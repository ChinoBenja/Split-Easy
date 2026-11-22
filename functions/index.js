const { initializeApp } = require("firebase-admin/app");
const { FieldValue, getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { logger } = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

initializeApp();

const db = getFirestore();
const MAX_MULTICAST_TOKENS = 500;

exports.notifyGroupMembersOnMessage = onDocumentCreated(
  "groups/{groupId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (
      !message ||
      message.type !== "text" ||
      typeof message.senderId !== "string"
    ) {
      return;
    }

    const { groupId, messageId } = event.params;
    const groupSnapshot = await db.collection("groups").doc(groupId).get();
    if (!groupSnapshot.exists) {
      logger.warn("No se notificó el mensaje: el grupo ya no existe.", {
        groupId,
        messageId,
      });
      return;
    }

    const group = groupSnapshot.data();
    const memberIds = Array.isArray(group.memberIds)
      ? [...new Set(group.memberIds)].filter(
          (uid) => typeof uid === "string" && uid !== message.senderId,
        )
      : [];
    if (memberIds.length === 0) return;

    const userSnapshots = await Promise.all(
      memberIds.map((uid) => db.collection("users").doc(uid).get()),
    );
    const recipients = userSnapshots
      .map((snapshot) => ({
        uid: snapshot.id,
        token: snapshot.data()?.fcmToken,
      }))
      .filter(
        (recipient) =>
          typeof recipient.token === "string" && recipient.token.length > 0,
      );
    if (recipients.length === 0) return;

    const rawText =
      typeof message.text === "string" && message.text.trim()
        ? message.text.trim()
        : message.imageUrl
          ? "📷 Imagen"
          : "Nuevo mensaje";
    const body =
      rawText.length > 160 ? `${rawText.slice(0, 157)}...` : rawText;
    const notification = {
      title:
        typeof group.name === "string" && group.name.trim()
          ? group.name.trim()
          : "SplitEasy",
      body: `${message.senderName || "Alguien"}: ${body}`,
    };

    for (let start = 0; start < recipients.length; start += MAX_MULTICAST_TOKENS) {
      const batch = recipients.slice(start, start + MAX_MULTICAST_TOKENS);
      const result = await getMessaging().sendEachForMulticast({
        tokens: batch.map((recipient) => recipient.token),
        notification,
        data: {
          type: "group_message",
          groupId,
          messageId,
        },
        android: {
          notification: { channelId: "split_easy_notifications" },
        },
        apns: {
          payload: { aps: { sound: "default" } },
        },
      });

      const invalidRecipients = [];
      result.responses.forEach((response, index) => {
        if (
          !response.success &&
          [
            "messaging/invalid-registration-token",
            "messaging/registration-token-not-registered",
          ].includes(response.error?.code)
        ) {
          invalidRecipients.push(batch[index]);
        }
      });

      await Promise.all(
        invalidRecipients.map(async ({ uid, token }) => {
          const userRef = db.collection("users").doc(uid);
          await db.runTransaction(async (transaction) => {
            const userSnapshot = await transaction.get(userRef);
            if (userSnapshot.data()?.fcmToken === token) {
              transaction.update(userRef, {
                fcmToken: FieldValue.delete(),
              });
            }
          });
        }),
      );

      if (result.failureCount > 0) {
        logger.warn("Algunas notificaciones del grupo no se enviaron.", {
          groupId,
          messageId,
          failureCount: result.failureCount,
        });
      }
    }
  },
);
