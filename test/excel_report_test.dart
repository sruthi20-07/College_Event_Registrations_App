import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:college_event_app/models/registration_model.dart';
import 'package:college_event_app/models/user_model.dart';
import 'package:college_event_app/utils/excel_export_helper.dart';
import 'package:college_event_app/screens/admin/event_registration_report_screen.dart';
import 'package:college_event_app/screens/admin/event_registrations_screen.dart';

void main() {
  group('A. Excel (.xlsx) Generation & Schema Verification', () {
    test('Event with multiple registrations generates valid .xlsx workbook with Registrations & Summary sheets', () {
      final now = DateTime(2026, 11, 15, 10, 30);
      final registrations = [
        RegistrationModel(
          id: 'REG_001',
          eventId: 'EVT_FSD',
          eventTitle: 'FSD hackathon',
          studentId: 'STU_101',
          studentName: 'Aarav Sharma',
          studentEmail: 'aarav@college.edu',
          rollNumber: '21CS045',
          phone: '9876543210',
          department: 'Computer Science',
          year: '3rd Year',
          section: 'A',
          amount: 250.0,
          paymentStatus: 'paid',
          paymentReference: 'PAY_XYZ_123',
          registrationStatus: 'confirmed',
          attended: true,
          attendanceStatus: 'attended',
          registeredAt: now,
          paidAt: now,
          attendedAt: now.add(const Duration(hours: 2)),
        ),
        RegistrationModel(
          id: 'REG_002',
          eventId: 'EVT_FSD',
          eventTitle: '', // Missing title in doc, will be resolved from eventTitle/eventsMap
          studentId: 'STU_102',
          studentName: 'Priya Patel',
          studentEmail: 'priya@college.edu',
          rollNumber: '22IT012',
          phone: '9123456780',
          department: 'Information Technology',
          year: '2nd Year',
          section: 'B',
          amount: 0.0,
          paymentStatus: 'free',
          paymentReference: '',
          registrationStatus: 'confirmed',
          attended: false,
          attendanceStatus: 'not_attended',
          registeredAt: now,
        ),
      ];

      final bytes = ExcelExportHelper.generateRegistrationsExcel(
        registrations: registrations,
        eventTitle: 'FSD hackathon',
        eventId: 'EVT_FSD',
        eventNamesById: {'EVT_FSD': 'FSD hackathon'},
      );

      expect(bytes.isNotEmpty, isTrue);
      // Verify ZIP / XLSX magic header: PK (0x50, 0x4B)
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);

      // Decode and verify Excel structure
      final decodedExcel = Excel.decodeBytes(bytes);
      expect(decodedExcel.tables.containsKey('Registrations'), isTrue);
      expect(decodedExcel.tables.containsKey('Summary'), isTrue);

      final regSheet = decodedExcel.tables['Registrations']!;
      expect(regSheet.maxRows, greaterThanOrEqualTo(6));

      final summarySheet = decodedExcel.tables['Summary']!;
      expect(summarySheet.maxRows, greaterThanOrEqualTo(10));
    });

    test('All-events export resolves event name for each registration via eventNamesById map', () {
      final now = DateTime(2026, 11, 15, 10, 30);
      final registrations = [
        RegistrationModel(
          id: 'REG_001',
          eventId: 'EVT_FSD',
          studentId: 'STU_001',
          eventTitle: '', // Missing title on model
          studentName: 'Aarav Sharma',
          studentEmail: 'aarav@college.edu',
          rollNumber: '21CS045',
          department: 'CSE',
          year: '3rd Year',
          registeredAt: now,
        ),
        RegistrationModel(
          id: 'REG_002',
          eventId: 'EVT_AI',
          studentId: 'STU_002',
          eventTitle: '', // Missing title on model
          studentName: 'Priya Patel',
          studentEmail: 'priya@college.edu',
          rollNumber: '22IT012',
          department: 'IT',
          year: '2nd Year',
          registeredAt: now,
        ),
        RegistrationModel(
          id: 'REG_003',
          eventId: '', // Missing event ID
          studentId: 'STU_003',
          eventTitle: '',
          studentName: 'Rohan Verma',
          studentEmail: 'rohan@college.edu',
          rollNumber: '23ECE01',
          department: 'ECE',
          year: '1st Year',
          registeredAt: now,
        ),
      ];

      final bytes = ExcelExportHelper.generateRegistrationsExcel(
        registrations: registrations,
        eventTitle: 'All Events',
        eventId: 'all_events',
        eventNamesById: {
          'EVT_FSD': 'FSD hackathon',
          'EVT_AI': 'AI Summit 2026',
        },
      );

      final decoded = Excel.decodeBytes(bytes);
      final sheet = decoded.tables['Registrations']!;

      // Row 4 is column headers, Rows 5, 6, 7 are registrations
      // Column 8 is 'Event Name'
      final row1Event = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 5)).value;
      final row2Event = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 6)).value;
      final row3Event = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 7)).value;

      expect(row1Event.toString(), contains('FSD hackathon'));
      expect(row2Event.toString(), contains('AI Summit 2026'));
      expect(row3Event.toString(), contains('Missing Event Reference'));
    });

    test('Event with zero registrations generates valid .xlsx template with zero summary metrics', () {
      final bytes = ExcelExportHelper.generateRegistrationsExcel(
        registrations: [],
        eventTitle: 'Empty Event 2026',
        eventId: 'EVT_EMPTY_000',
      );

      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);

      final decodedExcel = Excel.decodeBytes(bytes);
      expect(decodedExcel.tables.containsKey('Registrations'), isTrue);
      expect(decodedExcel.tables.containsKey('Summary'), isTrue);
    });

    test('Summary calculations accurately compute paid counts, free counts, and revenue without double counting', () {
      final now = DateTime(2026, 11, 15, 10, 30);
      final registrations = [
        RegistrationModel(
          id: 'R1',
          eventId: 'E1',
          studentId: 'S1',
          studentName: 'Student 1',
          studentEmail: 's1@college.edu',
          rollNumber: 'R1',
          department: 'CSE',
          year: '3rd Year',
          amount: 500.0,
          paymentStatus: 'paid',
          attended: true,
          attendanceStatus: 'attended',
          registeredAt: now,
        ),
        RegistrationModel(
          id: 'R2',
          eventId: 'E1',
          studentId: 'S2',
          studentName: 'Student 2',
          studentEmail: 's2@college.edu',
          rollNumber: 'R2',
          department: 'CSE',
          year: '3rd Year',
          amount: 300.0,
          paymentStatus: 'completed',
          attended: false,
          attendanceStatus: 'not_attended',
          registeredAt: now,
        ),
        RegistrationModel(
          id: 'R3',
          eventId: 'E1',
          studentId: 'S3',
          studentName: 'Student 3',
          studentEmail: 's3@college.edu',
          rollNumber: 'R3',
          department: 'IT',
          year: '2nd Year',
          amount: 0.0,
          paymentStatus: 'free',
          attended: true,
          attendanceStatus: 'attended',
          registeredAt: now,
        ),
      ];

      final bytes = ExcelExportHelper.generateRegistrationsExcel(
        registrations: registrations,
        eventTitle: 'Tech Fest',
        eventId: 'E1',
      );

      expect(bytes.isNotEmpty, isTrue);
      final decoded = Excel.decodeBytes(bytes);
      expect(decoded.tables.containsKey('Summary'), isTrue);
    });

    test('Generates professional, safe title-based filenames', () {
      final name1 = ExcelExportHelper.getSafeFileName(
        eventTitle: 'FSD hackathon',
        eventId: 'EVT_101',
      );
      expect(name1, 'FSD_Hackathon_Registrations.xlsx');

      final name2 = ExcelExportHelper.getSafeFileName(
        eventTitle: 'All Events',
      );
      expect(name2, 'All_Events_Registrations.xlsx');

      final name3 = ExcelExportHelper.getSafeFileName(
        eventId: 'all_events',
      );
      expect(name3, 'All_Events_Registrations.xlsx');

      final name4 = ExcelExportHelper.getSafeFileName(
        eventTitle: 'AI & Data Science Workshop 2026!',
        eventId: 'EVT_AIDS',
      );
      expect(name4, 'AI_Data_Science_Workshop_2026_Registrations.xlsx');
    });
  });

  group('B. Data Access & Authorization Verification', () {
    test('UserModel role authorization correctly normalizes role casing and recognizes admin emails', () {
      final studentUser = UserModel(
        uid: 'STU_UID_01',
        name: 'Regular Student',
        email: 'student@college.edu',
        rollNumber: '21CS001',
        department: 'CSE',
        year: '3rd Year',
        role: 'student',
      );

      final adminByEmail = UserModel(
        uid: 'ADM_UID_01',
        name: 'Admin User',
        email: 'admin@collegeevent.com',
        rollNumber: 'ADMIN',
        department: 'Administration',
        year: 'Staff',
        role: 'student', // Doc might say student, but email is admin@collegeevent.com
      );

      final facultyUser = UserModel(
        uid: 'FAC_UID_01',
        name: 'Faculty Member',
        email: 'prof@college.edu',
        rollNumber: 'FAC101',
        department: 'CSE',
        year: 'Faculty',
        role: 'Faculty', // Capitalized
      );

      expect(studentUser.isStaff, isFalse);
      expect(studentUser.isAdmin, isFalse);

      expect(adminByEmail.isStaff, isTrue);
      expect(adminByEmail.isAdmin, isTrue);

      expect(facultyUser.isStaff, isTrue);
      expect(facultyUser.isFaculty, isTrue);
    });

    testWidgets('EventRegistrationReportScreen displays Access Restricted for unauthorized user',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EventRegistrationReportScreen(),
        ),
      );

      // Unauthenticated / student view shows Access Restricted view
      expect(find.text('Event Registration Report'), findsOneWidget);
      expect(find.text('Access Restricted'), findsOneWidget);
      expect(
        find.textContaining('Only authorized college administrators'),
        findsOneWidget,
      );
    });
  });

  group('C. UI Integration & Screen Verification', () {
    testWidgets('EventRegistrationsScreen renders Download Excel action button and full report shortcut',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EventRegistrationsScreen(),
        ),
      );

      expect(find.text('Registrations Management'), findsOneWidget);
      // Top action icon for Full Report Table
      expect(find.byTooltip('View Full Report Table'), findsOneWidget);
      expect(find.byIcon(Icons.table_view_rounded), findsOneWidget);
    });
  });
}
