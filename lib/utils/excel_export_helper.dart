import 'package:excel/excel.dart';
import '../models/registration_model.dart';
import 'date_formatter.dart';
import 'file_download_helper.dart';

class ExcelExportHelper {
  /// Generates a sanitized safe filename for the event registration workbook
  /// e.g. selecting 'FSD hackathon' -> 'FSD_Hackathon_Registrations.xlsx'
  /// All events -> 'All_Events_Registrations.xlsx'
  static String getSafeFileName({String? eventTitle, String? eventId}) {
    final title = (eventTitle ?? '').trim();
    final id = (eventId ?? '').trim();

    if (id.isEmpty ||
        id.toLowerCase() == 'all' ||
        id.toLowerCase() == 'all_events' ||
        title.toLowerCase() == 'all events') {
      return 'All_Events_Registrations.xlsx';
    }

    if (title.isNotEmpty) {
      // Remove special symbols like & ! ? ( ) etc. first
      final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s-]'), ' ');
      final words = sanitizedTitle
          .split(RegExp(r'[\s_-]+'))
          .where((w) => w.isNotEmpty)
          .toList();

      final formattedWords = words.map((w) {
        if (w.length <= 1) return w.toUpperCase();
        // Keep acronyms uppercase if already all-caps (like FSD, AI, IT)
        if (w == w.toUpperCase()) return w;
        return w[0].toUpperCase() + w.substring(1).toLowerCase();
      }).toList();

      final cleanTitle = formattedWords.join('_');
      if (cleanTitle.isNotEmpty) {
        return '${cleanTitle}_Registrations.xlsx';
      }
    }

