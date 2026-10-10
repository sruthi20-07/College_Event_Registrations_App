import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/registration_model.dart';

class LocalRegistrationService {
  static const String _keyRegistrations = 'local_user_registrations_v1';
  static const String _keySeatsPrefix = 'local_event_seats_';

  static LocalRegistrationService? _instance;
  LocalRegistrationService._();

  factory LocalRegistrationService() {
    _instance ??= LocalRegistrationService._();
    return _instance!;
  }

  /// Get list of all locally saved registrations
  Future<List<RegistrationModel>> getRegisteredEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> rawList = prefs.getStringList(_keyRegistrations) ?? [];

      return rawList.map((item) {
        final Map<String, dynamic> map =
            jsonDecode(item) as Map<String, dynamic>;
        return RegistrationModel.fromMap(map, map['id'] as String? ?? '');
      }).toList();
    } catch (e) {
      debugPrint('LocalRegistrationService getRegisteredEvents error: $e');
      return [];
    }
  }

  /// Check if user is already registered for a specific event
  Future<bool> isRegistered(String eventId) async {
    final list = await getRegisteredEvents();
    return list.any((reg) => reg.eventId == eventId && reg.isRegistered);
  }

  /// Register student for an event locally
  Future<String> registerForEvent(RegistrationModel registration) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getRegisteredEvents();

    // Check if duplicate exists
    if (list.any((r) => r.eventId == registration.eventId && r.isRegistered)) {
      throw Exception('You are already registered for this event.');
    }

    final String docId = registration.id.isNotEmpty
        ? registration.id
        : 'REG-${registration.eventId}-${DateTime.now().millisecondsSinceEpoch}';

    final finalRegistration = registration.copyWith(
      id: docId,
      registeredAt: DateTime.now(),
      registrationStatus: 'confirmed',
    );

    final rawList = prefs.getStringList(_keyRegistrations) ?? [];
    rawList.add(jsonEncode(finalRegistration.toMapForLocalJson()));
    await prefs.setStringList(_keyRegistrations, rawList);

    return docId;
  }

  /// Get current seat count for an event, defaulting to initial seats if not customized locally
  Future<int> getAvailableSeats(String eventId, int defaultSeats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('$_keySeatsPrefix$eventId');
      if (saved != null) {
        return saved.clamp(0, defaultSeats);
      }
      return defaultSeats;
    } catch (_) {
      return defaultSeats;
    }
  }

  /// Save/update available seats count for an event
  Future<void> saveAvailableSeats(String eventId, int availableSeats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        '$_keySeatsPrefix$eventId',
        availableSeats.clamp(0, 99999),
      );
    } catch (e) {
      debugPrint('Error saving seat count: $e');
    }
  }

  /// Decrement available seats for an event by 1 safely (never below 0)
  Future<int> decrementSeats(String eventId, int currentSeats) async {
    final newSeats = (currentSeats - 1).clamp(0, 99999);
    await saveAvailableSeats(eventId, newSeats);
    return newSeats;
  }

  /// Remove a registration (cancel)
  Future<void> removeRegistration(String registrationId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getRegisteredEvents();
    list.removeWhere((r) => r.id == registrationId);

    final rawList = list.map((r) => jsonEncode(r.toMapForLocalJson())).toList();
    await prefs.setStringList(_keyRegistrations, rawList);
  }

  /// Clear all registrations (for reset/testing)
  Future<void> clearRegistrations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRegistrations);
  }
}
