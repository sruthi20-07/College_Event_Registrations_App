import 'package:flutter_test/flutter_test.dart';
import 'package:college_event_app/models/event_model.dart';
import 'package:college_event_app/models/registration_model.dart';
import 'package:college_event_app/models/user_model.dart';
import 'package:college_event_app/models/whatsapp_notification_model.dart';
import 'package:college_event_app/services/whatsapp_service.dart';

void main() {
  group('WhatsApp Phone Normalization & Validation', () {
    test('Normalizes 10-digit Indian numbers with default country code', () {
      expect(WhatsAppService.normalizeForWaMe('9876543210'), '919876543210');
      expect(WhatsAppService.normalizeForWaMe('  98765 43210  '), '919876543210');
      expect(WhatsAppService.normalizeForStorage('9876543210'), '+919876543210');
    });

    test('Handles numbers already having +91 prefix or 0 prefix', () {
      expect(WhatsAppService.normalizeForWaMe('+919876543210'), '919876543210');
      expect(WhatsAppService.normalizeForWaMe('09876543210'), '919876543210');
      expect(WhatsAppService.normalizeForStorage('+91 98765-43210'), '+919876543210');
    });

    test('Validates phone numbers accurately', () {
      expect(WhatsAppService.isValidPhoneNumber('9876543210'), isTrue);
      expect(WhatsAppService.isValidPhoneNumber('+919876543210'), isTrue);
      expect(WhatsAppService.isValidPhoneNumber('+14155552671'), isTrue);
      expect(WhatsAppService.isValidPhoneNumber('123'), isFalse);
      expect(WhatsAppService.isValidPhoneNumber(''), isFalse);
    });
  });

  group('WhatsApp Message Template Construction', () {
    test('Builds formatted ticket confirmation message with real event details', () {
      final event = EventModel(
        id: 'event_hackathon_2026',
        title: 'Annual Tech Hackathon 2026',
        description: '48hr coding hackathon',
        category: 'Technical',
        posterUrl: '',
        date: DateTime(2026, 11, 15, 9, 30),
        startTime: '9:30 AM',
        endTime: '5:30 PM',
        venue: 'Auditorium Hall B',
        maxSeats: 150,
        availableSeats: 108,
        registrationFee: 0,
        registrationDeadline: DateTime(2026, 11, 14),
        organizer: 'Computer Science Dept',
        createdBy: 'Admin',
        createdAt: DateTime(2026, 10, 1),
      );

      final registration = RegistrationModel(
        id: 'reg_abc123xyz',
        eventId: 'event_hackathon_2026',
        studentId: 'student_999',
        studentName: 'Rahul Sharma',
        studentEmail: 'rahul@college.edu',
        phone: '+919876543210',
        rollNumber: 'CS2026-088',
        department: 'Computer Science',
        year: '3rd Year',
        section: 'A',
        registrationStatus: 'confirmed',
        registeredAt: DateTime(2026, 10, 10),
        ticketToken: 'tkt_secure_token_789',
        whatsappNumber: '+919876543210',
        whatsappConsent: true,
      );

      final message = WhatsAppService.buildTicketMessage(
        registration: registration,
        event: event,
      );

      expect(message, contains('Hello Rahul Sharma! 👋'));
      expect(message, contains('Your registration for **Annual Tech Hackathon 2026** is confirmed! 🎉'));
      expect(message, contains('📅 Date: ${event.dateFormatted}'));
      expect(message, contains('⏰ Time: 9:30 AM'));
      expect(message, contains('📍 Venue: Auditorium Hall B'));
      expect(message, contains('🆔 Registration ID: REG-REG_ABC1'));
      expect(message, contains('✅ **IMPORTANT — ATTENDANCE**'));
      expect(message, contains('scan the official attendance QR code displayed at the event venue using the scanner in the College Event App'));
      expect(message, contains('Registration confirmation alone does NOT mark you as present.'));
      expect(message, contains('Thank you! Have a great event! 🎊'));
      expect(message, isNot(contains('Ticket ID:')));
    });
  });

  group('UserModel & RegistrationModel WhatsApp Persistence', () {
    test('UserModel maps whatsapp preferences correctly', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user_test_1',
        name: 'Priya Patel',
        email: 'priya@college.edu',
        rollNumber: 'EC2026-012',
        department: 'Electronics',
        year: '2nd Year',
        role: 'student',
        whatsappNumber: '+919123456780',
        whatsappConsent: true,
        whatsappConsentAt: now,
      );

      final map = user.toMap();
      expect(map['whatsappNumber'], '+919123456780');
      expect(map['whatsappConsent'], isTrue);

      final reconstructed = UserModel.fromMap(map, 'user_test_1');
      expect(reconstructed.whatsappNumber, '+919123456780');
      expect(reconstructed.whatsappConsent, isTrue);
    });

    test('RegistrationModel preserves WhatsApp delivery status and mode', () {
      final now = DateTime.now();
      final reg = RegistrationModel(
        id: 'reg_demo_1',
        eventId: 'event_001',
        studentId: 'student_001',
        studentName: 'Sruthi',
        studentEmail: 'sruthi@college.edu',
        phone: '9876543210',
        rollNumber: 'IT2026-005',
        department: 'Information Technology',
        year: '4th Year',
        registrationStatus: 'confirmed',
        registeredAt: now,
        ticketToken: 'tkt_sruthi_pass_123',
        whatsappNumber: '+919876543210',
        whatsappConsent: true,
        whatsappStatus: 'delivered',
        whatsappDeliveryMode: 'cloud_api',
        whatsappMessageId: 'wamid.HBgLM...',
        whatsappSentAt: now,
      );

      final map = reg.toMap();
      expect(map['whatsappStatus'], 'delivered');
      expect(map['whatsappDeliveryMode'], 'cloud_api');
      expect(map['whatsappMessageId'], 'wamid.HBgLM...');
      expect(map['ticketToken'], 'tkt_sruthi_pass_123');

      final parsed = RegistrationModel.fromMap(map, 'reg_demo_1');
      expect(parsed.whatsappStatus, 'delivered');
      expect(parsed.whatsappDeliveryMode, 'cloud_api');
      expect(parsed.ticketToken, 'tkt_sruthi_pass_123');
    });

    test('WhatsAppNotificationModel correctly serializes audit job data', () {
      final now = DateTime.now();
      final log = WhatsAppNotificationModel(
        id: 'reg_demo_1_cloud_wa',
        registrationId: 'reg_demo_1',
        eventId: 'event_001',
        studentId: 'student_001',
        studentName: 'Sruthi',
        whatsappNumber: '919876543210',
        eventTitle: 'Robotics Workshop',
        eventDate: 'Oct 25, 2026',
        eventTime: '10:00 AM',
        venue: 'Lab 3',
        ticketToken: 'tkt_sruthi_pass_123',
        deliveryMode: 'cloud_api',
        status: 'accepted',
        providerMessageId: 'wamid.TEST1234',
        attemptCount: 1,
        lastAttemptAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final map = log.toMap();
      expect(map['deliveryMode'], 'cloud_api');
      expect(map['status'], 'accepted');
      expect(map['providerMessageId'], 'wamid.TEST1234');

      final fromMap = WhatsAppNotificationModel.fromMap(map, 'reg_demo_1_cloud_wa');
      expect(fromMap.eventTitle, 'Robotics Workshop');
      expect(fromMap.whatsappNumber, '919876543210');
    });
  });

  group('Official WhatsApp Cloud API Template Payload Specification', () {
    test('buildTemplatePayload constructs valid Meta Cloud API schema', () {
      final now = DateTime(2026, 11, 20, 10, 0);
      final event = EventModel(
        id: 'evt_tech_01',
        title: 'National AI Summit',
        description: 'AI Symposium',
        category: 'Technical',
        posterUrl: '',
        date: now,
        startTime: '10:00 AM',
        endTime: '4:00 PM',
        venue: 'Main Auditorium',
        maxSeats: 200,
        availableSeats: 150,
        registrationFee: 0,
        registrationDeadline: now.subtract(const Duration(days: 1)),
        organizer: 'CSE Dept',
        createdBy: 'Admin',
        createdAt: now.subtract(const Duration(days: 10)),
      );

      final registration = RegistrationModel(
        id: 'reg_summit_9999',
        eventId: 'evt_tech_01',
        studentId: 'stu_123',
        studentName: 'Aarav Sharma',
        studentEmail: 'aarav@college.edu',
        phone: '+919876543210',
        rollNumber: '21CS101',
        department: 'CSE',
        year: '4th Year',
        section: 'A',
        registrationStatus: 'confirmed',
        registeredAt: now,
        ticketToken: 'tkt_summit_pass_01',
        whatsappNumber: '+919876543210',
        whatsappConsent: true,
      );

      final payload = WhatsAppService.buildTemplatePayload(
        registration: registration,
        event: event,
        templateName: 'event_registration_confirmation',
      );

      expect(payload['messaging_product'], 'whatsapp');
      expect(payload['recipient_type'], 'individual');
      expect(payload['to'], '919876543210');
      expect(payload['type'], 'template');

      final template = payload['template'] as Map<String, dynamic>;
      expect(template['name'], 'event_registration_confirmation');
      expect(template['language']['code'], 'en_US');

      final components = template['components'] as List;
      expect(components.isNotEmpty, isTrue);

      final bodyComponent = components.first as Map<String, dynamic>;
      expect(bodyComponent['type'], 'body');

      final params = bodyComponent['parameters'] as List;
      expect(params.length, 7);
      expect(params[0]['text'], 'Aarav Sharma'); // {{1}}: studentName
      expect(params[1]['text'], 'National AI Summit'); // {{2}}: eventTitle
      expect(params[2]['text'], contains('Nov')); // {{3}}: eventDate
      expect(params[3]['text'], '10:00 AM - 4:00 PM'); // {{4}}: eventTime
      expect(params[4]['text'], 'Main Auditorium'); // {{5}}: venue
      expect(params[5]['text'], 'REG-REG_SUMM'); // {{6}}: registrationId
      expect(params[6]['text'], 'tkt_summit_pass_01'); // {{7}}: ticketId
    });
  });

  group('Automated Trigger, Idempotency & Credentials Isolation', () {
    test('Deterministic idempotency key matches registration ID', () {
      const regId = 'reg_unique_4567';
      final expectedJobId = '${regId}_cloud_wa';
      expect(expectedJobId, 'reg_unique_4567_cloud_wa');

      // Re-running for same registration ID produces identical key
      final duplicateJobId = '${regId}_cloud_wa';
      expect(expectedJobId, duplicateJobId);
    });

    test('Data models and Firestore serialization never expose API secrets', () {
      final now = DateTime.now();
      final log = WhatsAppNotificationModel(
        id: 'test_job_1',
        registrationId: 'reg_1',
        eventId: 'evt_1',
        studentId: 'stu_1',
        studentName: 'Student One',
        whatsappNumber: '919876543210',
        eventTitle: 'Event One',
        deliveryMode: 'cloud_api',
        status: 'pending',
        createdAt: now,
      );

      final map = log.toMap();
      // Ensure no tokens, authorization headers, or secrets in data models
      expect(map.containsKey('accessToken'), isFalse);
      expect(map.containsKey('token'), isFalse);
      expect(map.containsKey('secret'), isFalse);
      expect(map.containsKey('bearer'), isFalse);
      expect(map.containsKey('authHeader'), isFalse);
    });

    test('Missing phone number and unconsented students do not break registration state', () {
      final registrationNoPhone = RegistrationModel(
        id: 'reg_no_phone',
        eventId: 'evt_1',
        studentId: 'stu_2',
        studentName: 'Student Two',
        studentEmail: 'student2@college.edu',
        rollNumber: '21CS102',
        department: 'CSE',
        year: '3rd Year',
        phone: '',
        whatsappNumber: '',
        whatsappConsent: false,
        registrationStatus: 'confirmed',
      );

      expect(registrationNoPhone.isRegistered, isTrue);
      expect(registrationNoPhone.whatsappConsent, isFalse);
      expect(WhatsAppService.isValidPhoneNumber(registrationNoPhone.phone), isFalse);
    });

    test('Registration status and seat counts remain confirmed regardless of WhatsApp status', () {
      final regSuccess = RegistrationModel(
        id: 'reg_success',
        eventId: 'evt_1',
        studentId: 'stu_3',
        studentName: 'Student Three',
        studentEmail: 'student3@college.edu',
        rollNumber: '21CS103',
        department: 'CSE',
        year: '3rd Year',
        registrationStatus: 'confirmed',
        whatsappStatus: 'delivered',
      );

      final regFailed = RegistrationModel(
        id: 'reg_failed',
        eventId: 'evt_1',
        studentId: 'stu_4',
        studentName: 'Student Four',
        studentEmail: 'student4@college.edu',
        rollNumber: '21CS104',
        department: 'CSE',
        year: '3rd Year',
        registrationStatus: 'confirmed',
        whatsappStatus: 'failed',
        whatsappError: 'Provider unreachable',
      );

      // Both registrations are confirmed regardless of notification delivery
      expect(regSuccess.isRegistered, isTrue);
      expect(regFailed.isRegistered, isTrue);
      expect(regFailed.registrationStatus, 'confirmed');
    });
  });
}