    final cleanId = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final effectiveId = cleanId.isNotEmpty ? cleanId : 'All_Events';
    return '${effectiveId}_Registrations.xlsx';
  }

  /// Generates real .xlsx bytes with two worksheets:
  /// Worksheet 1: 'Registrations' (16 clean data columns with header)
  /// Worksheet 2: 'Summary' (comprehensive totals, revenue, status breakdowns)
  static List<int> generateRegistrationsExcel({
    required List<RegistrationModel> registrations,
    required String eventTitle,
    required String eventId,
    Map<String, String>? eventNamesById,
  }) {
    final excel = Excel.createExcel();

    // 1. SETUP WORKSHEET 1: REGISTRATIONS
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    const regSheetName = 'Registrations';
    excel.rename(defaultSheet, regSheetName);
    final regSheet = excel[regSheetName];

    final bool isAllEvents = eventId.isEmpty ||
        eventId.toLowerCase() == 'all' ||
        eventId.toLowerCase() == 'all_events' ||
        eventTitle.toLowerCase() == 'all events';

    final String displayTitle = isAllEvents
        ? 'All Events'
        : (eventTitle.isNotEmpty ? eventTitle : 'Event ID: $eventId');
    final String displayId = isAllEvents ? 'ALL' : eventId;

    // Compact Report Header (Worksheet 1)
    regSheet.appendRow([
      TextCellValue('COLLEGE EVENT REGISTRATION REPORT'),
    ]);
    regSheet.appendRow([
      TextCellValue('Selected Event: $displayTitle'),
      TextCellValue('Event ID: $displayId'),
    ]);
    regSheet.appendRow([
      TextCellValue('Generated At: ${DateFormatter.formatDateTime(DateTime.now())}'),
      TextCellValue('Total Records: ${registrations.length}'),
    ]);
    regSheet.appendRow([TextCellValue('')]); // Blank spacer row

    // Table Column Headers (16 Columns)
    final columnHeaders = [
      'Registration ID',
      'Student Name',
      'Roll Number',
      'Student Email',
      'Contact Number',
      'Department',
      'Year',
      'Section',
      'Event Name',
      'Registration Date',
      'Registration Status',
      'Payment Status',
      'Amount (INR)',
      'Payment Reference ID',
      'Attendance Status',
      'Attended At',
    ];

    regSheet.appendRow(columnHeaders.map((h) => TextCellValue(h)).toList());

    // Data Rows
    for (final reg in registrations) {
      final String regId = reg.id.isNotEmpty ? reg.id : 'N/A';
      final String name = reg.studentName.isNotEmpty ? reg.studentName : 'N/A';
      final String roll = reg.rollNumber.isNotEmpty ? reg.rollNumber : 'N/A';
      final String email = reg.studentEmail.isNotEmpty ? reg.studentEmail : 'N/A';
      final String phone = reg.phone.isNotEmpty
          ? reg.phone
          : (reg.whatsappNumber.isNotEmpty ? reg.whatsappNumber : 'N/A');
      final String dept = reg.department.isNotEmpty ? reg.department : 'N/A';
      final String year = reg.year.isNotEmpty ? reg.year : 'N/A';
      final String section = reg.section.isNotEmpty ? reg.section : 'A';

      // Accurate event name resolution without showing N/A when relationship exists
      String resolvedEventName;
      if (reg.eventTitle.isNotEmpty) {
        resolvedEventName = reg.eventTitle;
      } else if (eventNamesById != null &&
          eventNamesById.containsKey(reg.eventId) &&
          eventNamesById[reg.eventId]!.isNotEmpty) {
        resolvedEventName = eventNamesById[reg.eventId]!;
      } else if (!isAllEvents && eventTitle.isNotEmpty) {
        resolvedEventName = eventTitle;
      } else if (reg.eventId.isEmpty) {
        resolvedEventName = 'Missing Event Reference';
      } else {
        resolvedEventName = 'Event ID: ${reg.eventId}';
      }

      final String regDate = DateFormatter.formatDateTime(reg.registeredAt);
      final String regStatus = reg.registrationStatus.toUpperCase();
      final String payStatus = reg.paymentStatus.toUpperCase();
      final double amount = reg.amount;
      final String payRef =
          reg.paymentReference.isNotEmpty ? reg.paymentReference : 'N/A';
      final String attendStatus = reg.isAttended ? 'ATTENDED' : 'NOT ATTENDED';
      final String attendedAt = reg.attendedAt != null
          ? DateFormatter.formatDateTime(reg.attendedAt!)
          : 'N/A';

      regSheet.appendRow([
        TextCellValue(regId),
        TextCellValue(name),
        TextCellValue(roll),
        TextCellValue(email),
        TextCellValue(phone),
        TextCellValue(dept),
        TextCellValue(year),
        TextCellValue(section),
        TextCellValue(resolvedEventName),
        TextCellValue(regDate),
        TextCellValue(regStatus),
        TextCellValue(payStatus),
        DoubleCellValue(amount),
        TextCellValue(payRef),
        TextCellValue(attendStatus),
        TextCellValue(attendedAt),
      ]);
    }

    // Set readable column widths for Worksheet 1
    final widths = [
      24.0, // Registration ID
      22.0, // Student Name
      16.0, // Roll Number
      28.0, // Student Email
      16.0, // Contact Number
      24.0, // Department
      12.0, // Year
      10.0, // Section
      26.0, // Event Name
      20.0, // Registration Date
      18.0, // Registration Status
      16.0, // Payment Status
      14.0, // Amount (INR)
      26.0, // Payment Reference ID
      18.0, // Attendance Status
      20.0, // Attended At
    ];
    for (int i = 0; i < widths.length; i++) {
      regSheet.setColumnWidth(i, widths[i]);
    }

    // 2. SETUP WORKSHEET 2: SUMMARY
    const summarySheetName = 'Summary';
    final summarySheet = excel[summarySheetName];

    // Compute metrics
    int totalPaid = 0;
    int totalFree = 0;
    int totalAttended = 0;
    double totalRevenue = 0.0;
    final Map<String, int> regStatusCounts = {};
    final Map<String, int> payStatusCounts = {};

    for (final reg in registrations) {
      // Registration status breakdown
      final String rs = reg.registrationStatus.trim().isEmpty
          ? 'CONFIRMED'
          : reg.registrationStatus.trim().toUpperCase();
      regStatusCounts[rs] = (regStatusCounts[rs] ?? 0) + 1;

      // Payment status breakdown
      final String rawPay = reg.paymentStatus.trim();
      final String psLower = rawPay.toLowerCase();
      final String psKey = rawPay.isEmpty ? 'FREE' : rawPay.toUpperCase();
      payStatusCounts[psKey] = (payStatusCounts[psKey] ?? 0) + 1;

      // Check valid paid records vs free records
      final bool isPaid = (psLower == 'paid' || psLower == 'completed') && psLower != 'free';
      if (isPaid) {
        totalPaid++;
        if (reg.amount > 0) {
          totalRevenue += reg.amount;
        }
      } else if (psLower == 'free') {
        totalFree++;
      }

      if (reg.isAttended) {
        totalAttended++;
      }
    }

    final int totalNotAttended = (registrations.length - totalAttended).clamp(0, registrations.length);

    // Build Summary Sheet Content
    summarySheet.appendRow([TextCellValue('COLLEGE EVENT REGISTRATION SUMMARY')]);
    summarySheet.appendRow([
      TextCellValue('Scope: $displayTitle'),
      TextCellValue('Event ID: $displayId'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Generated At: ${DateFormatter.formatDateTime(DateTime.now())}'),
    ]);
    summarySheet.appendRow([TextCellValue('')]);

    summarySheet.appendRow([TextCellValue('KEY METRICS'), TextCellValue('')]);
    summarySheet.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);
    summarySheet.appendRow([
      TextCellValue('Total Registered'),
      IntCellValue(registrations.length),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total Paid Registrations'),
      IntCellValue(totalPaid),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total Free Registrations'),
      IntCellValue(totalFree),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total Attended'),
      IntCellValue(totalAttended),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total Not Attended'),
      IntCellValue(totalNotAttended),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total Revenue (INR)'),
      DoubleCellValue(totalRevenue),
    ]);

    summarySheet.appendRow([TextCellValue('')]);
    summarySheet.appendRow([TextCellValue('REGISTRATION STATUS BREAKDOWN'), TextCellValue('')]);
    summarySheet.appendRow([TextCellValue('Status'), TextCellValue('Count')]);
    if (regStatusCounts.isEmpty) {
      summarySheet.appendRow([TextCellValue('No records'), IntCellValue(0)]);
    } else {
      for (final entry in regStatusCounts.entries) {
        summarySheet.appendRow([TextCellValue(entry.key), IntCellValue(entry.value)]);
      }
    }

    summarySheet.appendRow([TextCellValue('')]);
    summarySheet.appendRow([TextCellValue('PAYMENT STATUS BREAKDOWN'), TextCellValue('')]);
    summarySheet.appendRow([TextCellValue('Payment Status'), TextCellValue('Count')]);
    if (payStatusCounts.isEmpty) {
      summarySheet.appendRow([TextCellValue('No records'), IntCellValue(0)]);
    } else {
      for (final entry in payStatusCounts.entries) {
        summarySheet.appendRow([TextCellValue(entry.key), IntCellValue(entry.value)]);
      }
    }

    summarySheet.appendRow([TextCellValue('')]);
    summarySheet.appendRow([TextCellValue('ATTENDANCE STATUS BREAKDOWN'), TextCellValue('')]);
    summarySheet.appendRow([TextCellValue('Attendance Status'), TextCellValue('Count')]);
    summarySheet.appendRow([TextCellValue('ATTENDED'), IntCellValue(totalAttended)]);
    summarySheet.appendRow([TextCellValue('NOT ATTENDED'), IntCellValue(totalNotAttended)]);

    summarySheet.setColumnWidth(0, 32.0);
    summarySheet.setColumnWidth(1, 20.0);

    // Set Registrations as the default active sheet
    excel.setDefaultSheet(regSheetName);

    // Use encode() which returns byte array WITHOUT triggering automatic web download
    final bytes = excel.encode();
    return bytes ?? <int>[];
  }

  /// Generates the .xlsx file and triggers platform download / share
  static Future<String> downloadRegistrationsExcel({
    required List<RegistrationModel> registrations,
    required String eventTitle,
    required String eventId,
    Map<String, String>? eventNamesById,
  }) async {
    final bytes = generateRegistrationsExcel(
      registrations: registrations,
      eventTitle: eventTitle,
      eventId: eventId,
      eventNamesById: eventNamesById,
    );

    if (bytes.isEmpty) {
      throw Exception('Failed to generate Excel workbook data.');
    }

    final fileName = getSafeFileName(eventTitle: eventTitle, eventId: eventId);
    return await FileDownloadHelper.downloadFile(
      bytes: bytes,
      fileName: fileName,
    );
  }
}
