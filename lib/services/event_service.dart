import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';
import '../utils/constants.dart';

class EventService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _eventsCollection =>
      _db.collection('events');

  /// Generates a cryptographically unique, non-interchangeable event QR token
  static String generateEventQrToken(String eventId) {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'evtok_${eventId}_$hex';
  }

  /// Ensures an existing event in Firestore has a persistent unique QR token
  Future<String> ensureEventQrToken(String eventId) async {
    try {
      final docRef = _eventsCollection.doc(eventId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) return generateEventQrToken(eventId);

      final data = snapshot.data() ?? {};
      final existing = (data['qrToken'] ?? data['attendanceToken'] ?? '') as String;
      if (existing.isNotEmpty) return existing;

      final newToken = generateEventQrToken(eventId);
      await docRef.update({
        'qrToken': newToken,
        'attendanceToken': newToken,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return newToken;
    } catch (e) {
      return generateEventQrToken(eventId);
    }
  }

  /// Streams upcoming & active events ordered by date for student view
  Stream<List<EventModel>> streamEvents() {
    try {
      return _eventsCollection
          .orderBy('date', descending: false)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => EventModel.fromSnapshot(doc))
                .toList(),
          );
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Streams all events including drafts/cancelled for admin view
  Stream<List<EventModel>> streamAllEventsAdmin() {
    try {
      return _eventsCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => EventModel.fromSnapshot(doc))
                .toList(),
          );
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Streams events filtered by category
  Stream<List<EventModel>> streamEventsByCategory(String category) {
    try {
      if (category == EventCategories.all || category.isEmpty) {
        return streamEvents();
      }
      return _eventsCollection
          .where('category', isEqualTo: category)
          .orderBy('date', descending: false)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => EventModel.fromSnapshot(doc))
                .toList(),
          );
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Stream single event by ID
  Stream<EventModel?> streamEvent(String eventId) {
    try {
      return _eventsCollection
          .doc(eventId)
          .snapshots()
          .map((doc) => doc.exists ? EventModel.fromSnapshot(doc) : null);
    } catch (_) {
      return Stream.value(null);
    }
  }

  /// Get single event by ID
  Future<EventModel?> getEventById(String eventId) async {
    try {
      final doc = await _eventsCollection.doc(eventId).get();
      if (doc.exists) {
        return EventModel.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Creates a new event in Firestore with unique QR token (Admin feature)
  Future<String> createEvent(EventModel event) async {
    try {
      final docRef = event.id.isNotEmpty
          ? _eventsCollection.doc(event.id)
          : _eventsCollection.doc();

      final String uniqueToken = event.qrToken.isNotEmpty
          ? event.qrToken
          : generateEventQrToken(docRef.id);

      final newEvent = event.copyWith(
        id: docRef.id,
        qrToken: uniqueToken,
        availableSeats: event.maxSeats, // Initially all seats available
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await docRef.set(newEvent.toMap());
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Updates an existing event in Firestore while preserving its unique QR token
  Future<void> updateEvent(EventModel event) async {
    try {
      String token = event.qrToken;
      if (token.isEmpty) {
        final existingDoc = await _eventsCollection.doc(event.id).get();
        token = existingDoc.data()?['qrToken'] ??
            existingDoc.data()?['attendanceToken'] ??
            generateEventQrToken(event.id);
      }

      final updatedEvent = event.copyWith(
        qrToken: token,
        updatedAt: DateTime.now(),
      );
      await _eventsCollection.doc(event.id).update(updatedEvent.toMap());
    } catch (e) {
      rethrow;
    }
  }

  /// Toggles event publish/unpublish status and ensures unique QR token exists
  Future<void> togglePublishEvent(String eventId, String currentStatus) async {
    try {
      final newStatus = currentStatus == EventStatuses.upcoming
          ? EventStatuses.cancelled
          : EventStatuses.upcoming;

      final doc = await _eventsCollection.doc(eventId).get();
      final data = doc.data() ?? {};
      String token = (data['qrToken'] ?? data['attendanceToken'] ?? '') as String;

      if (newStatus == EventStatuses.upcoming && token.isEmpty) {
        token = generateEventQrToken(eventId);
      }

      final Map<String, dynamic> updateData = {
        'status': newStatus,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };
      if (token.isNotEmpty) {
        updateData['qrToken'] = token;
        updateData['attendanceToken'] = token;
      }

      await _eventsCollection.doc(eventId).update(updateData);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes an event document from Firestore safely
  Future<void> deleteEvent(String eventId) async {
    try {
      await _eventsCollection.doc(eventId).delete();
    } catch (e) {
      rethrow;
    }
  }
}

