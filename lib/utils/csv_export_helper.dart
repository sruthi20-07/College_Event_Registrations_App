import 'package:flutter/services.dart';
import '../models/registration_model.dart';
import 'date_formatter.dart';

class CsvExportHelper {
  /// Converts a list of registrations into formatted CSV string
  static String generateRegistrationsCsv(
    List<RegistrationModel> registrations,
  ) {
    final StringBuffer buffer = StringBuffer();

    // CSV HEADER
    buffer.writeln(
      'Registration ID,Student Name,Student ID,Email,Phone,Department,Year,Section,Event ID,Payment Status,Payment ID,Amount (INR),Registration Date',
    );

    // CSV ROWS
    for (final reg in registrations) {
      final String regId = reg.id.replaceAll(',', ' ');
      final String name = reg.studentName.replaceAll(',', ' ');
      final String studentId = reg.rollNumber.replaceAll(',', ' ');
      final String email = reg.studentEmail.replaceAll(',', ' ');
      final String phone = reg.phone.replaceAll(',', ' ');
      final String dept = reg.department.replaceAll(',', ' ');
      final String year = reg.year.replaceAll(',', ' ');
      final String section = reg.section.replaceAll(',', ' ');
      final String eventId = reg.eventId.replaceAll(',', ' ');
      final String payStatus = reg.paymentStatus.replaceAll(',', ' ');
      final String payId = reg.paymentId.replaceAll(',', ' ');
      final String amount = reg.amount.toStringAsFixed(2);
      final String regDate = DateFormatter.formatDate(reg.registeredAt);

      buffer.writeln(
        '$regId,$name,$studentId,$email,$phone,$dept,$year,$section,$eventId,$payStatus,$payId,$amount,$regDate',
      );
    }

    return buffer.toString();
  }

  /// Copies CSV data to system clipboard
  static Future<void> copyCsvToClipboard(
    List<RegistrationModel> registrations,
  ) async {
    final csvContent = generateRegistrationsCsv(registrations);
    await Clipboard.setData(ClipboardData(text: csvContent));
  }
}
