import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String rollNumber;
  final String department;
  final String year;
  final String role;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.rollNumber,
    required this.department,
    required this.year,
    this.role = UserRoles.student,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isAdmin => role == UserRoles.admin;
  bool get isFaculty => role == UserRoles.faculty;
  bool get isCoordinator => role == UserRoles.coordinator;
  bool get isStudent => role == UserRoles.student;
  bool get isStaff => UserRoles.isAdminOrStaff(role);

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      uid: docId,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      rollNumber: map['rollNumber'] as String? ?? '',
      department: map['department'] as String? ?? '',
      year: map['year'] as String? ?? '',
      role: map['role'] as String? ?? UserRoles.student,
      createdAt: DateFormatter.parseDateTime(map['createdAt']),
    );
  }

  factory UserModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'rollNumber': rollNumber,
      'department': department,
      'year': year,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? rollNumber,
    String? department,
    String? year,
    String? role,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      rollNumber: rollNumber ?? this.rollNumber,
      department: department ?? this.department,
      year: year ?? this.year,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
