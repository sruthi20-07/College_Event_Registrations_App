import '../models/event_model.dart';
import '../utils/constants.dart';

final List<EventModel> events = [
  EventModel(
    id: 'EVT001',
    title: 'TECHNOVA 2026',
    description:
        'A technical fest featuring coding competitions, quizzes, project exhibitions and exciting challenges for students.',
    category: 'Technical',
    posterUrl: 'assets/images/technova.jpg',
    date: DateTime(2026, 10, 18),
    startTime: '10:00 AM',
    endTime: '4:00 PM',
    venue: 'Main Auditorium',
    organizer: 'Computer Science Club',
    maxSeats: 100,
    availableSeats: 48,
    registrationFee: 100,
    registrationDeadline: DateTime(2026, 10, 17),
    allowedYears: const [AcademicYears.year2, AcademicYears.year3, AcademicYears.year4],
    allowedDepartments: const [AcademicDepartments.cse, AcademicDepartments.it, AcademicDepartments.aiDs],
    minCgpa: 6.5,
    requirements: 'Bring your student ID card and laptop.',
    coordinators: const [
      EventCoordinator(
        name: 'Dr. Ramesh Kumar',
        role: 'Faculty Coordinator',
        phone: '9876543210',
        email: 'ramesh.k@college.edu',
        whatsapp: '+919876543210',
      ),
      EventCoordinator(
        name: 'Priya Sharma',
        role: 'Student Lead',
        phone: '9876500001',
        email: 'priya.s@student.college.edu',
        whatsapp: '+919876500001',
      ),
    ],
  ),
  EventModel(
    id: 'EVT002',
    title: 'Flutter Workshop',
    description:
        'Learn Flutter development from basics and build your first cross-platform mobile application.',
    category: 'Workshop',
    posterUrl: 'assets/images/flutter.jpg',
    date: DateTime(2026, 10, 20),
    startTime: '10:00 AM',
    endTime: '1:00 PM',
    venue: 'Computer Lab 3',
    organizer: 'Coding Club',
    maxSeats: 60,
    availableSeats: 25,
    registrationFee: 50,
    registrationDeadline: DateTime(2026, 10, 19),
    allowedYears: const [AcademicYears.year2, AcademicYears.year3],
    allowedDepartments: const [], // Open to all departments
    minCgpa: 0.0,
    requirements: 'Install Flutter SDK and VS Code before attending.',
    coordinators: const [
      EventCoordinator(
        name: 'Prof. Anitha Rao',
        role: 'Faculty In-Charge',
        phone: '9845012345',
        email: 'anitha.rao@college.edu',
      ),
    ],
  ),
  EventModel(
    id: 'EVT003',
    title: 'Cultural Fiesta',
    description:
        'An exciting cultural celebration featuring dance, music, drama and traditional performances.',
    category: 'Cultural',
    posterUrl: 'assets/images/cultural.jpg',
    date: DateTime(2026, 10, 22),
    startTime: '5:00 PM',
    endTime: '8:00 PM',
    venue: 'Open Air Theatre',
    organizer: 'Cultural Club',
    maxSeats: 300,
    availableSeats: 120,
    registrationFee: 0,
    registrationDeadline: DateTime(2026, 10, 21),
    allowedYears: const [], // All years
    allowedDepartments: const [], // All departments
    coordinators: const [
      EventCoordinator(
        name: 'Kavitha Nair',
        role: 'Cultural Secretary',
        phone: '9812345678',
        email: 'cultural@college.edu',
      ),
    ],
  ),
  EventModel(
    id: 'EVT004',
    title: 'Campus Cricket Cup',
    description:
        'Inter-department cricket tournament. Form your team and compete for the championship.',
    category: 'Sports',
    posterUrl: 'assets/images/cricket.jpg',
    date: DateTime(2026, 10, 25),
    startTime: '8:00 AM',
    endTime: '5:00 PM',
    venue: 'College Ground',
    organizer: 'Sports Club',
    maxSeats: 150,
    availableSeats: 70,
    registrationFee: 200,
    registrationDeadline: DateTime(2026, 10, 24),
    allowedYears: const [],
    allowedDepartments: const [],
    coordinators: const [
      EventCoordinator(
        name: 'Coach Vikram Singh',
        role: 'Sports Director',
        phone: '9823456789',
        email: 'sports@college.edu',
      ),
    ],
  ),
  EventModel(
    id: 'EVT005',
    title: 'AI & Future Technologies',
    description:
        'Explore Artificial Intelligence, Machine Learning, Generative AI and the future of technology.',
    category: 'Technical',
    posterUrl: 'assets/images/ai.jpg',
    date: DateTime(2026, 10, 28),
    startTime: '11:00 AM',
    endTime: '2:00 PM',
    venue: 'Seminar Hall',
    organizer: 'AI Club',
    maxSeats: 120,
    availableSeats: 55,
    registrationFee: 0,
    registrationDeadline: DateTime(2026, 10, 27),
    allowedYears: const [AcademicYears.year3, AcademicYears.year4],
    allowedDepartments: const [AcademicDepartments.cse, AcademicDepartments.it, AcademicDepartments.aiDs, AcademicDepartments.ece],
    coordinators: const [
      EventCoordinator(
        name: 'Dr. Sunita Murthy',
        role: 'AI Dept Lead',
        phone: '9834567890',
        email: 'sunita.m@college.edu',
      ),
    ],
  ),
  EventModel(
    id: 'EVT006',
    title: 'Hackathon 2026',
    description:
        'A 24-hour coding marathon where students collaborate to solve real-world problems using technology.',
    category: 'Hackathon',
    posterUrl: 'assets/images/hackathon.jpg',
    date: DateTime(2026, 11, 1),
    startTime: '9:00 AM',
    endTime: '9:00 AM',
    venue: 'Innovation Hub',
    organizer: 'Innovation Club',
    maxSeats: 100,
    availableSeats: 32,
    registrationFee: 150,
    registrationDeadline: DateTime(2026, 10, 31),
    allowedYears: const [AcademicYears.year2, AcademicYears.year3, AcademicYears.year4],
    allowedDepartments: const [],
    coordinators: const [
      EventCoordinator(
        name: 'Rahul Varma',
        role: 'Hackathon Lead',
        phone: '9845678901',
        email: 'hackathon@college.edu',
      ),
    ],
  ),
];

void updateLocalEventSeats(String eventId) {
  final index = events.indexWhere((e) => e.id == eventId);
  if (index != -1) {
    final current = events[index];
    final newSeats = (current.availableSeats - 1).clamp(0, current.maxSeats);
    events[index] = current.copyWith(availableSeats: newSeats);
  }
}
