/**
 * WhatsApp Cloud API Backend for College Event App
 * Implements Mode B: Automated WhatsApp Confirmation & Digital Ticket Delivery
 * Powered by Firebase Cloud Functions & Cloud Firestore
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();
const db = admin.firestore();

// Secrets configured in Firebase Secret Manager:
// - WHATSAPP_ACCESS_TOKEN
// - WHATSAPP_PHONE_NUMBER_ID
// - WHATSAPP_WEBHOOK_VERIFY_TOKEN
// - WHATSAPP_TEMPLATE_NAME (default: "event_registration_confirmation")

const GRAPH_API_VERSION = "v21.0";

/**
 * Normalizes phone number into international E.164 digits without '+'
 */
function normalizePhoneNumber(rawNumber, defaultCountry = "91") {
  if (!rawNumber) return "";
  let digits = String(rawNumber).replace(/[^\d+]/g, "").trim();
  if (digits.startsWith("+")) {
    digits = digits.substring(1);
  } else if (digits.length === 10) {
    digits = `${defaultCountry}${digits}`;
  } else if (digits.startsWith("0") && digits.length === 11) {
    digits = `${defaultCountry}${digits.substring(1)}`;
  }
  return digits;
}

/**
 * 1. Background Trigger: Executes whenever a notification_log is queued with 'pending' status
 */
