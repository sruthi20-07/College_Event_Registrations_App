import 'web_url_launcher_stub.dart'
    if (dart.library.js_interop) 'web_url_launcher_web.dart' as platform_impl;

class PlatformUrlLauncher {
  /// Opens a URL across Flutter Web, Android, iOS and Desktop platforms safely.
  /// On Web, automatically falls back to native JS window.open if url_launcher throws
  /// MissingPluginException.
  static Future<bool> open(String url) async {
    return platform_impl.launchPlatformUrl(url);
  }
}
