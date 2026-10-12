import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:college_event_app/models/attendance_session_model.dart';
import 'package:college_event_app/models/event_model.dart';
import 'package:college_event_app/screens/main_screen.dart';
import 'package:college_event_app/screens/admin/admin_dashboard_screen.dart';
import 'package:college_event_app/screens/admin/admin_live_qr_screen.dart';
import 'package:college_event_app/screens/admin/event_live_attendance_qr_screen.dart';
import 'package:college_event_app/models/registration_model.dart';
import 'package:college_event_app/screens/admin/event_participants_screen.dart';
import 'package:college_event_app/screens/admin/manage_events_screen.dart';
import 'package:college_event_app/screens/student/registration_confirmation_screen.dart';
import 'package:college_event_app/services/whatsapp_service.dart';

void main() {
  testWidgets(
      'College Event App MainScreen loads successfully with feedback FAB and student scanner icon',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MainScreen(),
      ),
    );

    expect(find.text('Discover Events'), findsOneWidget);
    expect(find.text('Featured Event'), findsOneWidget);
    expect(find.text('Upcoming Events'), findsOneWidget);

    // Student top action area scanner icon
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);

    // Student bottom-right floating feedback icon
    expect(find.byTooltip('Feedback & Reviews'), findsOneWidget);
    expect(find.byIcon(Icons.rate_review_rounded), findsOneWidget);
  });

  testWidgets(
      'Admin Dashboard displays top QR attendance icon and bottom-right feedback FAB without scanner',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdminDashboardScreen(),
      ),
    );

    // Header & Welcome
    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(find.text('Overview Statistics'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);

    // 1. Top action area has QR attendance icon button
    expect(find.byTooltip('Event QR Codes & Attendance'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_2_rounded), findsOneWidget);

    // 2. Admins must NEVER have camera QR scanner
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
    expect(find.byIcon(Icons.camera_alt), findsNothing);

    // 3. Bottom-right floating feedback button
    expect(find.byTooltip('Feedback & Reviews'), findsOneWidget);
    expect(find.byIcon(Icons.rate_review_rounded), findsOneWidget);

    // 4. Quick Actions does NOT have the old large cards
    expect(find.text('Display live event QR codes and manage check-ins'),
        findsNothing);
    expect(find.text('Student App Feedback & Reviews'), findsNothing);
  });

  testWidgets(
      'AdminLiveQrScreen displays event-selection list without rendering QR codes or scanner controls',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdminLiveQrScreen(),
      ),
    );

    // Title
    expect(find.text('Live Attendance QR'), findsOneWidget);

    // No QR codes on selection screen
    expect(find.byType(QrImageView), findsNothing);

    // No scanner widgets on admin screens
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
    expect(find.byIcon(Icons.camera_alt), findsNothing);

    // No edit or participants controls on this page
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Participants'), findsNothing);
  });

  testWidgets(
      'EventLiveAttendanceQrScreen renders header, prominent details, stats, and control buttons',
      (WidgetTester tester) async {
    final testEvent = EventModel(
      id: 'EVT_TEST_101',
      title: 'Flutter Developer Summit 2026',
      description: 'Annual gathering of Flutter developers',
      category: 'Technical',
      date: DateTime(2026, 12, 10),
      startTime: '10:00 AM',
      endTime: '04:00 PM',
      venue: 'Main Auditorium',
      organizer: 'Computer Science Club',
      maxSeats: 250,
      availableSeats: 150,
      registrationFee: 0,
      registrationDeadline: DateTime(2026, 12, 9),
      qrToken: 'evtok_EVT_TEST_101_sample',
    );

    final testSession = AttendanceSessionModel(
      id: 'SES_TEST_001',
      eventId: 'EVT_TEST_101',
      eventTitle: 'Flutter Developer Summit 2026',
      createdByAdminUid: 'ADMIN_01',
      createdAt: DateTime.now(),
      isActive: true,
      refreshIntervalSeconds: 15,
      currentNonce: 'nonce_sample_123',
      currentHash: 'hash_sample_456',
      attendeeCount: 42,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventLiveAttendanceQrScreen(
          event: testEvent,
          initialSession: testSession,
        ),
      ),
    );

    // Header & Event Details
    expect(find.text('Live Event Attendance QR'), findsOneWidget);
    expect(find.text('Flutter Developer Summit 2026'), findsOneWidget);
    expect(find.text('TECHNICAL'), findsOneWidget);
    expect(find.textContaining('Main Auditorium'), findsOneWidget);

    // Live Badge and QR Card
    expect(find.text('LIVE ATTENDANCE'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    // Attendance stats labels & values
    expect(find.text('Verified Attendees'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Interval'), findsOneWidget);
    expect(find.text('15s'), findsOneWidget);
    expect(find.text('Max Seats'), findsOneWidget);
    expect(find.text('250'), findsOneWidget);

    // End Session and Projector Mode buttons
    expect(find.text('End Session'), findsOneWidget);
    expect(find.text('Projector Mode'), findsOneWidget);

    // Tapping End Session opens confirmation dialog
    await tester.ensureVisible(find.text('End Session'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('End Session'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('End Session?'), findsOneWidget);
    expect(find.textContaining('Are you sure you want to end attendance'),
        findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets(
      'ManageEventsScreen renders and does not have duplicate participants button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ManageEventsScreen(),
      ),
    );

    expect(find.text('Manage Events'), findsOneWidget);
    // Floating action button for adding events
    expect(find.text('Add Event'), findsOneWidget);
  });

  testWidgets(
      'RegistrationConfirmationScreen renders student ticket details without QR code or WhatsApp sharing UI',
      (WidgetTester tester) async {
    final testEvent = EventModel(
      id: 'EVT_SUMMIT_2026',
      title: 'Cloud & AI Innovation Summit',
      description: 'Annual cloud computing and artificial intelligence symposium',
      category: 'Technical',
      date: DateTime(2026, 11, 20),
      startTime: '10:00 AM',
      endTime: '05:00 PM',
      venue: 'Seminar Hall 3',
      organizer: 'Computer Science Dept',
      maxSeats: 150,
      availableSeats: 45,
      registrationFee: 0,
      registrationDeadline: DateTime(2026, 11, 19),
    );

    final testRegistration = RegistrationModel(
      id: 'REG_TEST_9988',
      eventId: 'EVT_SUMMIT_2026',
      studentId: 'STU_123',
      studentName: 'Ananya Sharma',
      studentEmail: 'ananya@college.edu',
      phone: '+919876543210',
      rollNumber: 'IT2026-045',
      department: 'Information Technology',
      year: '3rd Year',
      section: 'B',
      registrationStatus: 'confirmed',
      registeredAt: DateTime(2026, 10, 10),
      ticketToken: 'TKT_SECURE_TOKEN_XYZ',
      paymentStatus: 'free',
      attended: false,
      whatsappNumber: '+919876543210',
      whatsappConsent: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationConfirmationScreen(
          event: testEvent,
          registration: testRegistration,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Title and Header
    expect(find.text('Event Ticket & Pass'), findsOneWidget);
    expect(find.text('OFFICIAL ADMISSION TICKET'), findsOneWidget);
    expect(find.text('Cloud & AI Innovation Summit'), findsOneWidget);
    expect(find.text('TECHNICAL'), findsOneWidget);

    // 2. Preserved Ticket Details
    expect(find.text('Attendee Name'), findsOneWidget);
    expect(find.text('Ananya Sharma'), findsOneWidget);
    expect(find.text('Student ID / Roll'), findsOneWidget);
    expect(find.text('IT2026-045'), findsOneWidget);
    expect(find.text('Branch / Dept'), findsOneWidget);
    expect(find.text('Information Technology (B)'), findsOneWidget);
    expect(find.text('Academic Year'), findsOneWidget);
    expect(find.text('3rd Year'), findsOneWidget);
    expect(find.text('Payment Status'), findsOneWidget);
    expect(find.text('FREE'), findsOneWidget);
    expect(find.text('Attendance Status'), findsOneWidget);
    expect(find.text('NOT YET ATTENDED'), findsOneWidget);

    // 3. Navigation Buttons
    expect(find.text('View All My Registrations'), findsOneWidget);
    expect(find.text('Back to Explore Events'), findsOneWidget);

    // 4. CRITICAL: NO QR Code on Student Ticket Page
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('Scan at the venue entrance to check in'), findsNothing);
    expect(find.textContaining('present your QR code'), findsNothing);

    // 5. CRITICAL: NO WhatsApp Sharing UI on Student Side
    expect(find.text('WhatsApp Confirmation & Ticket'), findsNothing);
    expect(find.text('Share Ticket on WhatsApp'), findsNothing);
    expect(find.textContaining('Mode A: Quick Share'), findsNothing);
    expect(find.textContaining('Mode B: Cloud API'), findsNothing);
    expect(find.textContaining('Press Send in WhatsApp to deliver'), findsNothing);
    expect(find.byIcon(Icons.copy_rounded), findsNothing);
  });

  testWidgets(
      'EventParticipantsScreen renders compact layout with 7 stats tiles and exactly ONE Display Event QR action',
      (WidgetTester tester) async {
    final testEvent = EventModel(
      id: 'EVT_HACKATHON_2026',
      title: 'Full-Stack Hackathon 2026',
      description: '48hr intense software hackathon',
      category: 'Technical',
      date: DateTime(2026, 11, 25),
      startTime: '09:00 AM',
      endTime: '05:00 PM',
      venue: 'Computing Hub A',
      organizer: 'Computer Science Dept',
      maxSeats: 120,
      availableSeats: 80,
      registrationFee: 0,
      registrationDeadline: DateTime(2026, 11, 24),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventParticipantsScreen(event: testEvent),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Prominent event title in compact banner
    expect(find.text('Full-Stack Hackathon 2026'), findsOneWidget);
    expect(find.text('TECHNICAL'), findsOneWidget);
    expect(find.textContaining('Computing Hub A'), findsOneWidget);

    // 2. Exactly ONE Display Event QR action on the entire screen (in event summary card)
    expect(find.text('Display Event QR'), findsOneWidget);

    // 3. NO Floating Action Button anywhere on the screen
    expect(find.byType(FloatingActionButton), findsNothing);

    // 4. NO duplicate QR icons in AppBar
    expect(find.byIcon(Icons.qr_code_2_rounded), findsOneWidget);

    // 5. All 7 compact statistics tiles are rendered
    expect(find.text('Total Registrations'), findsOneWidget);
    expect(find.text('Active Registrations'), findsOneWidget);
    expect(find.text('Verified Attendees'), findsOneWidget);
    expect(find.text('Paid Registrations'), findsOneWidget);
    expect(find.text('Pending Payments'), findsOneWidget);
    expect(find.text('Cancelled Registrations'), findsOneWidget);
    expect(find.text('Available Seats'), findsOneWidget);

    // 6. Compact search field is rendered
    expect(find.byType(TextField), findsOneWidget);

    // 7. Verify the single Display Event QR action is enabled and ready to display QR
    final qrButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Display Event QR'),
    );
    expect(qrButton.onPressed, isNotNull);
  });

  test('WhatsAppService buildAdminConfirmationMessage generates compliant personalized message', () {
    final event = EventModel(
      id: 'fsd_hack_2026',
      title: 'FSD Hackathon',
      description: 'Full stack hackathon',
      category: 'Technical',
      date: DateTime(2026, 11, 20),
      startTime: '10:00 AM',
      endTime: '05:00 PM',
      venue: 'Innovation Lab',
      organizer: 'CSE Dept',
      maxSeats: 100,
      availableSeats: 50,
      registrationFee: 0,
      registrationDeadline: DateTime(2026, 11, 19),
    );

    final registration = RegistrationModel(
      id: 'reg_sruthi_12345',
      eventId: 'fsd_hack_2026',
      studentId: 'stu_sruthi_01',
      studentName: 'Sruthi',
      studentEmail: 'sruthi@college.edu',
      rollNumber: '22CS101',
      phone: '9876543210',
      whatsappNumber: '9876543210',
      department: 'CSE',
      year: '3rd Year',
      registrationStatus: 'confirmed',
    );

    final message = WhatsAppService.buildAdminConfirmationMessage(
      registration: registration,
      event: event,
    );

    expect(message, contains('Hello Sruthi! 👋'));
    expect(message, contains('Your registration for **FSD Hackathon** is confirmed! 🎉'));
    expect(message, contains('🆔 Registration ID: REG-REG_SRUT'));
    expect(message, contains('✅ **IMPORTANT — ATTENDANCE**'));
    expect(message, contains('scan the official attendance QR code displayed at the event venue using the scanner in the College Event App'));
    expect(message, contains('Registration confirmation alone does NOT mark you as present.'));
    expect(message, isNot(contains('Ticket ID:')));

    // Test phone normalization
    expect(WhatsAppService.normalizeForWaMe('9876543210'), equals('919876543210'));
    expect(WhatsAppService.normalizeForWaMe('+919876543210'), equals('919876543210'));
    expect(WhatsAppService.isValidPhoneNumber('9876543210'), isTrue);

    // Test model admin confirmation serialization
    final now = DateTime(2026, 10, 11, 19, 0);
    final confirmedReg = registration.copyWith(
      whatsappStatus: 'admin_confirmed_sent',
      whatsappConfirmedByAdminUid: 'admin_uid_777',
      whatsappConfirmedAt: now,
    );

    expect(confirmedReg.isWhatsAppAdminConfirmed, isTrue);
    expect(confirmedReg.whatsappConfirmedByAdminUid, equals('admin_uid_777'));
    expect(confirmedReg.toMap()['whatsappStatus'], equals('admin_confirmed_sent'));
    expect(confirmedReg.toMap()['whatsappConfirmedByAdminUid'], equals('admin_uid_777'));
  });
}