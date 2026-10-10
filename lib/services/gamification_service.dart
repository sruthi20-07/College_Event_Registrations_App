import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/gamification_model.dart';

class GamificationService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _gamificationCollection =>
      _db.collection('gamification');

  CollectionReference<Map<String, dynamic>> get _rewardHistoryCollection =>
      _db.collection('reward_history');

  /// Converts a DateTime into a consistent local calendar date key: 'YYYY-MM-DD'
  static String getCalendarDateKey(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Calculates calendar days difference between two 'YYYY-MM-DD' date keys
  static int daysDifference(String dateKeyA, String dateKeyB) {
    try {
      final a = DateTime.parse(dateKeyA);
      final b = DateTime.parse(dateKeyB);
      final dateOnlyA = DateTime(a.year, a.month, a.day);
      final dateOnlyB = DateTime(b.year, b.month, b.day);
      return dateOnlyB.difference(dateOnlyA).inDays;
    } catch (_) {
      return 999;
    }
  }

  /// Streams student gamification profile document in real-time
  Stream<GamificationModel?> streamGamification(String studentId) {
    if (studentId.isEmpty) return Stream.value(null);
    return _gamificationCollection
        .doc(studentId)
        .snapshots()
        .map((doc) => doc.exists ? GamificationModel.fromSnapshot(doc) : null);
  }

  /// Fetches student gamification profile once
  Future<GamificationModel?> getGamification(String studentId) async {
    if (studentId.isEmpty) return null;
    try {
      final doc = await _gamificationCollection.doc(studentId).get();
      if (doc.exists) {
        return GamificationModel.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting gamification profile: $e');
      return null;
    }
  }

  /// Streams reward history for a student ordered by newest first
  Stream<List<RewardHistoryModel>> streamRewardHistory(String studentId) {
    if (studentId.isEmpty) return Stream.value([]);
    return _rewardHistoryCollection
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => RewardHistoryModel.fromSnapshot(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Evaluates streaks, badges, and coin rewards inside an ongoing Firestore Transaction
  static Future<void> processAttendanceRewardInTransaction(
    Transaction transaction, {
    required String studentId,
    required String eventId,
    required String eventTitle,
    required DateTime attendedAt,
    required FirebaseFirestore firestore,
  }) async {
    if (studentId.isEmpty || eventId.isEmpty) return;

    final String idempotencyRewardId = '${studentId}_$eventId';
    final DocumentReference<Map<String, dynamic>> rewardRef = firestore
        .collection('reward_history')
        .doc(idempotencyRewardId);

    // 1. Check if reward history document already exists (idempotency guarantee)
    final rewardDoc = await transaction.get(rewardRef);
    if (rewardDoc.exists) {
      debugPrint(
        'Gamification reward already processed for $idempotencyRewardId',
      );
      return;
    }

    final DocumentReference<Map<String, dynamic>> gamificationRef = firestore
        .collection('gamification')
        .doc(studentId);

    final gamificationDoc = await transaction.get(gamificationRef);

    GamificationModel currentGamification;
    if (gamificationDoc.exists) {
      currentGamification = GamificationModel.fromSnapshot(gamificationDoc);
    } else {
      currentGamification = GamificationModel(studentId: studentId);
    }

    // 2. Compute calendar date and consecutive-day streak
    final String todayDateKey = getCalendarDateKey(attendedAt);
    int newStreak = currentGamification.currentStreak;
    int newLongest = currentGamification.longestStreak;

    final Set<String> distinctDates = Set<String>.from(
      currentGamification.distinctAttendedDates,
    );

    if (currentGamification.lastAttendedDate.isEmpty) {
      // First ever attendance
      newStreak = 1;
      newLongest = max(newLongest, 1);
    } else {
      final int diffDays = daysDifference(
        currentGamification.lastAttendedDate,
        todayDateKey,
      );

      if (diffDays == 0) {
        // Multiple events on the same calendar day -> streak stays the same
        newStreak = currentGamification.currentStreak > 0
            ? currentGamification.currentStreak
            : 1;
      } else if (diffDays == 1) {
        // Consecutive calendar day -> extend streak by 1
        newStreak = currentGamification.currentStreak + 1;
        newLongest = max(newLongest, newStreak);
      } else if (diffDays > 1) {
        // Gap of more than 1 day -> start a new streak of 1
        newStreak = 1;
      }
      // If diffDays < 0 (clock anomaly), keep current streak
    }

    distinctDates.add(todayDateKey);

    // 3. Increment total verified events attended and coins
    final int newTotalEvents = currentGamification.totalEventsAttended + 1;
    final int newCoins = currentGamification.coins + 50;

    // 4. Evaluate badges and unlock newly achieved milestones
    final Map<String, DateTime> updatedBadges = Map<String, DateTime>.from(
      currentGamification.unlockedBadges,
    );

    // Badges definitions:
    // 1. First Step: 1 event
    if (newTotalEvents >= 1 && !updatedBadges.containsKey('first_step')) {
      updatedBadges['first_step'] = attendedAt;
    }
    // 2. Event Explorer: 5 events
    if (newTotalEvents >= 5 && !updatedBadges.containsKey('event_explorer')) {
      updatedBadges['event_explorer'] = attendedAt;
    }
    // 3. Campus Champion: 10 events
    if (newTotalEvents >= 10 && !updatedBadges.containsKey('campus_champion')) {
      updatedBadges['campus_champion'] = attendedAt;
    }
    // 4. Consistency Star: 3 consecutive days streak
    if ((newStreak >= 3 || newLongest >= 3) &&
        !updatedBadges.containsKey('consistency_star')) {
      updatedBadges['consistency_star'] = attendedAt;
    }
    // 5. Elite Participant: 20 events
    if (newTotalEvents >= 20 &&
        !updatedBadges.containsKey('elite_participant')) {
      updatedBadges['elite_participant'] = attendedAt;
    }

    final updatedGamification = GamificationModel(
      studentId: studentId,
      coins: newCoins,
      totalEventsAttended: newTotalEvents,
      currentStreak: newStreak,
      longestStreak: newLongest,
      lastAttendedDate: todayDateKey,
      distinctAttendedDates: distinctDates.toList(),
      unlockedBadges: updatedBadges,
      updatedAt: attendedAt,
    );

    // 5. Write updated gamification profile
    transaction.set(
      gamificationRef,
      updatedGamification.toMap(),
      SetOptions(merge: true),
    );

    // 6. Write reward history record
    final rewardRecord = RewardHistoryModel(
      id: idempotencyRewardId,
      studentId: studentId,
      eventId: eventId,
      eventTitle: eventTitle.isNotEmpty ? eventTitle : 'College Event',
      coinsAwarded: 50,
      rewardType: 'attendance_verified',
      rewardReason: 'Verified Attendance (+50 Coins)',
      createdAt: attendedAt,
    );

    transaction.set(rewardRef, rewardRecord.toMap());
  }
}
