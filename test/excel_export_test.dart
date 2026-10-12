import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:college_event_app/utils/excel_export_helper.dart';
import 'package:college_event_app/utils/file_download_helper.dart';

void main() {
  test('Test excel package creation and byte encoding with encode()', () {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[defaultSheet];

    sheet.appendRow([
      TextCellValue('Registration ID'),
      TextCellValue('Student Name'),
      TextCellValue('Roll Number'),
      TextCellValue('Email'),
      TextCellValue('Phone'),
      TextCellValue('Department'),
      TextCellValue('Year'),
      TextCellValue('Event Name'),
      TextCellValue('Registration Date'),
      TextCellValue('Registration Status'),
      TextCellValue('Payment Status'),
      TextCellValue('Amount (INR)'),
      TextCellValue('Attendance Status'),
    ]);

    sheet.appendRow([
      TextCellValue('REG_101'),
      TextCellValue('Aarav Sharma'),
      TextCellValue('21CS045'),
      TextCellValue('aarav@college.edu'),
      TextCellValue('9876543210'),
      TextCellValue('CSE'),
      TextCellValue('3rd Year'),
      TextCellValue('Hackathon 2026'),
      TextCellValue('2026-11-15 10:30 AM'),
      TextCellValue('confirmed'),
      TextCellValue('paid'),
      DoubleCellValue(150.0),
      TextCellValue('attended'),
    ]);

    // Use encode() which yields pure OpenXML ZIP bytes without triggering browser downloads
    final bytes = excel.encode();
    expect(bytes, isNotNull);
    expect(bytes!.isNotEmpty, isTrue);
    // Excel files are ZIP archives starting with PK (0x50, 0x4B, 0x03, 0x04)
    expect(bytes[0], 0x50);
    expect(bytes[1], 0x4B);
  });

  test('Safe filename generator creates distinct filenames for different events', () {
    final file1 = ExcelExportHelper.getSafeFileName(eventTitle: 'FSD Hackathon', eventId: 'evt_1');
    final file2 = ExcelExportHelper.getSafeFileName(eventTitle: 'AI Workshop', eventId: 'evt_2');
    final fileAll = ExcelExportHelper.getSafeFileName(eventTitle: 'All Events', eventId: 'all_events');

    expect(file1, 'FSD_Hackathon_Registrations.xlsx');
    expect(file2, 'AI_Workshop_Registrations.xlsx');
    expect(fileAll, 'All_Events_Registrations.xlsx');
    expect(file1 != file2, isTrue);
  });

  test('generateRegistrationsExcel produces non-empty bytes for any event and registrations list', () {
    final bytes = ExcelExportHelper.generateRegistrationsExcel(
      registrations: [],
      eventTitle: 'Empty Event',
      eventId: 'evt_empty',
    );
    expect(bytes.isNotEmpty, isTrue);
    expect(bytes[0], 0x50);
    expect(bytes[1], 0x4B);
  });

  test('FileDownloadHelper.downloadFile throws when bytes are empty', () async {
    expect(
      () => FileDownloadHelper.downloadFile(bytes: [], fileName: 'test.xlsx'),
      throwsA(isA<Exception>()),
    );
  });
}
