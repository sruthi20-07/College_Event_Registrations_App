import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

class RegistrationModel {
  final String id;
  final String eventId;
  final String studentId;
  final String eventTitle;
  final String studentName;
  final String studentEmail;
  final String rollNumber;
  final String phone;
  final String department;
  final String year;
  final String section;
  final String eventDate;
  final String venue;
  final double amount;
  final String paymentStatus;
  final String paymentReference;
  final String registrationStatus;
  final String ticketToken;
  final bool attended;
  final String attendanceStatus;
  final DateTime registeredAt;
  final DateTime? paidAt;
  final DateTime? cancelledAt;
  final DateTime? attendedAt;
  final String verifiedByAdminUid;

  RegistrationModel({
    required this.id,
    required this.eventId,
    required this.studentId,
    this.eventTitle = '',
    required this.studentName,
    required this.studentEmail,
    required this.rollNumber,
    this.phone = '',
    required this.department,
    required this.year,
    this.section = 'A',
    this.eventDate = '',
    this.venue = '',
    this.amount = 0.0,
    this.paymentStatus = PaymentStatuses.free,
    this.paymentReference = '',
    this.registrationStatus = 'confirmed',
    this.ticketToken = '',
    this.attended = false,
    this.attendanceStatus = 'not_attended',
    DateTime? registeredAt,
    this.paidAt,
    this.cancelledAt,
    this.attendedAt,
    this.verifiedByAdminUid = '',
  }) : registeredAt = registeredAt ?? DateTime.now();

  String get userId => studentId;
  String get branch => department;
  String get paymentId => paymentReference;
  bool get isCancelled => registrationStatus == RegistrationStatuses.cancelled;
  bool get isRegistered =>
      registrationStatus == 'confirmed' ||
      registrationStatus == RegistrationStatuses.registered;
  bool get isPaid => paymentStatus == 'paid' || paymentStatus == 'completed';
  bool get isAttended => attended || attendanceStatus == 'attended';

  factory RegistrationModel.fromMap(Map<String, dynamic> map, String docId) {
    String resolvedUserId = (map['userId'] as String? ?? '').trim();
    final String rawStudentId = (map['studentId'] as String? ?? '').trim();
    if (resolvedUserId.isEmpty) {
      if (rawStudentId.isNotEmpty &&
          !rawStudentId.startsWith('STU-') &&
          !rawStudentId.startsWith('REG-')) {
        resolvedUserId = rawStudentId;
      } else if (docId.contains('_')) {
        resolvedUserId = docId.split('_').last;
      } else {
        resolvedUserId = rawStudentId;
      }
    }

    final String resolvedRoll =
        (map['rollNumber'] as String? ?? '').trim().isNotEmpty
            ? (map['rollNumber'] as String).trim()
            : ((rawStudentId.startsWith('STU') ||
                    rawStudentId.startsWith('REG'))
                ? rawStudentId
                : '');

    return RegistrationModel(
      id: docId,
      eventId: map['eventId'] as String? ?? '',
      studentId: resolvedUserId,
      eventTitle: map['eventTitle'] as String? ?? map['title'] as String? ?? '',
      studentName:
          map['studentName'] as String? ?? map['name'] as String? ?? '',
      studentEmail:
          map['studentEmail'] as String? ?? map['email'] as String? ?? '',
      rollNumber: resolvedRoll,
      phone: map['phone'] as String? ?? '',
      department:
          map['department'] as String? ?? map['branch'] as String? ?? '',
      year: map['year'] as String? ?? '',
      section: map['section'] as String? ?? 'A',
      eventDate: map['eventDate'] as String? ?? '',
      venue: map['venue'] as String? ?? '',
      amount: (map['amount'] as num? ?? 0.0).toDouble(),
      paymentStatus: map['paymentStatus'] as String? ?? PaymentStatuses.free,
      paymentReference:
          map['paymentReference'] as String? ??
          map['paymentId'] as String? ??
          '',
      registrationStatus: map['registrationStatus'] as String? ?? 'confirmed',
      ticketToken:
          map['ticketToken'] as String? ?? map['token'] as String? ?? '',
      attended:
          map['attended'] as bool? ?? (map['attendanceStatus'] == 'attended'),
      attendanceStatus:
          map['attendanceStatus'] as String? ??
          (map['attended'] == true ? 'attended' : 'not_attended'),
      registeredAt: DateFormatter.parseDateTime(map['registeredAt']),
      paidAt: map['paidAt'] != null
          ? DateFormatter.parseDateTime(map['paidAt'])
          : null,
      cancelledAt: map['cancelledAt'] != null
          ? DateFormatter.parseDateTime(map['cancelledAt'])
          : null,
      attendedAt: map['attendedAt'] != null
          ? DateFormatter.parseDateTime(map['attendedAt'])
          : null,
      verifiedByAdminUid:
          map['verifiedByAdminUid'] as String? ??
          map['verifiedBy'] as String? ??
          '',
    );
  }

