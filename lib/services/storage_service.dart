import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String registeredKey = 'registered_events';
  static const String savedKey = 'saved_events';

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads event poster bytes to Firebase Storage and returns download URL.
  /// Works reliably on Flutter Web and Mobile platforms using putData().
  Future<String> uploadEventPosterBytes(
    Uint8List imageBytes,
    String eventId, {
    String contentType = 'image/jpeg',
  }) async {
    try {
      final fileName =
          '${eventId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('event_posters').child(fileName);
      final metadata = SettableMetadata(contentType: contentType);
      final uploadTask = await ref.putData(imageBytes, metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading poster bytes to Firebase Storage: $e');
      rethrow;
    }
  }

  // --- Local SharedPreferences legacy methods for prototype compatibility ---
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
