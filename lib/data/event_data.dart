import '../models/event_model.dart';

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
