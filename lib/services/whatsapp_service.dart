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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  static String buildTicketMessage({
    required RegistrationModel registration,
    required EventModel event,
  }) {
    final String studentName = registration.studentName.isNotEmpty
        ? registration.studentName
        : 'Student';

    final String eventTitle = event.title.isNotEmpty
        ? event.title
        : registration.eventTitle;

    final String eventDate = event.dateFormatted.isNotEmpty
        ? event.dateFormatted
        : registration.eventDate;

    final String eventTime = event.time.isNotEmpty ? event.time : '10:00 AM - 4:00 PM';

    final String venue = event.venue.isNotEmpty
        ? event.venue
        : (registration.venue.isNotEmpty ? registration.venue : 'College Campus');

    final String formattedRegId = registration.id.length > 8
        ? 'REG-${registration.id.substring(0, 8).toUpperCase()}'
        : 'REG-${registration.id.toUpperCase()}';

    final String ticketId = registration.ticketToken.isNotEmpty
        ? registration.ticketToken
        : formattedRegId;

    return 'Hello $studentName!\n\n'
        'Your registration for $eventTitle is confirmed.\n\n'
        'Event: $eventTitle\n'
        'Date: $eventDate\n'
        'Time: $eventTime\n'
        'Venue: $venue\n'
        'Registration ID: $formattedRegId\n'
        'Ticket ID: $ticketId\n\n'
        'Please open your event ticket in the College Event App and present your QR code at the entrance.\n\n'
        'Thank you!';
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

  /// Streams real-time WhatsApp notification status for a registration
  Stream<WhatsAppNotificationModel?> streamNotificationLog(String registrationId) {
    if (registrationId.isEmpty) return Stream.value(null);
    return _notificationLogs
        .where('registrationId', isEqualTo: registrationId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return WhatsAppNotificationModel.fromSnapshot(snapshot.docs.first);
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
}
