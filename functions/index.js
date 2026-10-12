/**
 * Official WhatsApp Business Cloud API Backend for College Event App
 * Automatically sends verified registration confirmations and digital ticket passes.
 * Powered by Firebase Cloud Functions & Cloud Firestore.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();
const db = admin.firestore();

// Meta WhatsApp Cloud API Version
const GRAPH_API_VERSION = "v21.0";

/**
 * Normalizes phone number into international E.164 digits without '+'
 * Handles Indian numbers (default country 91) and existing international numbers.
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
 * Safely masks a phone number for diagnostics without exposing student PII
 */
function maskPhoneNumber(phone) {
  if (!phone || phone.length < 4) return "****";
  return `+***${phone.slice(-4)}`;
}

/**
 * 1. AUTOMATED TRIGGER: Executes whenever a registration is created or updated
 * When registration is confirmed and payment completed (or free), automatically enqueues
 * an official WhatsApp confirmation job idempotently.
 */
exports.onRegistrationConfirmed = functions.firestore
  .document("registrations/{registrationId}")
  .onWrite(async (change, context) => {
    if (!change.after.exists) return null;

    const regData = change.after.data();
    const registrationId = context.params.registrationId;

    // Check if registration is in confirmed status
    const isConfirmed =
      regData.registrationStatus === "confirmed" ||
      regData.registrationStatus === "registered";

    if (!isConfirmed) {
      return null;
    }

    // Check payment status for paid events
    const isPaidEvent = Number(regData.amount || 0) > 0;
    const isPaidOrFree =
      !isPaidEvent ||
      regData.paymentStatus === "paid" ||
      regData.paymentStatus === "completed";

    if (!isPaidOrFree) {
      return null;
    }

    // Check WhatsApp messaging consent
    if (!regData.whatsappConsent) {
      return null;
    }

    // Deterministic Idempotency Key
    const logId = `${registrationId}_cloud_wa`;
    const logRef = db.collection("notification_logs").doc(logId);

    return db.runTransaction(async (transaction) => {
      const logDoc = await transaction.get(logRef);

      if (logDoc.exists) {
        const existingStatus = logDoc.data().status;
        // Never duplicate if already pending, processing, accepted, sent, delivered, or read
        if (
          ["pending", "processing", "accepted", "sent", "delivered", "read"].includes(
            existingStatus
          )
        ) {
          return null;
        }
      }

      // Fetch event details if missing on registration document
      let eventTitle = regData.eventTitle || "";
      let eventDate = regData.eventDate || "";
      let eventTime = "";
      let venue = regData.venue || "";

      if (regData.eventId) {
        const eventDoc = await transaction.get(
          db.collection("events").doc(regData.eventId)
        );
        if (eventDoc.exists) {
          const ed = eventDoc.data();
          if (!eventTitle) eventTitle = ed.title || "";
          if (!eventDate)
            eventDate = ed.dateFormatted || (ed.date ? String(ed.date) : "");
          eventTime =
            ed.time ||
            (ed.startTime ? `${ed.startTime} - ${ed.endTime || ""}` : "");
          if (!venue) venue = ed.venue || "";
        }
      }

      const formattedRegId =
        registrationId.length > 8
          ? `REG-${registrationId.substring(0, 8).toUpperCase()}`
          : `REG-${registrationId.toUpperCase()}`;

      const ticketToken = regData.ticketToken || formattedRegId;
      const recipientPhone = normalizePhoneNumber(
        regData.whatsappNumber || regData.phone
      );

      transaction.set(
        logRef,
        {
          id: logId,
          registrationId: registrationId,
          eventId: regData.eventId || "",
          studentId: regData.studentId || regData.userId || "",
          studentName: regData.studentName || "Student",
          whatsappNumber: recipientPhone,
          eventTitle: eventTitle || "College Event",
          eventDate: eventDate || "Upcoming Date",
          eventTime: eventTime || "Scheduled Time",
          venue: venue || "College Campus",
          ticketToken: ticketToken,
          deliveryMode: "cloud_api",
          status: "pending",
          attemptCount: 1,
          lastError: "",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      transaction.update(change.after.ref, {
        whatsappStatus: "pending",
        whatsappDeliveryMode: "cloud_api",
      });

      console.log(
        `[WhatsApp Auto-Trigger] Enqueued confirmation job for registration ${registrationId}`
      );
      return null;
    });
  });

/**
 * 2. QUEUE PROCESSOR: Processes pending WhatsApp notification jobs
 * Dispatches official template messages via Meta WhatsApp Cloud API.
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

    // Atomically claim the job to prevent duplicate sends on retries / concurrent invocations
    const claimed = await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(change.after.ref);
      if (!doc.exists) return false;
      if (doc.data().status !== "pending") return false;

      transaction.update(change.after.ref, {
        status: "processing",
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return true;
    });

    if (!claimed) {
      return null;
    }

    // Retrieve backend credentials safely from environment secrets
    const token = process.env.WHATSAPP_ACCESS_TOKEN;
    const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;
    const templateName =
      process.env.WHATSAPP_TEMPLATE_NAME || "event_registration_confirmation";

    if (!token || !phoneNumberId) {
      const errMsg =
        "WhatsApp Cloud API credentials (WHATSAPP_ACCESS_TOKEN / WHATSAPP_PHONE_NUMBER_ID) not configured in Firebase secrets.";
      console.warn(
        `[WhatsApp] Cloud API credentials not configured. Job ${logId} marked as unconfigured.`
      );
      await change.after.ref.update({
        status: "unconfigured",
        lastError: errMsg,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      if (data.registrationId) {
        await db
          .collection("registrations")
          .doc(data.registrationId)
          .update({
            whatsappStatus: "unconfigured",
            whatsappError: errMsg,
          })
          .catch(() => {});
      }
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
        lastError: "Registration record not found in Firestore.",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }

    const regData = regDoc.data();
    if (!regData.whatsappConsent) {
      const noConsentMsg = "Student has not granted WhatsApp messaging consent.";
      await change.after.ref.update({
        status: "no_consent",
        lastError: noConsentMsg,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await db
        .collection("registrations")
        .doc(data.registrationId)
        .update({
          whatsappStatus: "no_consent",
          whatsappError: noConsentMsg,
        })
        .catch(() => {});
      return null;
    }

    // 2. Validate Paid Status
    if (regData.amount > 0 && regData.paymentStatus !== "paid") {
      const pendingMsg = "Payment is pending. Confirmation deferred.";
      await change.after.ref.update({
        status: "payment_pending",
        lastError: pendingMsg,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await db
        .collection("registrations")
        .doc(data.registrationId)
        .update({
          whatsappStatus: "payment_pending",
          whatsappError: pendingMsg,
        })
        .catch(() => {});
      return null;
    }

    const recipientPhone = normalizePhoneNumber(
      data.whatsappNumber || regData.whatsappNumber || regData.phone
    );

    if (!recipientPhone || recipientPhone.length < 10) {
      const invalidPhoneMsg = `Invalid recipient phone number: ${maskPhoneNumber(recipientPhone)}`;
      await change.after.ref.update({
        status: "invalid_phone",
        lastError: invalidPhoneMsg,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await db
        .collection("registrations")
        .doc(data.registrationId)
        .update({
          whatsappStatus: "invalid_phone",
          whatsappError: invalidPhoneMsg,
        })
        .catch(() => {});
      return null;
    }

    const formattedRegId =
      data.registrationId.length > 8
        ? `REG-${data.registrationId.substring(0, 8).toUpperCase()}`
        : `REG-${data.registrationId.toUpperCase()}`;

    const ticketId = data.ticketToken || regData.ticketToken || formattedRegId;

    // 3. Construct Meta Cloud API Payload conforming to approved Template
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
          timeout: 12000,
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
        lastError: "",
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update registration document with accepted state
      await db.collection("registrations").doc(data.registrationId).update({
        whatsappStatus: "accepted",
        whatsappMessageId: messageId || "",
        whatsappError: "",
        whatsappSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(
        `[WhatsApp] Message accepted by Meta. Job: ${logId}, MessageId: ${messageId}`
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
 * 3. WEBHOOK ENDPOINT: Handles Meta Delivery Receipts (sent, delivered, read, failed)
 */
exports.whatsappWebhook = functions.https.onRequest(async (req, res) => {
  // Verification Challenge (GET)
  if (req.method === "GET") {
    const mode = req.query["hub.mode"];
    const token = req.query["hub.verify_token"];
    const challenge = req.query["hub.challenge"];

    const verifyToken =
      process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN || "college_events_verify_token";

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

              console.log(
                `[WhatsApp Webhook] Status: Msg ${messageId} -> ${deliveryStatus}`
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

/**
 * 4. ADMIN CALLABLE: Allows authorized admin staff to safely retry eligible failed notifications
 */
exports.adminRetryWhatsAppNotification = functions.https.onCall(
  async (data, context) => {
    // 1. Authorization verification
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication required."
      );
    }

    const callerUid = context.auth.uid;
    const userDoc = await db.collection("users").doc(callerUid).get();
    const callerEmail = context.auth.token.email || "";

    const isAdmin =
      callerEmail === "admin@collegeevent.com" ||
      callerEmail === "admin@college.edu" ||
      (userDoc.exists &&
        ["admin", "faculty", "coordinator"].includes(userDoc.data().role));

    if (!isAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only authorized administrators may retry notifications."
      );
    }

    const { registrationId } = data;
    if (!registrationId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "registrationId is required."
      );
    }

    const logId = `${registrationId}_cloud_wa`;
    const logRef = db.collection("notification_logs").doc(logId);

    return db.runTransaction(async (transaction) => {
      const logDoc = await transaction.get(logRef);

      if (!logDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "No notification job found for this registration."
        );
      }

      const currentStatus = logDoc.data().status;
      // Do not re-send if already delivered or accepted
      if (["delivered", "read", "accepted", "processing"].includes(currentStatus)) {
        return {
          success: false,
          message: `Cannot retry: Notification is already in '${currentStatus}' status.`,
        };
      }

      // Reset to pending to re-trigger the queue worker
      transaction.update(logRef, {
        status: "pending",
        lastError: "",
        attemptCount: admin.firestore.FieldValue.increment(1),
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        message: "Notification re-enqueued successfully for processing.",
      };
    });
  }
);

/**
 * 5. REWARD REDEMPTION CALLABLE: Server-validated atomic reward redemption
 */
exports.redeemRewardCallable = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication required to redeem rewards."
    );
  }

  const studentId = context.auth.uid;
  const { rewardId } = data;

  if (!rewardId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "rewardId is required."
    );
  }

  const rewardRef = db.collection("rewards").doc(rewardId);
  const gamificationRef = db.collection("gamification").doc(studentId);
  const userRef = db.collection("users").doc(studentId);

  return db.runTransaction(async (transaction) => {
    const rewardDoc = await transaction.get(rewardRef);
    if (!rewardDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Reward not found.");
    }
    const reward = rewardDoc.data();
    if (!reward.isEnabled) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Reward is currently disabled."
      );
    }
    if (reward.availableStock === 0) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Reward is out of stock."
      );
    }

    const gameDoc = await transaction.get(gamificationRef);
    const gameData = gameDoc.exists ? gameDoc.data() : { coins: 0 };
    const currentCoins = Number(gameData.coins || 0);

    if (currentCoins < reward.coinCost) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `Insufficient coins. Required: ${reward.coinCost}, Available: ${currentCoins}`
      );
    }

    const userDoc = await transaction.get(userRef);
    const userData = userDoc.exists ? userDoc.data() : {};

    const redemptionId = `RED-${Date.now()}-${studentId.substring(0, 4)}`;
    const redemptionRef = db.collection("redemptions").doc(redemptionId);
    const ledgerRef = db.collection("reward_history").doc(`${redemptionId}_ledger`);

    // Deduct coins (spendable balance only)
    transaction.set(
      gamificationRef,
      {
        coins: currentCoins - reward.coinCost,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // Decrement stock if finite
    if (reward.availableStock > 0) {
      transaction.update(rewardRef, {
        availableStock: reward.availableStock - 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Create redemption
    transaction.set(redemptionRef, {
      id: redemptionId,
      studentId: studentId,
      studentName: userData.name || "Student",
      studentRoll: userData.rollNumber || "",
      studentEmail: userData.email || "",
      rewardId: rewardId,
      rewardTitle: reward.title || "Reward",
      rewardCategory: reward.category || "college_perk",
      coinCost: reward.coinCost,
      status: reward.fulfilmentType === "automatic" ? "approved" : "pending",
      statusReason: `Redeemed with ${reward.coinCost} coins`,
      idempotencyKey: redemptionId,
      redeemedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Create ledger entry
    transaction.set(ledgerRef, {
      id: `${redemptionId}_ledger`,
      studentId: studentId,
      amount: -reward.coinCost,
      type: "reward_redemption",
      title: `Redeemed: ${reward.title || "Reward"}`,
      description: `Spent ${reward.coinCost} coins`,
      refId: rewardId,
      idempotencyKey: redemptionId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      redemptionId: redemptionId,
      remainingCoins: currentCoins - reward.coinCost,
    };
  });
});

/**
 * 6. ADMIN COIN ADJUSTMENT CALLABLE: Role-verified administrative adjustments
 */
exports.adminAdjustCoinsCallable = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication required."
      );
    }

    const callerUid = context.auth.uid;
    const callerEmail = context.auth.token.email || "";
    const callerDoc = await db.collection("users").doc(callerUid).get();
    const isAdmin =
      callerEmail === "admin@collegeevent.com" ||
      callerEmail === "admin@college.edu" ||
      (callerDoc.exists &&
        ["admin", "faculty", "coordinator"].includes(callerDoc.data().role));

    if (!isAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only authorized staff can adjust student coins."
      );
    }

    const { studentId, coinDelta, reason } = data;
    if (!studentId || typeof coinDelta !== "number" || coinDelta === 0 || !reason) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "studentId, non-zero coinDelta, and reason are required."
      );
    }

    const gamificationRef = db.collection("gamification").doc(studentId);
    const adjustmentId = `ADJ-${Date.now()}-${studentId.substring(0, 4)}`;
    const ledgerRef = db.collection("reward_history").doc(adjustmentId);

    return db.runTransaction(async (transaction) => {
      const gameDoc = await transaction.get(gamificationRef);
      const gameData = gameDoc.exists
        ? gameDoc.data()
        : { coins: 0, lifetimeCoins: 0 };
      const currentSpendable = Number(gameData.coins || 0);
      const currentLifetime = Number(gameData.lifetimeCoins || currentSpendable);

      const newSpendable = Math.max(0, currentSpendable + coinDelta);
      const newLifetime =
        coinDelta > 0 ? currentLifetime + coinDelta : currentLifetime;

      transaction.set(
        gamificationRef,
        {
          coins: newSpendable,
          lifetimeCoins: newLifetime,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      transaction.set(ledgerRef, {
        id: adjustmentId,
        studentId: studentId,
        amount: coinDelta,
        type: "admin_adjustment",
        title: coinDelta > 0 ? "Admin Coin Award" : "Admin Coin Deduction",
        description: `${reason} (by ${callerUid})`,
        refId: callerUid,
        idempotencyKey: adjustmentId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        adjustmentId: adjustmentId,
        newSpendable: newSpendable,
        newLifetime: newLifetime,
      };
    });
  }
);

/**
 * 7. AUTOMATED REFERRAL QUALIFICATION TRIGGER:
 * Executes whenever a registration attendance is verified.
 * Checks if attendee was referred by another student with 'pending' status.
 * Atomically awards configured coins (+50 referrer, +50 referred) and marks referral completed.
 */
exports.onRegistrationAttended = functions.firestore
  .document("registrations/{registrationId}")
  .onWrite(async (change, context) => {
    if (!change.after.exists) return null;

    const afterData = change.after.data();
    const beforeData = change.before.exists ? change.before.data() : null;

    const isNowAttended =
      afterData.attended === true ||
      afterData.attendanceStatus === "attended";
    const wasAlreadyAttended =
      beforeData &&
      (beforeData.attended === true ||
        beforeData.attendanceStatus === "attended");

    if (!isNowAttended || wasAlreadyAttended) {
      return null;
    }

    const studentId = afterData.studentId || afterData.userId || "";
    if (!studentId) return null;

    const eventId = afterData.eventId || "";

    try {
      // 1. Fetch configured referral reward amount if defined
      let referrerCoinAward = 50;
      let referredCoinAward = 50;
      try {
        const ruleDoc = await db
          .collection("gamification_rules")
          .doc("referral")
          .get();
        if (ruleDoc.exists && ruleDoc.data().coinAmount) {
          referrerCoinAward = Number(ruleDoc.data().coinAmount);
        }
      } catch (err) {
        console.warn("Could not read referral rule:", err);
      }

      // 2. Locate pending referral
      let referralDoc = null;

      // Check student's gamification profile first for referredBy
      const studentGameDoc = await db
        .collection("gamification")
        .doc(studentId)
        .get();
      if (studentGameDoc.exists && studentGameDoc.data().referredBy) {
        const directId = `${studentGameDoc.data().referredBy}_${studentId}`;
        const directDoc = await db.collection("referrals").doc(directId).get();
        if (directDoc.exists && directDoc.data().status === "pending") {
          referralDoc = directDoc;
        }
      }

      // Fallback query by referredUid
      if (!referralDoc) {
        const query = await db
          .collection("referrals")
          .where("referredUid", "==", studentId)
          .where("status", "==", "pending")
          .limit(1)
          .get();
        if (!query.empty) {
          referralDoc = query.docs[0];
        }
      }

      if (!referralDoc || !referralDoc.exists) {
        return null;
      }

      const referral = referralDoc.data();
      const referralId = referralDoc.id;
      const referrerUid = referral.referrerUid;

      return await db.runTransaction(async (transaction) => {
        // Re-read referral doc in transaction to prevent duplicate claims
        const freshRef = await transaction.get(referralDoc.ref);
        if (!freshRef.exists) return null;
        const freshStatus = freshRef.data().status;
        if (freshStatus === "completed" || freshStatus === "qualified" || freshStatus !== "pending") {
          return null;
        }

        // Referrer profile
        const referrerGameRef = db.collection("gamification").doc(referrerUid);
        const referrerProfile = await transaction.get(referrerGameRef);
        if (referrerProfile.exists) {
          const rData = referrerProfile.data();
          const rCoins = Number(rData.coins || 0) + referrerCoinAward;
          const rLifetime =
            Number(rData.lifetimeCoins || 0) + referrerCoinAward;
          transaction.set(
            referrerGameRef,
            {
              coins: rCoins,
              lifetimeCoins: rLifetime,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );

          // Referrer ledger
          const refLedgerRef = db
            .collection("reward_history")
            .doc(`REF_BONUS_${referralId}_referrer`);
          transaction.set(refLedgerRef, {
            id: `REF_BONUS_${referralId}_referrer`,
            studentId: referrerUid,
            amount: referrerCoinAward,
            coinsAwarded: referrerCoinAward,
            type: "referral_bonus",
            rewardType: "referral_bonus",
            title: `Referral Reward (+${referrerCoinAward} Coins)`,
            rewardReason: `Referral qualified by ${
              referral.referredName || "Student"
            }`,
            refId: studentId,
            idempotencyKey: `REF_BONUS_${referralId}_referrer`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // Referred student profile
        const studentGameRef = db.collection("gamification").doc(studentId);
        const studentProfile = await transaction.get(studentGameRef);
        if (studentProfile.exists) {
          const sData = studentProfile.data();
          const sCoins = Number(sData.coins || 0) + referredCoinAward;
          const sLifetime =
            Number(sData.lifetimeCoins || 0) + referredCoinAward;
          transaction.set(
            studentGameRef,
            {
              coins: sCoins,
              lifetimeCoins: sLifetime,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );

          // Student ledger
          const studLedgerRef = db
            .collection("reward_history")
            .doc(`REF_BONUS_${referralId}_student`);
          transaction.set(studLedgerRef, {
            id: `REF_BONUS_${referralId}_student`,
            studentId: studentId,
            amount: referredCoinAward,
            coinsAwarded: referredCoinAward,
            type: "referral_bonus",
            rewardType: "referral_bonus",
            title: `Referral Welcome Bonus (+${referredCoinAward} Coins)`,
            rewardReason: "Joined using referral code",
            refId: referrerUid,
            idempotencyKey: `REF_BONUS_${referralId}_student`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // Mark referral completed
        transaction.update(referralDoc.ref, {
          status: "completed",
          coinsAwarded: referrerCoinAward,
          friendCoinsAwarded: referredCoinAward,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          qualifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          eventId: eventId,
        });

        console.log(
          `Successfully qualified referral ${referralId}: Referrer ${referrerUid} (+${referrerCoinAward}), Referred ${studentId} (+${referredCoinAward})`
        );
        return { success: true, referralId };
      });
    } catch (error) {
      console.error(
        "Error in onRegistrationAttended referral qualification:",
        error
      );
      return null;
    }
  });