exports.processWhatsAppNotificationQueue = functions.firestore
  .document("notification_logs/{logId}")
  .onWrite(async (change, context) => {
    if (!change.after.exists) return null;

    const data = change.after.data();
    const logId = context.params.logId;

    // Only process pending jobs targeting cloud_api
    if (data.status !== "pending" || data.deliveryMode !== "cloud_api") {
      return null;
    }

    const token = process.env.WHATSAPP_ACCESS_TOKEN;
    const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;
    const templateName =
      process.env.WHATSAPP_TEMPLATE_NAME || "event_registration_confirmation";

    if (!token || !phoneNumberId) {
      console.warn(
        `[WhatsApp] Missing Cloud API configuration for job ${logId}. Skipping API call.`
      );
      await change.after.ref.update({
        status: "unconfigured",
        lastError:
          "WhatsApp Cloud API credentials (WHATSAPP_ACCESS_TOKEN / WHATSAPP_PHONE_NUMBER_ID) not configured in Firebase environment secrets.",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }

    // 1. Verify Registration & Consent in Firestore
    const regDoc = await db
      .collection("registrations")
      .doc(data.registrationId)
      .get();
    if (!regDoc.exists) {
      await change.after.ref.update({
        status: "failed",
        lastError: "Registration document not found in Firestore.",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }

    const regData = regDoc.data();
    if (!regData.whatsappConsent) {
      await change.after.ref.update({
        status: "no_consent",
        lastError: "Student has not granted WhatsApp messaging consent.",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }

    // 2. Validate Paid Status
    if (regData.amount > 0 && regData.paymentStatus !== "paid") {
      await change.after.ref.update({
        status: "payment_pending",
        lastError: "Payment is not completed. Ticket message deferred.",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }

    const recipientPhone = normalizePhoneNumber(
      data.whatsappNumber || regData.whatsappNumber || regData.phone
    );

    if (!recipientPhone || recipientPhone.length < 10) {
      await change.after.ref.update({
        status: "invalid_phone",
        lastError: `Invalid recipient phone number: ${recipientPhone}`,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }

    const formattedRegId =
      data.registrationId.length > 8
        ? `REG-${data.registrationId.substring(0, 8).toUpperCase()}`
        : `REG-${data.registrationId.toUpperCase()}`;

    const ticketId = data.ticketToken || regData.ticketToken || formattedRegId;

    // 3. Construct Meta Cloud API Payload
    const payload = {
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: recipientPhone,
      type: "template",
      template: {
        name: templateName,
        language: {
          code: "en_US",
        },
        components: [
          {
            type: "body",
            parameters: [
              {
                type: "text",
                text: data.studentName || regData.studentName || "Student",
              },
              {
                type: "text",
                text: data.eventTitle || "College Event",
              },
              {
                type: "text",
                text: data.eventDate || "Upcoming Date",
              },
              {
                type: "text",
                text: data.eventTime || "Scheduled Time",
              },
              {
                type: "text",
                text: data.venue || "College Campus",
              },
              {
                type: "text",
                text: formattedRegId,
              },
              {
                type: "text",
                text: ticketId,
              },
            ],
          },
        ],
      },
    };

    try {
      const response = await axios.post(
        `https://graph.facebook.com/${GRAPH_API_VERSION}/${phoneNumberId}/messages`,
        payload,
        {
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          timeout: 10000,
        }
      );

      const messageId =
        response.data &&
        response.data.messages &&
        response.data.messages[0] &&
        response.data.messages[0].id;

      await change.after.ref.update({
        status: "accepted",
        providerMessageId: messageId || "",
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update registration document
      await db.collection("registrations").doc(data.registrationId).update({
        whatsappStatus: "accepted",
        whatsappMessageId: messageId || "",
        whatsappSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(
        `[WhatsApp] Message successfully accepted by Meta. Job: ${logId}, MessageId: ${messageId}`
      );
    } catch (err) {
      const safeErrorMessage =
        err.response && err.response.data && err.response.data.error
          ? err.response.data.error.message
          : err.message;

      console.error(
        `[WhatsApp] Delivery request failed for job ${logId}: ${safeErrorMessage}`
      );

      await change.after.ref.update({
        status: "failed",
        lastError: safeErrorMessage,
        attemptCount: admin.firestore.FieldValue.increment(1),
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await db.collection("registrations").doc(data.registrationId).update({
        whatsappStatus: "failed",
        whatsappError: safeErrorMessage,
      });
    }

    return null;
  });

/**
 * 2. Webhook Endpoint: Handles Meta WhatsApp Delivery Receipts (sent, delivered, read, failed)
 */
exports.whatsappWebhook = functions.https.onRequest(async (req, res) => {
  // Verification Challenge (GET)
  if (req.method === "GET") {
    const mode = req.query["hub.mode"];
    const token = req.query["hub.verify_token"];
    const challenge = req.query["hub.challenge"];

    const verifyToken = process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN || "college_events_verify_token";

    if (mode === "subscribe" && token === verifyToken) {
      return res.status(200).send(challenge);
    }
    return res.status(403).send("Forbidden");
  }

  // Delivery Event Notifications (POST)
  if (req.method === "POST") {
    const body = req.body;

    if (body.object && body.entry) {
      for (const entry of body.entry) {
        for (const change of entry.changes || []) {
          const value = change.value;
          if (value && value.statuses) {
            for (const statusObj of value.statuses) {
              const messageId = statusObj.id;
              const deliveryStatus = statusObj.status; // 'sent', 'delivered', 'read', 'failed'
              const recipientId = statusObj.recipient_id;

              console.log(
                `[WhatsApp Webhook] Status update: Msg ${messageId} -> ${deliveryStatus}`
              );

              // Update matching notification log in Firestore
              const logQuery = await db
                .collection("notification_logs")
                .where("providerMessageId", "==", messageId)
                .limit(1)
                .get();

              if (!logQuery.empty) {
                const doc = logQuery.docs[0];
                await doc.ref.update({
                  status: deliveryStatus,
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                const regId = doc.data().registrationId;
                if (regId) {
                  await db.collection("registrations").doc(regId).update({
                    whatsappStatus: deliveryStatus,
                  });
                }
              }
            }
          }
        }
      }
      return res.status(200).send("EVENT_RECEIVED");
    }

    return res.status(404).send("Not Found");
  }

  res.status(405).send("Method Not Allowed");
});
