import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_formatter.dart';

class FeedbackModel {
  final String id;
  final String studentUid;
  final String studentName;
  final String studentEmail;
  final String rollNumber;
  final String department;
  final int rating; // 1 to 5 stars
  final String message;
  final String category;
  final DateTime createdAt;

  String get feedback => message;

  FeedbackModel({
    required this.id,
    required this.studentUid,
    required this.studentName,
    required this.studentEmail,
    this.rollNumber = '',
    this.department = '',
    required this.rating,
    String? message,
    String? feedback,
    this.category = 'General',
    DateTime? createdAt,
  })  : message = message ?? feedback ?? '',
        createdAt = createdAt ?? DateTime.now();

  factory FeedbackModel.fromMap(Map<String, dynamic> map, String docId) {
    return FeedbackModel(
      id: docId,
      studentUid: map['studentUid'] as String? ?? '',
      studentName: map['studentName'] as String? ?? 'Anonymous Student',
      studentEmail: map['studentEmail'] as String? ?? '',
      rollNumber: map['rollNumber'] as String? ?? '',
      department: map['department'] as String? ?? '',
      rating: (map['rating'] as num?)?.toInt().clamp(1, 5) ?? 5,
      message: (map['message'] ?? map['feedback'] ?? '') as String,
      category: map['category'] as String? ?? 'General',
      createdAt: DateFormatter.parseDateTime(map['createdAt']),
    );
  }

  factory FeedbackModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return FeedbackModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'studentUid': studentUid,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'rollNumber': rollNumber,
      'department': department,
      'rating': rating,
      'message': message,
      'feedback': message,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
