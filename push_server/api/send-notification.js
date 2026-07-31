// push_server/api/send-notification.js
//
// Vercel serverless function — same logic as the Express version this
// replaced, just in Vercel's function-per-file convention instead of an
// always-running Express app. Deployed at /api/send-notification, and
// vercel.json rewrites /send-notification to this file so the public URL
// stays identical to what the Render setup would have used.
const admin = require("firebase-admin");

if (!admin.apps.length) {
  if (!process.env.FIREBASE_SERVICE_ACCOUNT) {
    console.error(
      "FIREBASE_SERVICE_ACCOUNT env var is not set — see PUSH_SERVER_SETUP.md"
    );
  } else {
    admin.initializeApp({
      credential: admin.credential.cert(
        JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
      ),
    });
  }
}

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

module.exports = async (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    res.status(204).end();
    return;
  }
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const authHeader = req.headers.authorization || "";
  const idToken = authHeader.startsWith("Bearer ")
    ? authHeader.slice(7)
    : null;

  if (!idToken) {
    res.status(401).json({ error: "Missing Authorization: Bearer <idToken>" });
    return;
  }

  let callerUid;
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    callerUid = decoded.uid;
  } catch (err) {
    res.status(401).json({ error: "Invalid or expired ID token" });
    return;
  }

  // Vercel parses a JSON body into req.body automatically for this
  // content type — no manual body-parsing middleware needed.
  const data = req.body || {};
  const toUserId = data.toUserId;

  if (!toUserId || typeof toUserId !== "string") {
    res.status(400).json({ error: "Missing 'toUserId'" });
    return;
  }

  // Prevent spoofing — you can only ever send a push "from" yourself.
  if (data.fromUserId && data.fromUserId !== callerUid) {
    res.status(403).json({
      error: "fromUserId must match the authenticated caller",
    });
    return;
  }

  if (toUserId === callerUid) {
    res.status(200).json({ skipped: "self-notification" });
    return;
  }

  try {
    const db = admin.firestore();
    // fcmToken moved to Users/{uid}/private/data as part of the privacy
    // split (email/phone/block-lists/etc. are no longer on the public
    // doc) — reading the old path here always found nothing, so every
    // push silently no-op'd as "recipient has no fcmToken" regardless of
    // whether the recipient actually had one.
    const privateSnap = await db
      .collection("Users")
      .doc(toUserId)
      .collection("private")
      .doc("data")
      .get();
    const token = privateSnap.data()?.fcmToken;
    if (!token) {
      res.status(200).json({ skipped: "recipient has no fcmToken" });
      return;
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

    await admin.messaging().send(message);
    res.status(200).json({ success: true });
  } catch (err) {
    const code = err && err.errorInfo && err.errorInfo.code;
    const isStaleToken =
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token" ||
      code === "messaging/invalid-argument";

    if (isStaleToken) {
      await admin
        .firestore()
        .collection("Users")
        .doc(toUserId)
        .collection("private")
        .doc("data")
        .update({ fcmToken: admin.firestore.FieldValue.delete() });
      res.status(200).json({ skipped: "stale token cleared" });
      return;
    }

    console.error("Push send failed:", err);
    res.status(500).json({ error: "push send failed" });
  }
};
