import 'package:flutter_test/flutter_test.dart';
import 'package:college_event_app/models/event_model.dart';
import 'package:college_event_app/models/user_model.dart';
import 'package:college_event_app/utils/constants.dart';

void main() {
  group('A. Event Model & Backward Compatibility', () {
    test('Old Firestore event document without new fields deserializes properly', () {
      final legacyDoc = {
        'title': 'Legacy Tech Fest',
        'description': 'Old event without eligibility or coordinator fields',
        'category': 'Technical',
        'venue': 'Auditorium',
        'organizer': 'Tech Club',
        'capacity': 100,
        'registeredCount': 20,
        'fee': 50.0,
      };

      final event = EventModel.fromMap(legacyDoc, 'EVT_LEGACY_01');

      expect(event.id, 'EVT_LEGACY_01');
      expect(event.title, 'Legacy Tech Fest');
      expect(event.coordinators, isEmpty);
      expect(event.allowedYears, isEmpty);
      expect(event.allowedDepartments, isEmpty);
      expect(event.minCgpa, 0.0);
      expect(event.requirements, '');
      expect(event.isAllYears, isTrue);
      expect(event.isAllDepartments, isTrue);
      expect(event.eligibilitySummary, 'Open to All Students');
    });

    test('Full Event with coordinators and eligibility serializes and deserializes cleanly', () {
      final fullEvent = EventModel(
        id: 'EVT_2026',
        title: 'Hackathon 2026',
        description: 'Inter-branch 24h coding marathon',
        category: 'Hackathon',
        date: DateTime(2026, 11, 1),
        startTime: '9:00 AM',
        endTime: '9:00 AM',
        venue: 'Innovation Hub',
        organizer: 'Coding Club',
        maxSeats: 80,
        availableSeats: 80,
        registrationFee: 150.0,
        registrationDeadline: DateTime(2026, 10, 31),
        allowedYears: const [AcademicYears.year2, AcademicYears.year3],
        allowedDepartments: const [AcademicDepartments.cse, AcademicDepartments.it],
        minCgpa: 7.0,
        requirements: 'Bring laptop with dev environment',
        coordinators: const [
          EventCoordinator(
            name: 'Prof. Ramesh',
            role: 'Faculty Lead',
            phone: '9876543210',
            email: 'ramesh@college.edu',
            whatsapp: '+919876543210',
          ),
          EventCoordinator(
            name: 'Priya Sharma',
            role: 'Student Head',
            phone: '9876500001',
            email: 'priya@student.college.edu',
          ),
        ],
      );

      final map = fullEvent.toMap();
      final parsed = EventModel.fromMap(map, 'EVT_2026');

      expect(parsed.id, 'EVT_2026');
      expect(parsed.title, 'Hackathon 2026');
      expect(parsed.allowedYears, containsAll([AcademicYears.year2, AcademicYears.year3]));
      expect(parsed.allowedDepartments, containsAll([AcademicDepartments.cse, AcademicDepartments.it]));
      expect(parsed.minCgpa, 7.0);
      expect(parsed.requirements, 'Bring laptop with dev environment');
      expect(parsed.coordinators.length, 2);
      expect(parsed.coordinators[0].name, 'Prof. Ramesh');
      expect(parsed.coordinators[0].whatsapp, '+919876543210');
      expect(parsed.coordinators[1].name, 'Priya Sharma');
      expect(parsed.coordinators[1].whatsapp, '');
    });
  });

  group('B. Coordinator Management', () {
    test('Coordinator supports add, edit, and removal via EventModel copyWith', () {
      final initialEvent = EventModel(
        id: 'EVT_COORD',
        title: 'Sports Fest',
        description: 'Annual Sports',
        category: 'Sports',
        date: DateTime(2026, 10, 25),
        startTime: '8:00 AM',
        endTime: '5:00 PM',
        venue: 'Ground',
        organizer: 'Sports Dept',
        maxSeats: 100,
        availableSeats: 100,
        registrationFee: 0,
        registrationDeadline: DateTime(2026, 10, 24),
        coordinators: const [
          EventCoordinator(
            name: 'Coach Vikram',
            role: 'Director',
            phone: '9823456789',
            email: 'sports@college.edu',
          ),
        ],
      );

      expect(initialEvent.coordinators.length, 1);

      // Add a coordinator
      final updatedCoordinators = [
        ...initialEvent.coordinators,
        const EventCoordinator(
          name: 'Anjali Kumar',
          role: 'Student Secretary',
          phone: '9845011111',
          email: 'anjali@student.college.edu',
          whatsapp: '+919845011111',
        ),
      ];

      final eventWithTwoCoordinators = initialEvent.copyWith(coordinators: updatedCoordinators);
      expect(eventWithTwoCoordinators.coordinators.length, 2);
      expect(eventWithTwoCoordinators.coordinators.last.name, 'Anjali Kumar');

      // Edit first coordinator
      final editedCoordinators = List<EventCoordinator>.from(eventWithTwoCoordinators.coordinators);
      editedCoordinators[0] = editedCoordinators[0].copyWith(phone: '9999988888');

      final eventWithEditedCoord = eventWithTwoCoordinators.copyWith(coordinators: editedCoordinators);
      expect(eventWithEditedCoord.coordinators[0].phone, '9999988888');

      // Remove coordinator
      final remainingCoordinators = List<EventCoordinator>.from(eventWithEditedCoord.coordinators)..removeAt(0);
      final eventWithRemovedCoord = eventWithEditedCoord.copyWith(coordinators: remainingCoordinators);
      expect(eventWithRemovedCoord.coordinators.length, 1);
      expect(eventWithRemovedCoord.coordinators.first.name, 'Anjali Kumar');
    });
  });

  group('C. Eligibility Configuration & Visibility Validation', () {
    final secondYearStudentCse = UserModel(
      uid: 'user_2nd_cse',
      name: 'Rohan Sharma',
      email: 'rohan@college.edu',
      rollNumber: 'CS-2024-01',
      department: AcademicDepartments.cse,
      year: AcademicYears.year2,
      role: UserRoles.student,
    );

    final thirdYearStudentIt = UserModel(
      uid: 'user_3rd_it',
      name: 'Sneha Patel',
      email: 'sneha@college.edu',
      rollNumber: 'IT-2023-14',
      department: AcademicDepartments.it,
      year: AcademicYears.year3,
      role: UserRoles.student,
    );

    final firstYearStudentCivil = UserModel(
      uid: 'user_1st_civil',
      name: 'Aditya Das',
      email: 'aditya@college.edu',
      rollNumber: 'CV-2025-09',
      department: AcademicDepartments.civil,
      year: AcademicYears.year1,
      role: UserRoles.student,
    );

    final fourthYearStudentMech = UserModel(
      uid: 'user_4th_mech',
      name: 'Karan Verma',
      email: 'karan@college.edu',
      rollNumber: 'ME-2022-55',
      department: AcademicDepartments.mech,
      year: AcademicYears.year4,
      role: UserRoles.student,
    );

    final incompleteProfileStudent = UserModel(
      uid: 'user_incomplete',
      name: 'New Student',
      email: 'new@college.edu',
      rollNumber: '',
      department: '',
      year: '',
      role: UserRoles.student,
    );

    final adminUser = UserModel(
      uid: 'user_admin',
      name: 'Admin User',
      email: 'admin@collegeevent.com',
      rollNumber: 'ADM-01',
      department: 'Staff',
      year: 'Staff',
      role: UserRoles.admin,
    );

    test('1. All-Years and All-Departments Event is visible & eligible for all complete profiles', () {
      final openEvent = EventModel(
        id: 'EVT_OPEN',
        title: 'Open Campus Fest',
        description: 'Everyone is welcome',
        category: 'Cultural',
        date: DateTime(2026, 10, 20),
        startTime: '5:00 PM',
        endTime: '9:00 PM',
        venue: 'Open Ground',
        organizer: 'Student Council',
        maxSeats: 500,
        availableSeats: 500,
        registrationFee: 0,
        registrationDeadline: DateTime(2026, 10, 19),
        allowedYears: const [],
        allowedDepartments: const [],
      );

      expect(openEvent.isEligibleFor(secondYearStudentCse), isTrue);
      expect(openEvent.isEligibleFor(thirdYearStudentIt), isTrue);
      expect(openEvent.isEligibleFor(firstYearStudentCivil), isTrue);
      expect(openEvent.isEligibleFor(fourthYearStudentMech), isTrue);
      expect(openEvent.isEligibleFor(adminUser), isTrue);
    });

    test('2. Year-Restricted Event (2nd and 3rd Year only) filters properly', () {
      final yearRestrictedEvent = EventModel(
        id: 'EVT_YR_RESTRICT',
        title: 'Junior-Senior Coding Workshop',
        description: 'Exclusively for 2nd and 3rd year students',
        category: 'Workshop',
        date: DateTime(2026, 10, 22),
        startTime: '10:00 AM',
        endTime: '1:00 PM',
        venue: 'Lab 2',
        organizer: 'Coding Club',
        maxSeats: 60,
        availableSeats: 60,
        registrationFee: 0,
        registrationDeadline: DateTime(2026, 10, 21),
        allowedYears: const [AcademicYears.year2, AcademicYears.year3],
        allowedDepartments: const [], // All branches
      );

      // 2nd and 3rd years MUST be eligible
      expect(yearRestrictedEvent.isEligibleFor(secondYearStudentCse), isTrue);
      expect(yearRestrictedEvent.isEligibleFor(thirdYearStudentIt), isTrue);

      // 1st and 4th years MUST be ineligible
      expect(yearRestrictedEvent.isEligibleFor(firstYearStudentCivil), isFalse);
      expect(yearRestrictedEvent.isEligibleFor(fourthYearStudentMech), isFalse);

      // Admin/Staff has universal access
      expect(yearRestrictedEvent.isEligibleFor(adminUser), isTrue);
    });

    test('3. Branch-Restricted Event (CSE & IT only) filters properly', () {
      final branchRestrictedEvent = EventModel(
        id: 'EVT_BRANCH_RESTRICT',
        title: 'Cloud Computing Symposium',
        description: 'For IT & CSE students',
        category: 'Technical',
        date: DateTime(2026, 10, 24),
        startTime: '2:00 PM',
        endTime: '4:00 PM',
        venue: 'Seminar Hall B',
        organizer: 'CS & IT Depts',
        maxSeats: 80,
        availableSeats: 80,
        registrationFee: 0,
        registrationDeadline: DateTime(2026, 10, 23),
        allowedYears: const [], // All years
        allowedDepartments: const [AcademicDepartments.cse, AcademicDepartments.it],
      );

      // CSE and IT students eligible across all years
      expect(branchRestrictedEvent.isEligibleFor(secondYearStudentCse), isTrue);
      expect(branchRestrictedEvent.isEligibleFor(thirdYearStudentIt), isTrue);

      // Civil and Mech students ineligible
      expect(branchRestrictedEvent.isEligibleFor(firstYearStudentCivil), isFalse);
      expect(branchRestrictedEvent.isEligibleFor(fourthYearStudentMech), isFalse);
    });

    test('4. Combined Year & Branch Restriction (3rd Year IT only) enforces strict combination', () {
      final strictEvent = EventModel(
        id: 'EVT_STRICT',
        title: 'Final Year Project Orientation',
        description: 'For 3rd year IT students preparing for final projects',
        category: 'Seminar',
        date: DateTime(2026, 10, 26),
        startTime: '11:00 AM',
        endTime: '1:00 PM',
        venue: 'Room 404',
        organizer: 'IT Dept',
        maxSeats: 50,
        availableSeats: 50,
        registrationFee: 0,
        registrationDeadline: DateTime(2026, 10, 25),
        allowedYears: const [AcademicYears.year3],
        allowedDepartments: const [AcademicDepartments.it],
      );

      // Matches both year 3 and IT
      expect(strictEvent.isEligibleFor(thirdYearStudentIt), isTrue);

      // 2nd Year CSE fails both year and dept
      expect(strictEvent.isEligibleFor(secondYearStudentCse), isFalse);

      // 1st Year Civil fails
      expect(strictEvent.isEligibleFor(firstYearStudentCivil), isFalse);

      // 4th Year Mech fails
      expect(strictEvent.isEligibleFor(fourthYearStudentMech), isFalse);
    });

    test('5. Incomplete student profile fails eligibility without guessing', () {
      final event = EventModel(
        id: 'EVT_ANY',
        title: 'Any Event',
        description: 'Desc',
        category: 'Technical',
        date: DateTime(2026, 10, 20),
        startTime: '10:00 AM',
        endTime: '12:00 PM',
        venue: 'Hall',
        organizer: 'Club',
        maxSeats: 50,
        availableSeats: 50,
        registrationFee: 0,
        registrationDeadline: DateTime(2026, 10, 19),
        allowedYears: const [AcademicYears.year2],
      );

      // Incomplete profile without year or department MUST NOT be guessed as eligible
      expect(event.isEligibleFor(incompleteProfileStudent), isFalse);
      expect(event.isEligibleFor(null), isFalse);
    });

    test('6. Normalization handles alternative year and department text representations', () {
      expect(AcademicYears.matches([AcademicYears.year2], '2nd Year'), isTrue);
      expect(AcademicYears.matches([AcademicYears.year2], '2nd'), isTrue);
      expect(AcademicYears.matches([AcademicYears.year2], '2'), isTrue);
      expect(AcademicYears.matches([AcademicYears.year2], '1st Year'), isFalse);

      expect(AcademicDepartments.matches([AcademicDepartments.cse], 'Computer Science'), isTrue);
      expect(AcademicDepartments.matches([AcademicDepartments.cse], 'CSE'), isTrue);
      expect(AcademicDepartments.matches([AcademicDepartments.it], 'IT'), isTrue);
      expect(AcademicDepartments.matches([AcademicDepartments.it], 'Mechanical'), isFalse);
    });
  });
}
