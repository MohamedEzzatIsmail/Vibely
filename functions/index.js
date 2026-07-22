/**
 * Firebase Cloud Functions (Vibely Backend)
 * Handles:
 * 1. sendPushNotification — authenticated HTTPS endpoint for sending a
 *    one-off push on demand (pre-existing).
 * 2. Open Graph / Deep Link Preview Pages at /post/:id (pre-existing —
 *    this is what makes shared post links render a rich preview card in
 *    WhatsApp/iMessage/etc.).
 * 3. sendNotificationPush — Firestore trigger that automatically sends a
 *    push the moment a Users/{uid}/notifications/{id} document is
 *    created. This is the new piece: nothing in the app ever called
 *    sendPushNotification (confirmed — no `http` calls anywhere in the
 *    Flutter client despite the `http` package being a pubspec
 *    dependency), so notifications never reached anyone while the app
 *    was closed. Rather than wire the client to call the HTTPS endpoint
 *    after every notification write (one more place to forget), this
 *    trigger fires automatically for every notification type — likes,
 *    comments, follows, mentions, blocks, and direct + group messages —
 *    with no client changes needed. #1 and #2 are untouched and still
 *    work exactly as before.
 */

const functions = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const express = require("express");

admin.initializeApp();
setGlobalOptions({ maxInstances: 10, region: "us-central1" });

const app = express();

/* ─────────────────────────────────────────────────────────────
   1. PUSH NOTIFICATION FUNCTION (FCM) — on-demand HTTPS endpoint
───────────────────────────────────────────────────────────── */

exports.sendPushNotification = functions.https.onRequest(async (req, res) => {
  // CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  // This endpoint had no authentication at all — anyone who found the URL
  // could send arbitrary push notifications to any FCM token. Requires a
  // valid Firebase ID token from a signed-in Vibely user before proceeding.
  const authHeader = req.get("Authorization") || "";
  const idToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;

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

  const { token, title, body, data } = req.body;

  if (!token || typeof token !== "string") {
    res.status(400).json({ error: "Missing or invalid 'token'" });
    return;
  }

  const message = {
    token,

    notification: {
      title: title || "Vibely",
      body: body || "",
    },

    data: stringifyValues({ ...(data ?? {}), senderUid: callerUid }),

    android: {
      priority: "high",
      notification: {
        channelId: "high_importance_channel",
        sound: "default",
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
      },
    },

    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
          badge: 1,
          "content-available": 1,
        },
      },
    },
  };

  try {
    const messageId = await admin.messaging().send(message);
    res.status(200).json({ success: true, messageId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* ─────────────────────────────────────────────────────────────
   2. OPEN GRAPH + DEEP LINK PAGE (/post/:id)
───────────────────────────────────────────────────────────── */

app.get("/post/:id", async (req, res) => {
  const postId = req.params.id;

  // Pulls the real post from Firestore, with a safe fallback if it's
  // missing, private, or the lookup fails.
  let post = {
    title: "Vibely Post",
    text: "This is a sample post",
    imageUrl: "https://vibely.app/default.jpg",
  };

  try {
    const doc = await admin.firestore().collection("Posts").doc(postId).get();
    if (doc.exists) {
      const d = doc.data();
      if (d.privacy === "public") {
        post = {
          title: d.name ? `${d.name} on Vibely` : post.title,
          text: (d.text || post.text).slice(0, 200),
          imageUrl: (d.postImages && d.postImages[0]) || post.imageUrl,
        };
      }
    }
  } catch (err) {
    // Fall back to the generic placeholder above rather than failing the
    // whole preview page.
    console.error("Failed to load post for OG preview:", postId, err);
  }

  res.set("Content-Type", "text/html");

  res.send(`
    <!DOCTYPE html>
    <html>
    <head>

      <!-- Open Graph (WhatsApp / Facebook / iMessage preview) -->
      <meta property="og:title" content="${escapeHtml(post.title)}" />
      <meta property="og:description" content="${escapeHtml(post.text)}" />
      <meta property="og:image" content="${escapeHtml(post.imageUrl)}" />
      <meta property="og:url" content="https://vibely.app/post/${escapeHtml(postId)}" />
      <meta property="og:type" content="article" />

    </head>

    <body>

      Loading Vibely...

      <!-- Deep link into app -->
      <script>
        window.location.href = ${JSON.stringify(`vibely://post/${postId}`).replace(/</g, "\\u003c")};
      </script>

    </body>
    </html>
  `);
});

/* ─────────────────────────────────────────────────────────────
   3. EXPORT EXPRESS APP AS CLOUD FUNCTION
───────────────────────────────────────────────────────────── */

exports.api = functions.https.onRequest(app);

/* ─────────────────────────────────────────────────────────────
   4. AUTOMATIC PUSH ON EVERY NEW NOTIFICATION DOCUMENT (NEW)
───────────────────────────────────────────────────────────── */

const db = admin.firestore();
const messaging = admin.messaging();

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

/** Builds the { title, body } shown in the OS notification tray. */
function buildAlert(data) {
  const name = data.fromUserName || "Someone";
  if (data.type === "message") {
    // For messages the body is the actual message preview, not a
    // generic action string — matches how every real chat app does it.
    const preview = data.text && String(data.text).trim().length > 0
      ? data.text
      : "Sent you a message";
    return { title: name, body: preview };
  }
  return { title: name, body: actionText(data.type) };
}

/**
 * Builds the FCM `data` payload. Every value MUST be a string — FCM
 * data payloads don't support other types — and the keys must match
 * exactly what fcm_service.dart's _route() reads on the client.
 */
function buildDataPayload(notifId, data) {
  const payload = {
    notificationId: notifId,
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

exports.sendNotificationPush = onDocumentCreated(
  "Users/{uid}/notifications/{notifId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const recipientUid = event.params.uid;
    const notifId = event.params.notifId;

    // Never push a notification to its own author (defensive — the app
    // already guards this before writing, but a rule change or manual
    // write shouldn't be able to spam someone about themselves).
    if (data.fromUserId && data.fromUserId === recipientUid) return;

    const userSnap = await db.collection("Users").doc(recipientUid).get();
    const token = userSnap.data()?.fcmToken;
    if (!token) {
      logger.info(`No fcmToken for ${recipientUid} — skipping push.`);
      return;
    }

    const { title, body } = buildAlert(data);

    const message = {
      token,
      notification: { title, body },
      data: buildDataPayload(notifId, data),
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

    try {
      await messaging.send(message);
    } catch (err) {
      const code = err && err.errorInfo && err.errorInfo.code;
      const isStaleToken =
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token" ||
        code === "messaging/invalid-argument";

      if (isStaleToken) {
        logger.info(`Stale fcmToken for ${recipientUid} — clearing it.`);
        await db.collection("Users").doc(recipientUid).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      } else {
        logger.error(`Push send failed for ${recipientUid}:`, err);
      }
    }
  }
);

/* ─────────────────────────────────────────────────────────────
   5. HELPERS
───────────────────────────────────────────────────────────── */

function stringifyValues(obj) {
  const result = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v !== null && v !== undefined) {
      result[k] = String(v);
    }
  }
  return result;
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
