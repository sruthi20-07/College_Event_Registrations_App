import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/event_model.dart';
import '../models/registration_model.dart';
import '../models/whatsapp_notification_model.dart';
import '../utils/web_url_launcher.dart';

class WhatsAppHandoffResult {
  final bool success;
  final String message;
  final String? url;

  const WhatsAppHandoffResult({
    required this.success,
    required this.message,
    this.url,
  });
}

class WhatsAppApiResult {
  final bool success;
  final String status; // 'accepted', 'failed', 'unconfigured', 'no_consent'
  final String message;
  final String? messageId;
  final String? errorCode;

  const WhatsAppApiResult({
    required this.success,
    required this.status,
    required this.message,
    this.messageId,
    this.errorCode,
  });

  factory WhatsAppApiResult.unconfigured({required String message}) {
    return WhatsAppApiResult(
      success: false,
      status: 'unconfigured',
      message: message,
    );
  }

  factory WhatsAppApiResult.noConsent() {
    return const WhatsAppApiResult(
      success: false,
      status: 'no_consent',
      message: 'Student has not consented to WhatsApp notifications.',
    );
  }
}

class WhatsAppService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notificationLogs =>
      _firestore.collection('notification_logs');

  CollectionReference<Map<String, dynamic>> get _registrations =>
      _firestore.collection('registrations');

  /// Normalizes a phone number into international E.164 format without '+' for wa.me links
  static String normalizeForWaMe(String input, {String defaultCountryCode = '91'}) {
    if (input.trim().isEmpty) return '';

    // Remove all non-numeric characters except leading plus
    String digitsOnly = input.replaceAll(RegExp(r'[^\d+]'), '').trim();

    if (digitsOnly.startsWith('+')) {
      digitsOnly = digitsOnly.substring(1);
    } else if (digitsOnly.length == 10) {
      // 10-digit Indian standard mobile number
      digitsOnly = '$defaultCountryCode$digitsOnly';
    } else if (digitsOnly.startsWith('0') && digitsOnly.length == 11) {
      // Numbers starting with 0
      digitsOnly = '$defaultCountryCode${digitsOnly.substring(1)}';
    }

    return digitsOnly;
  }

  /// Normalizes a phone number for display/storage with '+' prefix
  static String normalizeForStorage(String input, {String defaultCountryCode = '+91'}) {
    final clean = normalizeForWaMe(input, defaultCountryCode: defaultCountryCode.replaceAll('+', ''));
    if (clean.isEmpty) return '';
    return '+$clean';
  }

  /// Validates whether the given string is a valid mobile/WhatsApp number (10 to 15 digits)
  static bool isValidPhoneNumber(String input) {
    final clean = normalizeForWaMe(input);
    return clean.length >= 10 && clean.length <= 15;
  }

  /// Builds formatted registration confirmation message using real event and student details
  /// explicitly instructing students to scan the official attendance QR code at the venue.
  static String buildTicketMessage({
    required RegistrationModel registration,
    required EventModel event,
  }) {
    final String studentName = registration.studentName.trim().isNotEmpty
        ? registration.studentName.trim()
        : 'Student';

    final String eventName = event.title.trim().isNotEmpty
        ? event.title.trim()
        : (registration.eventTitle.trim().isNotEmpty
            ? registration.eventTitle.trim()
            : 'Event');

    final String eventDate = event.dateFormatted.trim().isNotEmpty
        ? event.dateFormatted.trim()
        : (registration.eventDate.trim().isNotEmpty
            ? registration.eventDate.trim()
            : 'Event Date');

    final String eventTime = event.time.trim().isNotEmpty
        ? event.time.trim()
        : '10:00 AM - 4:00 PM';

    final String eventVenue = event.venue.trim().isNotEmpty
        ? event.venue.trim()
        : (registration.venue.trim().isNotEmpty
            ? registration.venue.trim()
            : 'College Campus');

    final String regIdRaw = registration.id.trim().toUpperCase();
    final String registrationId = regIdRaw.startsWith('REG-')
        ? regIdRaw
        : (regIdRaw.length > 8 ? 'REG-${regIdRaw.substring(0, 8)}' : 'REG-$regIdRaw');

    return 'Hello $studentName! \n\n'
    'Your registration for $eventName is confirmed! \n\n'
    'Event: $eventName\n'
    'Date: $eventDate\n'
    'Time: $eventTime\n'
    'Venue: $eventVenue\n'
    'Registration ID: $registrationId\n\n'
    'IMPORTANT — ATTENDANCE:\n'
    'Please attend the event and scan the official attendance QR code '
    'displayed at the venue using the College Event App to get your '
    'attendance marked as present.\n\n'
    'Registration confirmation alone does not mark you as present.\n\n'
    'Thank you!';
  }

  /// Formats the admin confirmation message; delegates directly to buildTicketMessage
  static String buildAdminConfirmationMessage({
    required RegistrationModel registration,
    required EventModel event,
  }) {
    return buildTicketMessage(
      registration: registration,
      event: event,
    );
  }

  /// Constructs Meta WhatsApp Cloud API template payload conforming to official specifications
  static Map<String, dynamic> buildTemplatePayload({
    required RegistrationModel registration,
    required EventModel event,
    String templateName = 'event_registration_confirmation',
  }) {
    final cleanPhone = normalizeForWaMe(
      registration.whatsappNumber.isNotEmpty
          ? registration.whatsappNumber
          : registration.phone,
    );

    final String studentName = registration.studentName.isNotEmpty
        ? registration.studentName
        : 'Student';
    final String eventTitle =
        event.title.isNotEmpty ? event.title : registration.eventTitle;
    final String eventDate = event.dateFormatted.isNotEmpty
        ? event.dateFormatted
        : registration.eventDate;
    final String eventTime =
        event.time.isNotEmpty ? event.time : '10:00 AM - 4:00 PM';
    final String venue = event.venue.isNotEmpty
        ? event.venue
        : (registration.venue.isNotEmpty
            ? registration.venue
            : 'College Campus');

    final String formattedRegId = registration.id.length > 8
        ? 'REG-${registration.id.substring(0, 8).toUpperCase()}'
        : 'REG-${registration.id.toUpperCase()}';

    final String ticketId = registration.ticketToken.isNotEmpty
        ? registration.ticketToken
        : formattedRegId;

    return {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': cleanPhone,
      'type': 'template',
      'template': {
        'name': templateName,
        'language': {'code': 'en_US'},
        'components': [
          {
            'type': 'body',
            'parameters': [
              {'type': 'text', 'text': studentName},
              {'type': 'text', 'text': eventTitle},
              {'type': 'text', 'text': eventDate},
              {'type': 'text', 'text': eventTime},
              {'type': 'text', 'text': venue},
              {'type': 'text', 'text': formattedRegId},
              {'type': 'text', 'text': ticketId},
            ],
          },
        ],
      },
    };
  }

  /// MODE A: Quick Demo / Manual WhatsApp Handoff via wa.me link
  Future<WhatsAppHandoffResult> shareTicketOnWhatsApp({
    required RegistrationModel registration,
    required EventModel event,
  }) async {
    final String targetNumber = registration.whatsappNumber.isNotEmpty
        ? registration.whatsappNumber
        : registration.phone;

    final String cleanNumber = normalizeForWaMe(targetNumber);

    if (cleanNumber.isEmpty || !isValidPhoneNumber(cleanNumber)) {
      return const WhatsAppHandoffResult(
        success: false,
        message: 'Invalid WhatsApp number. Please check the country code and digits.',
      );
    }

    final String messageText = buildTicketMessage(
      registration: registration,
      event: event,
    );

    final String encodedMessage = Uri.encodeComponent(messageText);
    final String urlString = 'https://wa.me/$cleanNumber?text=$encodedMessage';

    bool launched = false;
    try {
      launched = await PlatformUrlLauncher.open(urlString);
    } catch (e) {
      debugPrint('Error opening WhatsApp URL: $e');
      launched = false;
    }

    if (launched) {
      // Log notification attempt idempotently in Firestore
      await _recordNotificationLog(
        registration: registration,
        event: event,
        deliveryMode: 'manual',
        status: 'ready_to_share',
      );

      return WhatsAppHandoffResult(
        success: true,
        message: 'WhatsApp opened with prefilled ticket for +$cleanNumber. Tap "Send" in WhatsApp to deliver the message.',
        url: urlString,
      );
    } else {
      await _recordNotificationLog(
        registration: registration,
        event: event,
        deliveryMode: 'manual',
        status: 'failed',
        lastError: 'Could not open WhatsApp on this browser/device.',
      );

      return WhatsAppHandoffResult(
        success: false,
        message: 'Could not open WhatsApp on this device. You can copy the ticket text directly and send manually.',
        url: urlString,
      );
    }
  }

  /// MODE B: Automated WhatsApp Cloud API Delivery (Backend Architecture)
  Future<WhatsAppApiResult> sendCloudApiWhatsAppNotification({
    required RegistrationModel registration,
    required EventModel event,
  }) async {
    // 1. Consent verification
    if (!registration.whatsappConsent) {
      return WhatsAppApiResult.noConsent();
    }

    final String targetNumber = registration.whatsappNumber.isNotEmpty
        ? registration.whatsappNumber
        : registration.phone;

    final String cleanNumber = normalizeForWaMe(targetNumber);
    if (!isValidPhoneNumber(cleanNumber)) {
      return const WhatsAppApiResult(
        success: false,
        status: 'failed',
        message: 'Invalid international phone number for Cloud API delivery.',
      );
    }

    // 2. Paid registration verification
    if (event.isPaid && !registration.isPaid) {
      return const WhatsAppApiResult(
        success: false,
        status: 'failed',
        message: 'Payment pending. Cannot send confirmed ticket before payment verification.',
      );
    }

    // 3. Create or update notification job in Firestore for secure Cloud Function worker
    final String logId = '${registration.id}_cloud_wa';
    final DateTime now = DateTime.now();

    try {
      final docRef = _notificationLogs.doc(logId);
      final docSnap = await docRef.get();

      int attemptCount = 1;
      if (docSnap.exists) {
        attemptCount = ((docSnap.data()?['attemptCount'] as num?)?.toInt() ?? 1) + 1;
      }

      final notificationLog = WhatsAppNotificationModel(
        id: logId,
        registrationId: registration.id,
        eventId: event.id,
        studentId: registration.studentId,
        studentName: registration.studentName,
        whatsappNumber: cleanNumber,
        eventTitle: event.title,
        eventDate: event.dateFormatted,
        eventTime: event.time,
        venue: event.venue,
        ticketToken: registration.ticketToken,
        deliveryMode: 'cloud_api',
        status: 'pending',
        attemptCount: attemptCount,
        lastAttemptAt: now,
        createdAt: docSnap.exists ? null : now,
        updatedAt: now,
      );

      await docRef.set(notificationLog.toMap(), SetOptions(merge: true));

      // Update registration document with pending status
      if (registration.id.isNotEmpty) {
        await _registrations.doc(registration.id).update({
          'whatsappStatus': 'pending',
          'whatsappDeliveryMode': 'cloud_api',
          'whatsappSentAt': Timestamp.fromDate(now),
        }).catchError((_) {});
      }

      // Poll up to 2 seconds to check if Cloud Function processed the job and updated Firestore
      for (int i = 0; i < 4; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        final updatedSnap = await docRef.get();
        if (updatedSnap.exists) {
          final currentStatus = updatedSnap.data()?['status'] as String? ?? 'pending';
          final providerMsgId = updatedSnap.data()?['providerMessageId'] as String?;
          final lastErr = updatedSnap.data()?['lastError'] as String?;

          if (currentStatus == 'accepted') {
            return WhatsAppApiResult(
              success: true,
              status: 'accepted',
              messageId: providerMsgId,
              message: 'Message accepted by Meta WhatsApp Cloud API${providerMsgId != null && providerMsgId.isNotEmpty ? ' (ID: $providerMsgId)' : ''}. Delivery confirmation pending.',
            );
          } else if (currentStatus == 'delivered') {
            return WhatsAppApiResult(
              success: true,
              status: 'delivered',
              messageId: providerMsgId,
              message: 'Delivered to student\'s WhatsApp device (+$cleanNumber).',
            );
          } else if (currentStatus == 'unconfigured') {
            return WhatsAppApiResult(
              success: false,
              status: 'unconfigured',
              message: lastErr ?? 'WhatsApp Cloud API backend credentials (WHATSAPP_ACCESS_TOKEN / WHATSAPP_PHONE_NUMBER_ID) not configured in Firebase environment secrets.',
            );
          } else if (currentStatus == 'failed') {
            return WhatsAppApiResult(
              success: false,
              status: 'failed',
              errorCode: 'API_ERROR',
              message: lastErr ?? 'WhatsApp Cloud API rejected the message.',
            );
          }
        }
      }

      // If backend has not yet updated the record, report accurate status
      return WhatsAppApiResult(
        success: false,
        status: 'queued',
        message: 'Notification queued in Firestore (Job: $logId). Backend Cloud Function is awaiting execution. Deploy Cloud Functions and configure WHATSAPP_ACCESS_TOKEN secrets in Firebase.',
      );
    } catch (e) {
      debugPrint('Cloud API notification queueing error: $e');
      return WhatsAppApiResult(
        success: false,
        status: 'failed',
        message: 'Could not queue Cloud API notification: $e',
      );
    }
  }

  /// Automatically enqueues a WhatsApp Cloud API notification after registration is confirmed.
  /// Ensures idempotency so duplicate triggers do not send multiple messages.
  Future<WhatsAppApiResult> queueAutomatedNotification({
    required RegistrationModel registration,
    EventModel? event,
  }) async {
    // 1. Consent verification
    if (!registration.whatsappConsent) {
      if (registration.id.isNotEmpty) {
        await _registrations.doc(registration.id).update({
          'whatsappStatus': 'no_consent',
          'whatsappError': 'Student has not consented to WhatsApp notifications.',
        }).catchError((_) {});
      }
      return WhatsAppApiResult.noConsent();
    }
    // 2. Validate recipient phone number
    final String targetNumber = registration.whatsappNumber.isNotEmpty
        ? registration.whatsappNumber
        : registration.phone;
    final String cleanNumber = normalizeForWaMe(targetNumber);

    if (cleanNumber.isEmpty || !isValidPhoneNumber(cleanNumber)) {
      if (registration.id.isNotEmpty) {
        await _registrations.doc(registration.id).update({
          'whatsappStatus': 'invalid_phone',
          'whatsappError': 'Invalid or missing contact phone number for WhatsApp confirmation.',
        }).catchError((_) {});
      }
      return const WhatsAppApiResult(
        success: false,
        status: 'invalid_phone',
        message: 'Invalid or missing contact phone number for WhatsApp confirmation.',
      );
    }

    // 3. Validate payment status for paid events
    if (registration.amount > 0 && !registration.isPaid) {
      if (registration.id.isNotEmpty) {
        await _registrations.doc(registration.id).update({
          'whatsappStatus': 'payment_pending',
          'whatsappError': 'Registration payment is pending. Notification deferred.',
        }).catchError((_) {});
      }
      return const WhatsAppApiResult(
        success: false,
        status: 'payment_pending',
        message: 'Registration payment is pending. Notification deferred.',
      );
    }

    // 4. Deterministic Idempotency Key
    final String logId = '${registration.id}_cloud_wa';
    final DateTime now = DateTime.now();

    try {
      final docRef = _notificationLogs.doc(logId);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final existingStatus = docSnap.data()?['status'] as String? ?? '';
        // If already pending, processing, accepted, sent, delivered, or read, prevent duplicate send
        if (const ['pending', 'processing', 'accepted', 'sent', 'delivered', 'read']
            .contains(existingStatus)) {
          return WhatsAppApiResult(
            success: true,
            status: existingStatus,
            message: 'WhatsApp notification is already $existingStatus for this registration.',
          );
        }
      }

      int attemptCount = 1;
      if (docSnap.exists) {
        attemptCount =
            ((docSnap.data()?['attemptCount'] as num?)?.toInt() ?? 1) + 1;
      }

      final notificationLog = WhatsAppNotificationModel(
        id: logId,
        registrationId: registration.id,
        eventId: event?.id ?? registration.eventId,
        studentId: registration.studentId,
        studentName: registration.studentName,
        whatsappNumber: cleanNumber,
        eventTitle: event?.title ?? registration.eventTitle,
        eventDate: event?.dateFormatted ?? registration.eventDate,
        eventTime: event?.time ?? '',
        venue: event?.venue ?? registration.venue,
        ticketToken: registration.ticketToken,
        deliveryMode: 'cloud_api',
        status: 'pending',
        attemptCount: attemptCount,
        lastAttemptAt: now,
        createdAt: docSnap.exists ? null : now,
        updatedAt: now,
      );

      await docRef.set(notificationLog.toMap(), SetOptions(merge: true));

      if (registration.id.isNotEmpty) {
        await _registrations.doc(registration.id).update({
          'whatsappStatus': 'pending',
          'whatsappDeliveryMode': 'cloud_api',
        }).catchError((_) {});
      }

      return const WhatsAppApiResult(
        success: true,
        status: 'pending',
        message: 'WhatsApp confirmation queued successfully for delivery.',
      );
    } catch (e) {
      debugPrint('Error queueing automated notification: $e');
      return WhatsAppApiResult(
        success: false,
        status: 'failed',
        message: 'Failed to queue automated notification: $e',
      );
    }
  }

  /// Safely retries an eligible failed or unconfigured notification without sending duplicates.
  Future<WhatsAppApiResult> retryCloudApiNotification({
    required RegistrationModel registration,
    EventModel? event,
  }) async {
    final String logId = '${registration.id}_cloud_wa';
    try {
      final docRef = _notificationLogs.doc(logId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        // Not yet queued -> queue fresh
        return queueAutomatedNotification(
          registration: registration,
          event: event,
        );
      }

      final currentStatus = docSnap.data()?['status'] as String? ?? '';
      // Guard against duplicate send
      if (const ['accepted', 'delivered', 'read', 'processing', 'sent']
          .contains(currentStatus)) {
        return WhatsAppApiResult(
          success: false,
          status: currentStatus,
          message: 'Cannot retry: message has already been $currentStatus.',
        );
      }

      final int attemptCount =
          ((docSnap.data()?['attemptCount'] as num?)?.toInt() ?? 1) + 1;
      final DateTime now = DateTime.now();

      await docRef.update({
        'status': 'pending',
        'lastError': '',
        'attemptCount': attemptCount,
        'lastAttemptAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      if (registration.id.isNotEmpty) {
        await _registrations.doc(registration.id).update({
          'whatsappStatus': 'pending',
          'whatsappError': '',
        }).catchError((_) {});
      }

      return const WhatsAppApiResult(
        success: true,
        status: 'pending',
        message: 'Notification re-enqueued for delivery.',
      );
    } catch (e) {
      debugPrint('Error retrying notification: $e');
      return WhatsAppApiResult(
        success: false,
        status: 'failed',
        message: 'Could not retry notification: $e',
      );
    }
  }

  /// Streams real-time WhatsApp notification status for a registration
  Stream<WhatsAppNotificationModel?> streamNotificationLog(String registrationId) {
    if (registrationId.isEmpty) return Stream.value(null);
    return _notificationLogs
        .doc('${registrationId}_cloud_wa')
        .snapshots()
        .map((docSnap) {
          if (!docSnap.exists) return null;
          return WhatsAppNotificationModel.fromSnapshot(docSnap);
        });
  }

  /// Internal helper to record notification attempt in Firestore
  Future<void> _recordNotificationLog({
    required RegistrationModel registration,
    required EventModel event,
    required String deliveryMode,
    required String status,
    String? lastError,
  }) async {
    final String logId = '${registration.id}_wa';
    final DateTime now = DateTime.now();

    try {
      final docRef = _notificationLogs.doc(logId);
      final docSnap = await docRef.get();

      int attemptCount = 1;
      if (docSnap.exists) {
        attemptCount = ((docSnap.data()?['attemptCount'] as num?)?.toInt() ?? 1) + 1;
      }

      final log = WhatsAppNotificationModel(
        id: logId,
        registrationId: registration.id,
        eventId: event.id,
        studentId: registration.studentId,
        studentName: registration.studentName,
        whatsappNumber: registration.whatsappNumber,
        eventTitle: event.title,
        eventDate: event.dateFormatted,
        eventTime: event.time,
        venue: event.venue,
        ticketToken: registration.ticketToken,
        deliveryMode: deliveryMode,
        status: status,
        attemptCount: attemptCount,
        lastAttemptAt: now,
        lastError: lastError ?? '',
        createdAt: docSnap.exists ? null : now,
        updatedAt: now,
      );

      await docRef.set(log.toMap(), SetOptions(merge: true));

      // Update registration model status
        final Map<String, dynamic> updateData = {
          'whatsappStatus': status,
          'whatsappDeliveryMode': deliveryMode,
          'whatsappSentAt': Timestamp.fromDate(now),
        };
        if (lastError != null && lastError.isNotEmpty) {
          updateData['whatsappError'] = lastError;
        }
        await _registrations.doc(registration.id).update(updateData).catchError((_) {});
    } catch (e) {
      debugPrint('Failed to save notification audit log: $e');
    }
  }

  /// Records admin manual WhatsApp confirmation in Firestore
  Future<void> recordAdminConfirmation({
    required String registrationId,
    required String eventId,
    required String studentId,
    required String studentName,
    required String eventTitle,
    required String phone,
    required String adminUid,
    required bool wasSent,
  }) async {
    final now = DateTime.now();
    final cleanPhone = normalizeForWaMe(phone);

    try {
      if (wasSent) {
        await _registrations.doc(registrationId).update({
          'whatsappStatus': 'admin_confirmed_sent',
          'whatsappDeliveryMode': 'manual_admin',
          'whatsappSentAt': Timestamp.fromDate(now),
          'whatsappConfirmedByAdminUid': adminUid,
          'whatsappConfirmedAt': Timestamp.fromDate(now),
          'whatsappNumber': cleanPhone.isNotEmpty ? '+$cleanPhone' : '',
          'whatsappError': '',
        }).catchError((_) {});

        await _notificationLogs.doc('${registrationId}_admin_wa').set({
          'id': '${registrationId}_admin_wa',
          'registrationId': registrationId,
          'eventId': eventId,
          'studentId': studentId,
          'studentName': studentName,
          'whatsappNumber': cleanPhone,
          'eventTitle': eventTitle,
          'deliveryMode': 'manual_admin',
          'status': 'admin_confirmed_sent',
          'adminUid': adminUid,
          'confirmedAt': Timestamp.fromDate(now),
          'lastAttemptAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true)).catchError((_) {});
      } else {
        await _registrations.doc(registrationId).update({
          'whatsappStatus': 'not_sent',
          'whatsappDeliveryMode': 'manual_admin',
          'whatsappError': 'Admin recorded message not sent.',
        }).catchError((_) {});

        await _notificationLogs.doc('${registrationId}_admin_wa').set({
          'id': '${registrationId}_admin_wa',
          'registrationId': registrationId,
          'eventId': eventId,
          'studentId': studentId,
          'studentName': studentName,
          'whatsappNumber': cleanPhone,
          'eventTitle': eventTitle,
          'deliveryMode': 'manual_admin',
          'status': 'not_sent',
          'adminUid': adminUid,
          'lastError': 'Admin recorded message not sent.',
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true)).catchError((_) {});
      }
    } catch (e) {
      debugPrint('Error recording admin WhatsApp confirmation: $e');
    }
  }
}

