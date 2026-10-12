// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

Future<String> saveAndLaunchFile(List<int> bytes, String fileName) async {
  if (bytes.isEmpty) {
    throw Exception('Workbook data is empty. Nothing to download.');
  }

  try {
    // 1. Ensure bytes are a true typed Uint8List (maps to JavaScript Uint8Array)
    final Uint8List uint8list =
        bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    // 2. Create binary Blob with exact OpenXML spreadsheet MIME type
    final blob = html.Blob(
      [uint8list],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);

    // 3. Create an <a> anchor element connected to layout (not display: none)
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..download = fileName
      ..style.position = 'fixed'
      ..style.left = '-9999px'
      ..style.top = '-9999px'
      ..style.opacity = '0';

    html.document.body?.children.add(anchor);

    // 4. Trigger genuine browser download
    anchor.click();

    // 5. Clean up both DOM anchor and Blob object URL after generous delay
    // This delay is essential: Chromium requires the element to remain connected
    // and the object URL to remain active until the browser's download manager
    // completes the request. Never remove anchor synchronously in the same microtask.
    Future.delayed(const Duration(seconds: 5), () {
      try {
        anchor.remove();
        html.Url.revokeObjectUrl(url);
      } catch (_) {}
    });

    debugPrint('Web download initiated: $fileName (${uint8list.lengthInBytes} bytes)');
    return 'Downloaded $fileName';
  } catch (e, stack) {
    debugPrint('saveAndLaunchFile error: $e\n$stack');
    rethrow;
  }
}
