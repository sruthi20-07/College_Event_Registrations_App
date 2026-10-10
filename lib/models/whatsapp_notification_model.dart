import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_formatter.dart';

class WhatsAppNotificationModel {
  final String id;
  final String registrationId;
  final String eventId;
  final String studentId;
  final String studentName;
  final String whatsappNumber;
  final String eventTitle;
  final String eventDate;
  final String eventTime;
  final String venue;
  final String ticketToken;
  final String deliveryMode; // 'manual' | 'cloud_api'
  final String status; // 'pending' | 'ready_to_share' | 'sent' | 'accepted' | 'delivered' | 'failed'
  final String providerMessageId;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final String lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  WhatsAppNotificationModel({
    required this.id,
    required this.registrationId,
    required this.eventId,
    required this.studentId,
    required this.studentName,
    required this.whatsappNumber,
    required this.eventTitle,
    this.eventDate = '',
    this.eventTime = '',
    this.venue = '',
    this.ticketToken = '',
    this.deliveryMode = 'manual',
    this.status = 'pending',
    this.providerMessageId = '',
    this.attemptCount = 1,
    this.lastAttemptAt,
    this.lastError = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory WhatsAppNotificationModel.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    return WhatsAppNotificationModel(
      id: docId,
      registrationId: map['registrationId'] as String? ?? '',
      eventId: map['eventId'] as String? ?? '',
      studentId: map['studentId'] as String? ?? map['userId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      whatsappNumber: map['whatsappNumber'] as String? ?? '',
      eventTitle: map['eventTitle'] as String? ?? '',
      eventDate: map['eventDate'] as String? ?? '',
      eventTime: map['eventTime'] as String? ?? '',
      venue: map['venue'] as String? ?? '',
      ticketToken: map['ticketToken'] as String? ?? '',
      deliveryMode: map['deliveryMode'] as String? ?? 'manual',
      status: map['status'] as String? ?? 'pending',
      providerMessageId: map['providerMessageId'] as String? ?? '',
      attemptCount: (map['attemptCount'] as num? ?? 1).toInt(),
      lastAttemptAt: map['lastAttemptAt'] != null
          ? DateFormatter.parseDateTime(map['lastAttemptAt'])
          : null,
      lastError: map['lastError'] as String? ?? '',
      createdAt: DateFormatter.parseDateTime(map['createdAt']),
      updatedAt: DateFormatter.parseDateTime(map['updatedAt']),
    );
  }

  factory WhatsAppNotificationModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return WhatsAppNotificationModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'registrationId': registrationId,
      'eventId': eventId,
      'studentId': studentId,
      'studentName': studentName,
      'whatsappNumber': whatsappNumber,
      'eventTitle': eventTitle,
      'eventDate': eventDate,
      'eventTime': eventTime,
      'venue': venue,
      'ticketToken': ticketToken,
      'deliveryMode': deliveryMode,
      'status': status,
      'providerMessageId': providerMessageId,
      'attemptCount': attemptCount,
      'lastAttemptAt': lastAttemptAt != null
          ? Timestamp.fromDate(lastAttemptAt!)
          : null,
      'lastError': lastError,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  WhatsAppNotificationModel copyWith({
    String? id,
    String? registrationId,
    String? eventId,
    String? studentId,
    String? studentName,
    String? whatsappNumber,
    String? eventTitle,
    String? eventDate,
    String? eventTime,
    String? venue,
    String? ticketToken,
    String? deliveryMode,
    String? status,
    String? providerMessageId,
    int? attemptCount,
    DateTime? lastAttemptAt,
    String? lastError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WhatsAppNotificationModel(
      id: id ?? this.id,
      registrationId: registrationId ?? this.registrationId,
      eventId: eventId ?? this.eventId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      eventTitle: eventTitle ?? this.eventTitle,
      eventDate: eventDate ?? this.eventDate,
      eventTime: eventTime ?? this.eventTime,
      venue: venue ?? this.venue,
      ticketToken: ticketToken ?? this.ticketToken,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      status: status ?? this.status,
      providerMessageId: providerMessageId ?? this.providerMessageId,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
