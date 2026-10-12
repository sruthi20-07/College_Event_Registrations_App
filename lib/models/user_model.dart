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
  final String whatsappNumber;
  final bool whatsappConsent;
  final DateTime? whatsappConsentAt;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.rollNumber,
    required this.department,
    required this.year,
    this.role = UserRoles.student,
    this.whatsappNumber = '',
    this.whatsappConsent = false,
    this.whatsappConsentAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isAdmin {
    final r = role.trim().toLowerCase();
    final e = email.trim().toLowerCase();
    return r == UserRoles.admin ||
        e == 'admin@collegeevent.com' ||
        e == 'admin@college.edu';
  }
  bool get isFaculty => role.trim().toLowerCase() == UserRoles.faculty;
  bool get isCoordinator => role.trim().toLowerCase() == UserRoles.coordinator;
  bool get isStudent => !isStaff;
  bool get isStaff => UserRoles.isAdminOrStaff(role) || isAdmin;

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    final String cleanEmail = (map['email'] as String? ?? '').trim().toLowerCase();
    final String rawRole = (map['role'] as String? ?? '').trim().toLowerCase();
    final bool isDocAdmin = map['isAdmin'] == true ||
        rawRole == 'admin' ||
        cleanEmail == 'admin@collegeevent.com' ||
        cleanEmail == 'admin@college.edu';
    final String resolvedRole = rawRole.isNotEmpty
        ? rawRole
        : (isDocAdmin ? UserRoles.admin : UserRoles.student);

    return UserModel(
      uid: docId,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      rollNumber: map['rollNumber'] as String? ?? '',
      department: map['department'] as String? ?? '',
      year: map['year'] as String? ?? '',
      role: resolvedRole,
      whatsappNumber: map['whatsappNumber'] as String? ?? map['phone'] as String? ?? '',
      whatsappConsent: map['whatsappConsent'] as bool? ?? false,
      whatsappConsentAt: map['whatsappConsentAt'] != null
          ? DateFormatter.parseDateTime(map['whatsappConsentAt'])
          : null,
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
      'whatsappNumber': whatsappNumber,
      'whatsappConsent': whatsappConsent,
      'whatsappConsentAt': whatsappConsentAt != null
          ? Timestamp.fromDate(whatsappConsentAt!)
          : null,
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
    String? whatsappNumber,
    bool? whatsappConsent,
    DateTime? whatsappConsentAt,
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
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      whatsappConsent: whatsappConsent ?? this.whatsappConsent,
      whatsappConsentAt: whatsappConsentAt ?? this.whatsappConsentAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
