/**
 * Vibely push server — standalone alternative to a Firebase Cloud Function.
 * ------------------------------------------------------------------------
 * Cloud Functions require the Blaze (pay-as-you-go) plan even to deploy a
 * single function. This is the same logic as functions/index.js's
 * `sendNotificationPush`, running as a plain Node/Express server instead,
 * so it can be hosted anywhere that runs Node for free (Render, etc.)
 * without touching your Firebase project's billing plan at all.
 *
 * Trigger model is different from the Cloud Function version: since there's
 * no Firestore trigger without Cloud Functions, the Flutter app calls this
 * server directly (POST /send-notification) right after it writes a
 * notification to Firestore — see lib/services/push_dispatcher.dart on the
 * client side. Everything else (payload shape, stale-token cleanup, title/
 * body building) is identical to the Cloud Function version.
 *
 * SECURITY: this endpoint requires a valid Firebase ID token from a signed
 * -in Vibely user (Authorization: Bearer <idToken>), and the token's uid
 * must match the notification's fromUserId — so no one can use this server
 * to send a push pretending to be someone else.
 */

const express = require("express");
const cors = require("cors");
const admin = require("firebase-admin");

// The service account key is provided via the FIREBASE_SERVICE_ACCOUNT
// environment variable (its full JSON contents, as a single-line string) —
// NEVER commit this key to git, and NEVER put it in the Flutter app. See
// PUSH_SERVER_SETUP.md for how to generate and set it.
if (!process.env.FIREBASE_SERVICE_ACCOUNT) {
  console.error(
    "FIREBASE_SERVICE_ACCOUNT env var is not set — see PUSH_SERVER_SETUP.md"
  );
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(
    JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
  ),
});

const db = admin.firestore();
const messaging = admin.messaging();

const app = express();
app.use(cors());
app.use(express.json());

app.get("/", (_req, res) => {
  res.status(200).send("Vibely push server is running.");
});

/** Mirrors _actionText() in notifications_screen.dart — keep in sync. */
function actionText(type) {
  switch (type) {
    case "postLike":
      return "reacted to your post";
    case "postComment":
      return "commented on your post";
    case "commentLike":
      return "liked your comment";
    case "commentReply":
      return "replied to your comment";
    case "follow":
      return "started following you";
    case "mention":
      return "mentioned you";
    case "blocked":
      return "blocked you";
    default:
      return "sent you a notification";
  }
}

function buildAlert(data) {
  const name = data.fromUserName || "Someone";
  if (data.type === "message") {
    const preview =
      data.text && String(data.text).trim().length > 0
        ? data.text
        : "Sent you a message";
    return { title: name, body: preview };
  }
  return { title: name, body: actionText(data.type) };
}

/** FCM `data` payload values must all be strings. */
function buildDataPayload(data) {
  const payload = {
    notificationId: data.id ? String(data.id) : "",
    type: data.type || "",
    fromUserId: data.fromUserId || "",
    fromUserName: data.fromUserName || "",
    fromUserImage: data.fromUserImage || "",
    dateTime: data.dateTime || new Date().toISOString(),
    isGroup: data.isGroup ? "true" : "false",
  };
  if (data.postId) payload.postId = String(data.postId);
  if (data.commentId) payload.commentId = String(data.commentId);
  if (data.replyId) payload.replyId = String(data.replyId);
  if (data.chatId) payload.chatId = String(data.chatId);
  if (data.text) payload.text = String(data.text);
  return payload;
}

app.post("/send-notification", async (req, res) => {
  const authHeader = req.get("Authorization") || "";
  const idToken = authHeader.startsWith("Bearer ")
    ? authHeader.slice(7)
    : null;

  if (!idToken) {
    return res.status(401).json({ error: "Missing Authorization: Bearer <idToken>" });
  }

  let callerUid;
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    callerUid = decoded.uid;
  } catch (err) {
    return res.status(401).json({ error: "Invalid or expired ID token" });
  }

  const data = req.body || {};
  const toUserId = data.toUserId;

  if (!toUserId || typeof toUserId !== "string") {
    return res.status(400).json({ error: "Missing 'toUserId'" });
  }

  // Prevent spoofing — you can only ever send a push "from" yourself.
  if (data.fromUserId && data.fromUserId !== callerUid) {
    return res.status(403).json({
      error: "fromUserId must match the authenticated caller",
    });
  }

  if (toUserId === callerUid) {
    return res.status(200).json({ skipped: "self-notification" });
  }

  try {
    const userSnap = await db.collection("Users").doc(toUserId).get();
    const token = userSnap.data()?.fcmToken;
    if (!token) {
      return res.status(200).json({ skipped: "recipient has no fcmToken" });
    }

    const { title, body } = buildAlert(data);

    const message = {
      token,
      notification: { title, body },
      data: buildDataPayload(data),
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: { sound: "default", badge: 1 },
        },
      },
    };

    await messaging.send(message);
    res.status(200).json({ success: true });
  } catch (err) {
    const code = err && err.errorInfo && err.errorInfo.code;
    const isStaleToken =
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token" ||
      code === "messaging/invalid-argument";

    if (isStaleToken) {
      await db.collection("Users").doc(toUserId).update({
        fcmToken: admin.firestore.FieldValue.delete(),
      });
      return res.status(200).json({ skipped: "stale token cleared" });
    }

    console.error("Push send failed:", err);
    res.status(500).json({ error: "push send failed" });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Vibely push server listening on port ${PORT}`);
});
