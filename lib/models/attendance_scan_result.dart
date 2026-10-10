import 'registration_model.dart';

enum AttendanceScanStatus {
  verified,
  alreadyCheckedIn,
  invalidTicket,
  registrationCancelled,
  paymentPending,
  wrongEvent,
  unauthorizedAdmin,
  error,
}

class AttendanceScanResult {
  final AttendanceScanStatus status;
  final String message;
  final RegistrationModel? registration;
  final DateTime? attendedAt;

  const AttendanceScanResult({
    required this.status,
    required this.message,
    this.registration,
    this.attendedAt,
  });

  bool get isSuccess => status == AttendanceScanStatus.verified;
  bool get isAlreadyCheckedIn =>
      status == AttendanceScanStatus.alreadyCheckedIn;

  String get title {
    switch (status) {
      case AttendanceScanStatus.verified:
        return 'Attendance Verified ✓';
      case AttendanceScanStatus.alreadyCheckedIn:
        return 'Already Checked In';
      case AttendanceScanStatus.invalidTicket:
        return 'Invalid Ticket';
      case AttendanceScanStatus.registrationCancelled:
        return 'Registration Cancelled';
      case AttendanceScanStatus.paymentPending:
        return 'Payment Pending';
      case AttendanceScanStatus.wrongEvent:
        return 'Wrong Event';
      case AttendanceScanStatus.unauthorizedAdmin:
        return 'Unauthorized Administrator';
      case AttendanceScanStatus.error:
        return 'Verification Error';
    }
  }
}
