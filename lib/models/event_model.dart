import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String posterUrl;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String venue;
  final String organizer;
  final int maxSeats;
  final int availableSeats;
  final double registrationFee;
  final DateTime registrationDeadline;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.posterUrl = '',
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.venue,
    required this.organizer,
    required this.maxSeats,
    required this.availableSeats,
    required this.registrationFee,
    required this.registrationDeadline,
    this.status = EventStatuses.upcoming,
    this.createdBy = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // Field aliases for schema compliance
  int get capacity => maxSeats;
  int get registeredCount => (maxSeats - availableSeats).clamp(0, maxSeats);
  String get imageUrl => posterUrl;
  String get image => posterUrl;
  double get fee => registrationFee;
  int get totalSeats => maxSeats;
  String get time => startTime.isNotEmpty && endTime.isNotEmpty
      ? '$startTime - $endTime'
      : (startTime.isNotEmpty ? startTime : '10:00 AM - 4:00 PM');
  String get dateFormatted => DateFormatter.formatDate(date);

  bool get isFull => availableSeats <= 0;
  bool get isDeadlinePassed => DateTime.now().isAfter(registrationDeadline);
  bool get isPaid => registrationFee > 0;
  bool get isPublished =>
      status == EventStatuses.upcoming || status == EventStatuses.ongoing;

  factory EventModel.fromMap(Map<String, dynamic> map, String docId) {
    final int capacity = (map['capacity'] as num? ??
            map['maxSeats'] as num? ??
            map['totalSeats'] as num? ??
            100)
        .toInt();
    final int regCount = (map['registeredCount'] as num? ?? 0).toInt();
    final int computedAvail = map['availableSeats'] != null
        ? (map['availableSeats'] as num).toInt()
        : (capacity - regCount).clamp(0, capacity);

    return EventModel(
      id: docId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? EventCategories.technical,
      posterUrl:
          map['posterUrl'] as String? ??
          map['imageUrl'] as String? ??
          map['image'] as String? ??
          '',
      date: DateFormatter.parseDateTime(map['date']),
      startTime: map['startTime'] as String? ?? '',
      endTime: map['endTime'] as String? ?? '',
      venue: map['venue'] as String? ?? '',
      organizer: map['organizer'] as String? ?? '',
      maxSeats: capacity,
      availableSeats: computedAvail,
      registrationFee:
          (map['registrationFee'] as num? ?? map['fee'] as num? ?? 0.0)
              .toDouble(),
      registrationDeadline: DateFormatter.parseDateTime(
        map['registrationDeadline'] ?? map['date'],
      ),
      status: map['status'] as String? ?? EventStatuses.upcoming,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: DateFormatter.parseDateTime(map['createdAt']),
      updatedAt: DateFormatter.parseDateTime(map['updatedAt']),
    );
  }

  factory EventModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return EventModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'posterUrl': posterUrl,
      'imageUrl': posterUrl,
      'date': Timestamp.fromDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'venue': venue,
      'organizer': organizer,
      'maxSeats': maxSeats,
      'capacity': maxSeats,
      'registeredCount': registeredCount,
      'availableSeats': availableSeats,
      'registrationFee': registrationFee,
      'registrationDeadline': Timestamp.fromDate(registrationDeadline),
      'status': status,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? posterUrl,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? venue,
    String? organizer,
    int? maxSeats,
    int? availableSeats,
    double? registrationFee,
    DateTime? registrationDeadline,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      posterUrl: posterUrl ?? this.posterUrl,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      venue: venue ?? this.venue,
      organizer: organizer ?? this.organizer,
      maxSeats: maxSeats ?? this.maxSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      registrationFee: registrationFee ?? this.registrationFee,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Alias for backwards compatibility with existing UI prototype code
typedef Event = EventModel;
