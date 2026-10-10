import 'dart:js_interop';
import 'package:url_launcher/url_launcher.dart';

@JS('window.open')
external JSObject? _jsWindowOpen(JSString url, JSString target);

Future<bool> launchPlatformUrl(String url) async {
  final uri = Uri.parse(url);

  // 1. Try standard url_launcher on Web with platformDefault mode
  try {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (launched) return true;
  } catch (_) {
    // Falls through to direct browser window.open fallback
  }

  // 2. Direct browser JS window.open fallback (eliminates MissingPluginException)
  try {
    _jsWindowOpen(url.toJS, '_blank'.toJS);
    return true;
  } catch (_) {
    return false;
  }
}