  factory RegistrationModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return RegistrationModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMapForLocalJson() {
    return {
      'id': id,
      'eventId': eventId,
      'studentId': studentId,
      'userId': studentId,
      'eventTitle': eventTitle,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'rollNumber': rollNumber,
      'phone': phone,
      'department': department,
      'branch': department,
      'year': year,
      'section': section,
      'eventDate': eventDate,
      'venue': venue,
      'amount': amount,
      'paymentStatus': paymentStatus,
      'paymentReference': paymentReference,
      'paymentId': paymentReference,
      'registrationStatus': registrationStatus,
      'ticketToken': ticketToken,
      'attended': isAttended,
      'attendanceStatus': isAttended ? 'attended' : 'not_attended',
      'registeredAt': registeredAt.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'attendedAt': attendedAt?.toIso8601String(),
      'verifiedByAdminUid': verifiedByAdminUid,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'studentId': studentId,
      'userId': studentId,
      'eventTitle': eventTitle,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'rollNumber': rollNumber,
      'phone': phone,
      'department': department,
      'branch': department,
      'year': year,
      'section': section,
      'eventDate': eventDate,
      'venue': venue,
      'amount': amount,
      'paymentStatus': paymentStatus,
      'paymentReference': paymentReference,
      'paymentId': paymentReference,
      'registrationStatus': registrationStatus,
      'ticketToken': ticketToken,
      'attended': isAttended,
      'attendanceStatus': isAttended ? 'attended' : 'not_attended',
      'registeredAt': Timestamp.fromDate(registeredAt),
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'cancelledAt': cancelledAt != null
          ? Timestamp.fromDate(cancelledAt!)
          : null,
      'attendedAt': attendedAt != null ? Timestamp.fromDate(attendedAt!) : null,
      'verifiedByAdminUid': verifiedByAdminUid,
    };
  }

  RegistrationModel copyWith({
    String? id,
    String? eventId,
    String? studentId,
    String? eventTitle,
    String? studentName,
    String? studentEmail,
    String? rollNumber,
    String? phone,
    String? department,
    String? year,
    String? section,
    String? eventDate,
    String? venue,
    double? amount,
    String? paymentStatus,
    String? paymentReference,
    String? registrationStatus,
    String? ticketToken,
    bool? attended,
    String? attendanceStatus,
    DateTime? registeredAt,
    DateTime? paidAt,
    DateTime? cancelledAt,
    DateTime? attendedAt,
    String? verifiedByAdminUid,
  }) {
    return RegistrationModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      studentId: studentId ?? this.studentId,
      eventTitle: eventTitle ?? this.eventTitle,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      rollNumber: rollNumber ?? this.rollNumber,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      year: year ?? this.year,
      section: section ?? this.section,
      eventDate: eventDate ?? this.eventDate,
      venue: venue ?? this.venue,
      amount: amount ?? this.amount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentReference: paymentReference ?? this.paymentReference,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      ticketToken: ticketToken ?? this.ticketToken,
      attended: attended ?? this.attended,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      registeredAt: registeredAt ?? this.registeredAt,
      paidAt: paidAt ?? this.paidAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      attendedAt: attendedAt ?? this.attendedAt,
      verifiedByAdminUid: verifiedByAdminUid ?? this.verifiedByAdminUid,
    );
  }
}
