import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';
import '../utils/constants.dart';

class EventService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _eventsCollection =>
      _db.collection('events');

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

  /// Creates a new event in Firestore (Admin feature)
  Future<String> createEvent(EventModel event) async {
    try {
      final docRef = event.id.isNotEmpty
          ? _eventsCollection.doc(event.id)
          : _eventsCollection.doc();

      final newEvent = event.copyWith(
        id: docRef.id,
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

  /// Updates an existing event in Firestore
  Future<void> updateEvent(EventModel event) async {
    try {
      final updatedEvent = event.copyWith(updatedAt: DateTime.now());
      await _eventsCollection.doc(event.id).update(updatedEvent.toMap());
    } catch (e) {
      rethrow;
    }
  }

  /// Toggles event publish/unpublish status
  Future<void> togglePublishEvent(String eventId, String currentStatus) async {
    try {
      final newStatus = currentStatus == EventStatuses.upcoming
          ? EventStatuses.cancelled
          : EventStatuses.upcoming;

      await _eventsCollection.doc(eventId).update({
        'status': newStatus,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
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
