import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/feedback_model.dart';

class FeedbackService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _feedbackCollection =
      _db.collection('app_feedback');

  /// Submits student feedback to Firestore
  static Future<void> submitFeedback({
    required int rating,
    String? message,
    String? feedback,
    String category = 'General',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Must be logged in to submit feedback.');
      }

      final String content = (message ?? feedback ?? '').trim();
      if (content.isEmpty) {
        throw Exception('Please provide a feedback message.');
      }

      String studentName = user.displayName ?? '';
      String rollNumber = '';
      String department = '';

      // Hydrate from user profile if available
      try {
        final userDoc = await _db.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() ?? {};
          if (studentName.isEmpty) studentName = data['name'] ?? '';
          rollNumber = data['rollNumber'] ?? '';
          department = data['department'] ?? '';
        }
      } catch (e) {
        debugPrint('Could not fetch user profile for feedback: $e');
      }

      final docRef = _feedbackCollection.doc();
      final newFeedback = FeedbackModel(
        id: docRef.id,
        studentUid: user.uid,
        studentName: studentName.isNotEmpty ? studentName : 'College Student',
        studentEmail: user.email ?? '',
        rollNumber: rollNumber,
        department: department,
        rating: rating.clamp(1, 5),
        message: content,
        category: category,
        createdAt: DateTime.now(),
      );

      await docRef.set(newFeedback.toMap());
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
      rethrow;
    }
  }

  /// Real-time stream of all feedback submissions for Admins
  static Stream<List<FeedbackModel>> streamAllFeedback() {
    return _feedbackCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FeedbackModel.fromSnapshot(doc))
              .toList();
        });
  }

  /// Real-time stream of student's own feedback
  static Stream<List<FeedbackModel>> streamUserFeedback(String uid) {
    return _feedbackCollection
        .where('studentUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FeedbackModel.fromSnapshot(doc))
              .toList();
        });
  }
}
