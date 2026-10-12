import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import 'user_model.dart';

class EventCoordinator {
  final String name;
  final String role;
  final String phone;
  final String email;
  final String whatsapp;

  const EventCoordinator({
    required this.name,
    required this.role,
    required this.phone,
    required this.email,
    this.whatsapp = '',
  });

  factory EventCoordinator.fromMap(Map<String, dynamic> map) {
    return EventCoordinator(
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? 'Coordinator',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      whatsapp: map['whatsapp'] as String? ?? map['whatsappNumber'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'phone': phone,
      'email': email,
      if (whatsapp.isNotEmpty) 'whatsapp': whatsapp,
    };
  }

  EventCoordinator copyWith({
    String? name,
    String? role,
    String? phone,
    String? email,
    String? whatsapp,
  }) {
    return EventCoordinator(
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      whatsapp: whatsapp ?? this.whatsapp,
    );
  }
}

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
  final List<EventCoordinator> coordinators;
  final List<String> allowedYears;
  final List<String> allowedDepartments;
  final double minCgpa;
  final String requirements;
  final String qrToken;
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
    this.coordinators = const [],
    this.allowedYears = const [],
    this.allowedDepartments = const [],
    this.minCgpa = 0.0,
    this.requirements = '',
    this.qrToken = '',
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
  bool get hasQrCode => qrToken.isNotEmpty;

  /// Returns the standardized JSON QR payload for this published event
  String get uniqueQrPayload {
    return jsonEncode({
      'type': 'event_attendance_qr',
      'eventId': id,
      'token': qrToken.isNotEmpty ? qrToken : 'evtok_${id}_static',
      'title': title,
    });
  }

  // Eligibility helpers
  bool get isAllYears =>
      allowedYears.isEmpty ||
      allowedYears.contains('All') ||
      allowedYears.contains(AcademicYears.all);

  bool get isAllDepartments =>
      allowedDepartments.isEmpty ||
      allowedDepartments.contains('All') ||
      allowedDepartments.contains(AcademicDepartments.all);

  bool isEligibleFor(UserModel? user) {
    if (user == null) return false;
    // Admins and staff have universal visibility
    if (user.isStaff) return true;

    // Student profile verification: both year and department must be present
    if (user.year.trim().isEmpty || user.department.trim().isEmpty) {
      return false;
    }

    final bool yearMatches = isAllYears || AcademicYears.matches(allowedYears, user.year);
    final bool deptMatches =
        isAllDepartments || AcademicDepartments.matches(allowedDepartments, user.department);

    return yearMatches && deptMatches;
  }

  String get eligibilitySummary {
    if (isAllYears && isAllDepartments) {
      return 'Open to All Students';
    }
    final List<String> parts = [];
    if (!isAllYears) {
      parts.add(allowedYears.join(', '));
    } else {
      parts.add('All Years');
    }

    if (!isAllDepartments) {
      parts.add(allowedDepartments.join(', '));
    } else {
      parts.add('All Branches');
    }

    if (minCgpa > 0) {
      parts.add('Min CGPA: ${minCgpa.toStringAsFixed(1)}');
    }
    return parts.join(' • ');
  }

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

    // Parse coordinators safely
    List<EventCoordinator> parsedCoordinators = [];
    if (map['coordinators'] is List) {
      parsedCoordinators = (map['coordinators'] as List)
          .whereType<Map>()
          .map((item) => EventCoordinator.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    // Parse allowedYears safely
    List<String> parsedYears = [];
    if (map['allowedYears'] is List) {
      parsedYears = (map['allowedYears'] as List)
          .map((y) => y.toString().trim())
          .where((y) => y.isNotEmpty)
          .toList();
    }

    // Parse allowedDepartments safely
    List<String> parsedDepartments = [];
    if (map['allowedDepartments'] is List) {
      parsedDepartments = (map['allowedDepartments'] as List)
          .map((d) => d.toString().trim())
          .where((d) => d.isNotEmpty)
          .toList();
    }

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
      coordinators: parsedCoordinators,
      allowedYears: parsedYears,
      allowedDepartments: parsedDepartments,
      minCgpa: (map['minCgpa'] as num? ?? 0.0).toDouble(),
      requirements: map['requirements'] as String? ?? '',
      qrToken: map['qrToken'] as String? ?? map['attendanceToken'] as String? ?? '',
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
      'coordinators': coordinators.map((c) => c.toMap()).toList(),
      'allowedYears': allowedYears,
      'allowedDepartments': allowedDepartments,
      'minCgpa': minCgpa,
      'requirements': requirements,
      'qrToken': qrToken,
      'attendanceToken': qrToken,
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
    List<EventCoordinator>? coordinators,
    List<String>? allowedYears,
    List<String>? allowedDepartments,
    double? minCgpa,
    String? requirements,
    String? qrToken,
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
      coordinators: coordinators ?? this.coordinators,
      allowedYears: allowedYears ?? this.allowedYears,
      allowedDepartments: allowedDepartments ?? this.allowedDepartments,
      minCgpa: minCgpa ?? this.minCgpa,
      requirements: requirements ?? this.requirements,
      qrToken: qrToken ?? this.qrToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


// Alias for backwards compatibility with existing UI prototype code
typedef Event = EventModel;
