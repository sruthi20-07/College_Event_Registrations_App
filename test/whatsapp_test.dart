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

      expect(message, contains('Hello Rahul Sharma!'));
      expect(message, contains('Your registration for Annual Tech Hackathon 2026 is confirmed.'));
      expect(message, contains('Event: Annual Tech Hackathon 2026'));
      expect(message, contains('Time: 9:30 AM - 5:30 PM'));
      expect(message, contains('Venue: Auditorium Hall B'));
      expect(message, contains('Registration ID: REG-REG_ABC1'));
      expect(message, contains('Ticket ID: tkt_secure_token_789'));
      expect(message, contains('Please open your event ticket in the College Event App and present your QR code at the entrance.'));
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
}
