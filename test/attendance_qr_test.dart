import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:college_event_app/models/attendance_session_model.dart';
import 'package:college_event_app/models/attendance_scan_result.dart';
import 'package:college_event_app/models/registration_model.dart';
import 'package:college_event_app/models/event_model.dart';
import 'package:college_event_app/services/event_service.dart';

void main() {
  group('A. AttendanceQrPayload - Cryptographic Token & Serialization', () {
    test('Creates short-lived payload with valid nonce and signature hash', () {
      final payload = AttendanceQrPayload.create(
        eventId: 'EVT_AI_CON_2026',
        sessionId: 'SES_998811',
        adminUid: 'ADMIN_SUPER_UID',
        validDurationSeconds: 15,
      );

      expect(payload.type, AttendanceQrPayload.qrType);
      expect(payload.eventId, 'EVT_AI_CON_2026');
      expect(payload.sessionId, 'SES_998811');
      expect(payload.nonce.length, greaterThanOrEqualTo(12));
      expect(payload.hash, isNotEmpty);
      expect(payload.isExpired, isFalse);
      expect(payload.expiresAt, greaterThan(payload.timestamp));
    });

    test('Payload serializes to JSON string and parses back accurately', () {
      final payload = AttendanceQrPayload.create(
        eventId: 'EVT_TECH_01',
        sessionId: 'SES_ALPHA',
        adminUid: 'ADMIN_01',
        validDurationSeconds: 20,
      );

      final rawString = payload.toRawString();
      expect(rawString.startsWith('{'), isTrue);
      expect(rawString.endsWith('}'), isTrue);

      final parsed = AttendanceQrPayload.tryParse(rawString);
      expect(parsed, isNotNull);
      expect(parsed!.eventId, 'EVT_TECH_01');
      expect(parsed.sessionId, 'SES_ALPHA');
      expect(parsed.nonce, payload.nonce);
      expect(parsed.timestamp, payload.timestamp);
      expect(parsed.expiresAt, payload.expiresAt);
      expect(parsed.hash, payload.hash);
    });

    test('Consecutive payloads have unique random nonces and hashes (Token Rotation)', () {
      final p1 = AttendanceQrPayload.create(
        eventId: 'EVT_100',
        sessionId: 'SES_100',
        adminUid: 'ADMIN_X',
        validDurationSeconds: 15,
      );
      final p2 = AttendanceQrPayload.create(
        eventId: 'EVT_100',
        sessionId: 'SES_100',
        adminUid: 'ADMIN_X',
        validDurationSeconds: 15,
      );

      expect(p1.nonce, isNot(equals(p2.nonce)));
      expect(p1.hash, isNot(equals(p2.hash)));
    });

    test('Rejects invalid, corrupt, or empty QR payload strings', () {
      expect(AttendanceQrPayload.tryParse(''), isNull);
      expect(AttendanceQrPayload.tryParse('hello world'), isNull);
      expect(AttendanceQrPayload.tryParse('{"invalid":"json"}'), isNull);
      expect(AttendanceQrPayload.tryParse('tkt_standard_ticket_token'), isNull);
    });

    test('Correctly identifies expired payloads', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final pastPayload = AttendanceQrPayload(
        eventId: 'EVT_PAST',
        sessionId: 'SES_PAST',
        nonce: 'abc123nonce',
        timestamp: now - 30000,
        expiresAt: now - 10000, // Expired 10 seconds ago
        hash: 'hashpast123',
      );

      expect(pastPayload.isExpired, isTrue);
    });
  });

  group('B. Event Unique QR Code & Token Generation (Non-Interchangeable)', () {
    test('Generates distinct tokens for different events', () {
      final tokenA = EventService.generateEventQrToken('EVENT_HACKATHON_A');
      final tokenB = EventService.generateEventQrToken('EVENT_SYMPOSIUM_B');

      expect(tokenA, startsWith('evtok_EVENT_HACKATHON_A_'));
      expect(tokenB, startsWith('evtok_EVENT_SYMPOSIUM_B_'));
      expect(tokenA, isNot(equals(tokenB)));
    });

    test('EventModel uniqueQrPayload contains correct eventId, title, and token', () {
      final event = EventModel(
        id: 'EVT_ROBO_2026',
        title: 'Robotics Championship 2026',
        description: 'Annual robotics battle',
        category: 'Technical',
        date: DateTime(2026, 11, 15),
        startTime: '10:00 AM',
        endTime: '4:00 PM',
        venue: 'Auditorium Hall',
        organizer: 'Robotics Club',
        maxSeats: 150,
        availableSeats: 80,
        registrationFee: 0,
        registrationDeadline: DateTime(2026, 11, 14),
        qrToken: 'evtok_EVT_ROBO_2026_abcdef1234567890',
      );

      expect(event.hasQrCode, isTrue);
      expect(event.isPublished, isTrue);

      final payloadJson = event.uniqueQrPayload;
      final decoded = jsonDecode(payloadJson) as Map<String, dynamic>;

      expect(decoded['type'], 'event_attendance_qr');
      expect(decoded['eventId'], 'EVT_ROBO_2026');
      expect(decoded['token'], 'evtok_EVT_ROBO_2026_abcdef1234567890');
      expect(decoded['title'], 'Robotics Championship 2026');
    });

    test('AttendanceQrPayload parses direct event JSON payload properly', () {
      final event = EventModel(
        id: 'EVT_CYBER_SEC',
        title: 'Cyber Security Workshop',
        description: 'Ethical hacking session',
        category: 'Workshop',
        date: DateTime(2026, 12, 1),
        startTime: '09:00 AM',
        endTime: '01:00 PM',
        venue: 'Lab 4',
        organizer: 'IT Dept',
        maxSeats: 60,
        availableSeats: 10,
        registrationFee: 0,
        registrationDeadline: DateTime(2026, 11, 30),
        qrToken: 'evtok_EVT_CYBER_SEC_9988aabbccddeeff',
      );

      final parsed = AttendanceQrPayload.tryParse(event.uniqueQrPayload);
      expect(parsed, isNotNull);
      expect(parsed!.eventId, 'EVT_CYBER_SEC');
      expect(parsed.hash, 'evtok_EVT_CYBER_SEC_9988aabbccddeeff');
      expect(parsed.isExpired, isFalse);
    });

    test('Event tokens are strictly non-interchangeable', () {
      final tokenA = EventService.generateEventQrToken('EVENT_A');
      final tokenB = EventService.generateEventQrToken('EVENT_B');

      final parsedA = AttendanceQrPayload.tryParse(jsonEncode({
        'type': 'event_attendance_qr',
        'eventId': 'EVENT_A',
        'token': tokenA,
      }));

      final parsedB = AttendanceQrPayload.tryParse(jsonEncode({
        'type': 'event_attendance_qr',
        'eventId': 'EVENT_B',
        'token': tokenB,
      }));

      expect(parsedA, isNotNull);
      expect(parsedB, isNotNull);

      // Verify that parsedA belongs ONLY to EVENT_A and not EVENT_B
      expect(parsedA!.eventId, 'EVENT_A');
      expect(parsedA.eventId, isNot(equals('EVENT_B')));
      expect(parsedA.hash, startsWith('evtok_EVENT_A_'));

      expect(parsedB!.eventId, 'EVENT_B');
      expect(parsedB.eventId, isNot(equals('EVENT_A')));
      expect(parsedB.hash, startsWith('evtok_EVENT_B_'));
    });

    test('Raw token format evtok_eventId_hash parses correctly into AttendanceQrPayload', () {
      const rawToken = 'evtok_EVT_CODING_JAM_1234567890abcdef';
      final parsed = AttendanceQrPayload.tryParse(rawToken);

      expect(parsed, isNotNull);
      expect(parsed!.eventId, 'EVT_CODING_JAM');
      expect(parsed.hash, rawToken);
    });
  });

  group('C. AttendanceSessionModel - Admin Session Management', () {
    test('AttendanceSessionModel serializes and deserializes Firestore maps', () {
      final now = DateTime(2026, 10, 10, 14, 30);
      final session = AttendanceSessionModel(
        id: 'SES_DOC_001',
        eventId: 'EVT_MUSIC_FEST',
        eventTitle: 'Annual Music Fest 2026',
        createdByAdminUid: 'ADMIN_SARAH',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 2)),
        isActive: true,
        refreshIntervalSeconds: 15,
        currentNonce: 'nonce_live_01',
        currentHash: 'hash_live_01',
        attendeeCount: 42,
      );

      final map = session.toMap();
      expect(map['eventId'], 'EVT_MUSIC_FEST');
      expect(map['isActive'], isTrue);
      expect(map['attendeeCount'], 42);
      expect(map['refreshIntervalSeconds'], 15);

      final copy = session.copyWith(
        isActive: false,
        closedAt: now.add(const Duration(hours: 1)),
        attendeeCount: 43,
      );
      expect(copy.isActive, isFalse);
      expect(copy.attendeeCount, 43);
      expect(copy.closedAt, isNotNull);
    });
  });

  group('D. AttendanceScanResult - Statuses and UI Messages', () {
    test('Verified status returns appropriate title and success flag', () {
      final result = AttendanceScanResult(
        status: AttendanceScanStatus.verified,
        message: 'Attendance recorded successfully!',
        coinsEarned: 50,
        eventTitle: 'Hackathon 2026',
      );

      expect(result.isSuccess, isTrue);
      expect(result.isAlreadyCheckedIn, isFalse);
      expect(result.title, 'Attendance Verified ✓');
      expect(result.coinsEarned, 50);
      expect(result.eventTitle, 'Hackathon 2026');
    });

    test('Already checked in status handled with proper feedback', () {
      final result = const AttendanceScanResult(
        status: AttendanceScanStatus.alreadyCheckedIn,
        message: 'You have already checked in for this event.',
      );

      expect(result.isSuccess, isFalse);
      expect(result.isAlreadyCheckedIn, isTrue);
      expect(result.title, 'Already Checked In');
    });

    test('Session expired status handled with clear warning', () {
      final result = const AttendanceScanResult(
        status: AttendanceScanStatus.sessionExpired,
        message: 'This QR code has expired. Please scan the current code.',
      );

      expect(result.isSuccess, isFalse);
      expect(result.title, 'QR Code Expired');
    });

    test('Not registered status indicates missing registration', () {
      final result = const AttendanceScanResult(
        status: AttendanceScanStatus.notRegistered,
        message: 'You are not registered for this event.',
      );

      expect(result.isSuccess, isFalse);
      expect(result.title, 'Not Registered');
    });

    test('Ineligible student status returns clear rejection', () {
      final result = const AttendanceScanResult(
        status: AttendanceScanStatus.ineligible,
        message: 'Department not eligible.',
      );

      expect(result.isSuccess, isFalse);
      expect(result.title, 'Ineligible for Event');
    });

    test('Session inactive / closed status returns proper message', () {
      final result = const AttendanceScanResult(
        status: AttendanceScanStatus.sessionInactive,
        message: 'Attendance is currently closed.',
      );

      expect(result.isSuccess, isFalse);
      expect(result.title, 'Attendance Closed');
    });
  });

  group('E. Backward Compatibility with Individual Registration Tickets', () {
    test('Individual ticket tokens and check-in methods coexist peacefully', () {
      final reg = RegistrationModel(
        id: 'REG_INDIVIDUAL_01',
        eventId: 'EVT_ROBOTICS',
        eventTitle: 'Robotics Workshop',
        studentId: 'STU_101',
        studentName: 'Aarav Sharma',
        studentEmail: 'aarav@college.edu',
        rollNumber: '21CS045',
        department: 'CSE',
        year: '3rd Year',
        ticketToken: 'tkt_8a9b7c6d5e4f3a2b1c0d',
        registeredAt: DateTime.now(),
        registrationStatus: 'confirmed',
        attended: false,
      );

      expect(reg.ticketToken, startsWith('tkt_'));
      expect(reg.isAttended, isFalse);

      final markedReg = reg.copyWith(
        attended: true,
        attendanceStatus: 'attended',
        attendedAt: DateTime.now(),
      );
      expect(markedReg.isAttended, isTrue);
      expect(markedReg.ticketToken, reg.ticketToken);
    });
  });

  group('F. Attendance Session Lifecycle & End Session Validation', () {
    test('AttendanceSessionModel transitions cleanly to ended state upon session termination', () {
      final now = DateTime.now();
      final activeSession = AttendanceSessionModel(
        id: 'SES_ACTIVE_001',
        eventId: 'EVT_AI_SUMMIT',
        eventTitle: 'AI Summit 2026',
        createdByAdminUid: 'ADMIN_01',
        createdAt: now,
        isActive: true,
        refreshIntervalSeconds: 15,
        currentNonce: 'nonce123456',
        currentHash: 'hash123456',
        attendeeCount: 12,
      );

      expect(activeSession.isActive, isTrue);
      expect(activeSession.closedAt, isNull);
      expect(activeSession.attendeeCount, 12);

      final closedAt = now.add(const Duration(minutes: 45));
      final endedSession = activeSession.copyWith(
        isActive: false,
        closedAt: closedAt,
      );

      expect(endedSession.isActive, isFalse);
      expect(endedSession.closedAt, closedAt);
      expect(endedSession.attendeeCount, 12); // Preserves existing attendee count
      expect(endedSession.eventId, 'EVT_AI_SUMMIT');
    });

    test('Expired token is rejected when compared against current time', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final expiredPayload = AttendanceQrPayload(
        eventId: 'EVT_EXPIRED_TEST',
        sessionId: 'SES_OLD',
        nonce: 'old_nonce',
        timestamp: nowMs - 30000,
        expiresAt: nowMs - 5000,
        hash: 'old_hash',
      );

      expect(expiredPayload.isExpired, isTrue);
    });

    test('Active payload with remaining validity is not expired', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final activePayload = AttendanceQrPayload(
        eventId: 'EVT_VALID_TEST',
        sessionId: 'SES_NEW',
        nonce: 'new_nonce',
        timestamp: nowMs,
        expiresAt: nowMs + 15000,
        hash: 'new_hash',
      );

      expect(activePayload.isExpired, isFalse);
    });
  });
}

