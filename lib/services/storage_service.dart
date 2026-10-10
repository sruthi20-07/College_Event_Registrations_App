import 'package:shared_preferences/shared_preferences.dart';

/// Service for local device storage (saved/bookmarked events and prototype preferences).
/// Firebase Storage poster uploading has been completely removed to operate on Firebase Spark free plan.
class StorageService {
  static const String registeredKey = 'registered_events';
  static const String savedKey = 'saved_events';

  // --- Local SharedPreferences methods for prototype compatibility ---
  static Future<List<String>> getRegisteredEvents() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(registeredKey) ?? [];
  }

  static Future<void> registerEvent(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final registered = prefs.getStringList(registeredKey) ?? [];
    if (!registered.contains(eventId)) {
      registered.add(eventId);
      await prefs.setStringList(registeredKey, registered);
    }
  }

  static Future<bool> isRegistered(String eventId) async {
    final registered = await getRegisteredEvents();
    return registered.contains(eventId);
  }

  static Future<List<String>> getSavedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(savedKey) ?? [];
  }

  static Future<bool> isSaved(String eventId) async {
    final saved = await getSavedEvents();
    return saved.contains(eventId);
  }

  static Future<void> toggleSavedEvent(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(savedKey) ?? [];
    if (saved.contains(eventId)) {
      saved.remove(eventId);
    } else {
      saved.add(eventId);
    }
    await prefs.setStringList(savedKey, saved);
  }
}
