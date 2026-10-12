// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String> saveAndLaunchFile(List<int> bytes, String fileName) async {
  if (bytes.isEmpty) {
    throw Exception('Workbook data is empty. Nothing to download.');
  }

  try {
    Directory? directory;
    if (Platform.isAndroid) {
      try {
        directory = await getDownloadsDirectory();
      } catch (_) {
        directory = null;
      }
    }
    directory ??= await getApplicationDocumentsDirectory();

    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    final xFile = XFile(
      file.path,
      name: fileName,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    await Share.shareXFiles(
      [xFile],
      text: 'Registration Report: $fileName',
    );
    return 'Saved to ${file.path}';
  } catch (e) {
    debugPrint('File download IO error: $e');
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes, flush: true);
    final xFile = XFile(
      tempFile.path,
      name: fileName,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    await Share.shareXFiles([xFile]);
    return 'Shared: $fileName';
  }
}
