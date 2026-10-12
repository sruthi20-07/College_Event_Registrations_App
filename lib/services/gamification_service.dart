import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/event_model.dart';
import '../models/gamification_model.dart';
import '../models/registration_model.dart';
import '../models/reward_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class GamificationService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _gamificationCollection =>
      _db.collection('gamification');

  CollectionReference<Map<String, dynamic>> get _rewardHistoryCollection =>
      _db.collection('reward_history');

  CollectionReference<Map<String, dynamic>> get _rewardsCollection =>
      _db.collection('rewards');

  CollectionReference<Map<String, dynamic>> get _redemptionsCollection =>
      _db.collection('redemptions');

  CollectionReference<Map<String, dynamic>> get _rulesCollection =>
      _db.collection('gamification_rules');

  CollectionReference<Map<String, dynamic>> get _referralsCollection =>
      _db.collection('referrals');

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

  // ==========================================
  // 1. PROFILE & REAL-TIME STREAMS
  // ==========================================

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

  /// Streams unified coin transaction ledger entries for a student
  Stream<List<CoinTransactionModel>> streamCoinTransactions(String studentId) {
    if (studentId.isEmpty) return Stream.value([]);
    return _rewardHistoryCollection
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => CoinTransactionModel.fromSnapshot(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // ==========================================
  // 2. CORE ATTENDANCE & EARNING CALCULATOR
  // ==========================================

  /// Computes updated gamification profile and reward record from existing state.
  /// Backward compatible: preserves exact signature while updating lifetimeCoins and streak rules.
  static ({GamificationModel updatedGamification, RewardHistoryModel rewardRecord}) computeReward({
    required GamificationModel currentGamification,
    required String studentId,
    required String eventId,
    required String eventTitle,
    required DateTime attendedAt,
    int coinAward = 50,
  }) {
    final String idempotencyRewardId = '${studentId}_$eventId';

    // 1. Compute calendar date and consecutive-day streak
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
    }

    distinctDates.add(todayDateKey);

    // 2. Increment total verified events attended and coins
    final int newTotalEvents = currentGamification.totalEventsAttended + 1;
    final int newCoins = currentGamification.coins + coinAward;
    final int newLifetime = currentGamification.lifetimeCoins + coinAward;

    // 3. Evaluate badges and unlock newly achieved milestones
    final Map<String, DateTime> updatedBadges = Map<String, DateTime>.from(
      currentGamification.unlockedBadges,
    );

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
      lifetimeCoins: newLifetime,
      totalEventsAttended: newTotalEvents,
      currentStreak: newStreak,
      longestStreak: newLongest,
      lastAttendedDate: todayDateKey,
      distinctAttendedDates: distinctDates.toList(),
      unlockedBadges: updatedBadges,
      referralCode: currentGamification.referralCode,
      referredBy: currentGamification.referredBy,
      updatedAt: attendedAt,
    );

    final rewardRecord = RewardHistoryModel(
      id: idempotencyRewardId,
      studentId: studentId,
      eventId: eventId,
      eventTitle: eventTitle.isNotEmpty ? eventTitle : 'College Event',
      coinsAwarded: coinAward,
      rewardType: 'attendance_verified',
      rewardReason: 'Verified Attendance (+$coinAward Coins)',
      createdAt: attendedAt,
    );

    return (updatedGamification: updatedGamification, rewardRecord: rewardRecord);
  }

  /// Evaluates streaks, badges, and coin rewards inside an ongoing Firestore Transaction.
  static Future<void> processAttendanceRewardInTransaction(
    Transaction transaction, {
    required String studentId,
    required String eventId,
    required String eventTitle,
    required DateTime attendedAt,
    required FirebaseFirestore firestore,
    int coinAward = 50,
  }) async {
    if (studentId.isEmpty || eventId.isEmpty) return;

    final String idempotencyRewardId = '${studentId}_$eventId';
    final DocumentReference<Map<String, dynamic>> rewardRef = firestore
        .collection('reward_history')
        .doc(idempotencyRewardId);

    // READ 1: Check if reward history document already exists (idempotency guarantee)
    final rewardDoc = await transaction.get(rewardRef);
    if (rewardDoc.exists) {
      debugPrint(
        'Gamification reward already processed for $idempotencyRewardId',
      );
      return;
    }

    // READ 2: Get current gamification profile
    final DocumentReference<Map<String, dynamic>> gamificationRef = firestore
        .collection('gamification')
        .doc(studentId);
    final gamificationDoc = await transaction.get(gamificationRef);

    final GamificationModel currentGamification = gamificationDoc.exists
        ? GamificationModel.fromSnapshot(gamificationDoc)
        : GamificationModel(studentId: studentId);

    // COMPUTE
    final result = computeReward(
      currentGamification: currentGamification,
      studentId: studentId,
      eventId: eventId,
      eventTitle: eventTitle,
      attendedAt: attendedAt,
      coinAward: coinAward,
    );

    // WRITES
    transaction.set(
      gamificationRef,
      result.updatedGamification.toMap(),
      SetOptions(merge: true),
    );

    transaction.set(rewardRef, result.rewardRecord.toMap());
  }

  // ==========================================
  // 3. REWARDS CATALOGUE MANAGEMENT
  // ==========================================

  /// Streams active available rewards for students
  Stream<List<RewardModel>> streamActiveRewards() {
    return _rewardsCollection
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => RewardModel.fromSnapshot(doc))
              .where((r) => r.isEnabled && !r.isExpired)
              .toList();
          list.sort((a, b) => a.coinCost.compareTo(b.coinCost));
          return list;
        });
  }

  /// Streams all rewards for administrators (including disabled and expired)
  Stream<List<RewardModel>> streamAllRewardsAdmin() {
    return _rewardsCollection
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => RewardModel.fromSnapshot(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Fetches a specific reward by ID
  Future<RewardModel?> getReward(String rewardId) async {
    try {
      final doc = await _rewardsCollection.doc(rewardId).get();
      if (doc.exists) {
        return RewardModel.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting reward: $e');
      return null;
    }
  }

  /// Creates a new reward in the catalogue
  Future<void> createReward(RewardModel reward) async {
    final ref = reward.id.isNotEmpty
        ? _rewardsCollection.doc(reward.id)
        : _rewardsCollection.doc();
    final toSave = reward.copyWith(id: ref.id, createdAt: DateTime.now(), updatedAt: DateTime.now());
    await ref.set(toSave.toMap());
  }

  /// Updates an existing reward in the catalogue
  Future<void> updateReward(RewardModel reward) async {
    final ref = _rewardsCollection.doc(reward.id);
    final toSave = reward.copyWith(updatedAt: DateTime.now());
    await ref.update(toSave.toMap());
  }

  /// Toggles enabled/disabled status of a reward
  Future<void> toggleRewardStatus(String rewardId, bool isEnabled) async {
    await _rewardsCollection.doc(rewardId).update({
      'isEnabled': isEnabled,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Deletes a reward from the catalogue
  Future<void> deleteReward(String rewardId) async {
    await _rewardsCollection.doc(rewardId).delete();
  }

  // ==========================================
  // 4. SECURE REWARD REDEMPTION & FULFILMENT
  // ==========================================

  /// Streams redemptions for a student
  Stream<List<RewardRedemptionModel>> streamStudentRedemptions(String studentId) {
    if (studentId.isEmpty) return Stream.value([]);
    return _redemptionsCollection
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => RewardRedemptionModel.fromSnapshot(doc))
              .toList();
          list.sort((a, b) => b.redeemedAt.compareTo(a.redeemedAt));
          return list;
        });
  }

  /// Streams redemptions for admins with optional status filter
  Stream<List<RewardRedemptionModel>> streamAllRedemptionsAdmin({String? statusFilter}) {
    Query<Map<String, dynamic>> query = _redemptionsCollection;
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => RewardRedemptionModel.fromSnapshot(doc))
          .toList();
      list.sort((a, b) => b.redeemedAt.compareTo(a.redeemedAt));
      return list;
    });
  }

  /// Transactionally redeems a standard reward (perk, certificate benefit, etc.)
  Future<RewardRedemptionModel> redeemReward({
    required String studentId,
    required String rewardId,
    required UserModel studentUser,
  }) async {
    if (studentId.isEmpty || rewardId.isEmpty) {
      throw Exception('Invalid student ID or reward ID.');
    }

    final String redemptionDocId = 'RED-${DateTime.now().millisecondsSinceEpoch}-${studentId.substring(0, min(4, studentId.length))}';

    return await _db.runTransaction((transaction) async {
      final rewardRef = _rewardsCollection.doc(rewardId);
      final rewardDoc = await transaction.get(rewardRef);

      if (!rewardDoc.exists) {
        throw Exception('Reward does not exist or has been removed.');
      }

      final reward = RewardModel.fromSnapshot(rewardDoc);

      if (!reward.isEnabled) {
        throw Exception('This reward is currently disabled.');
      }

      if (reward.isExpired) {
        throw Exception('This reward has expired.');
      }

      if (reward.isOutOfStock) {
        throw Exception('Sorry, this reward is out of stock.');
      }

      // Check year eligibility
      if (reward.eligibilityYears.isNotEmpty &&
          !reward.eligibilityYears.contains('All') &&
          !reward.eligibilityYears.contains('All Years')) {
        if (!AcademicYears.matches(reward.eligibilityYears, studentUser.year)) {
          throw Exception(
            'Ineligible: This reward is restricted to ${reward.eligibilityYears.join(', ')}.',
          );
        }
      }

      // Check department eligibility
      if (reward.eligibilityDepartments.isNotEmpty &&
          !reward.eligibilityDepartments.contains('All') &&
          !reward.eligibilityDepartments.contains('All Departments')) {
        if (!AcademicDepartments.matches(
          reward.eligibilityDepartments,
          studentUser.department,
        )) {
          throw Exception(
            'Ineligible: This reward is restricted to ${reward.eligibilityDepartments.join(', ')}.',
          );
        }
      }

      // READ student's gamification balance
      final gamificationRef = _gamificationCollection.doc(studentId);
      final gamificationDoc = await transaction.get(gamificationRef);

      final currentGamification = gamificationDoc.exists
          ? GamificationModel.fromSnapshot(gamificationDoc)
          : GamificationModel(studentId: studentId);

      if (currentGamification.coins < reward.coinCost) {
        throw Exception(
          'Insufficient coins: You have ${currentGamification.coins} coins, but ${reward.coinCost} are required.',
        );
      }

      // Check per-student redemption limit
      if (reward.perStudentLimit > 0) {
        final existingRedemptionsQuery = await _redemptionsCollection
            .where('studentId', isEqualTo: studentId)
            .where('rewardId', isEqualTo: rewardId)
            .get();
        final activeCount = existingRedemptionsQuery.docs.where((d) {
          final s = d.data()['status'] as String? ?? '';
          return s != RedemptionStatuses.rejected &&
              s != RedemptionStatuses.cancelled &&
              s != RedemptionStatuses.refunded;
        }).length;

        if (activeCount >= reward.perStudentLimit) {
          throw Exception(
            'You have reached the maximum redemption limit (${reward.perStudentLimit}) for this reward.',
          );
        }
      }

      // DEDUCT COINS: spendable balance decreases, lifetimeCoins remains unchanged!
      final newSpendableCoins = currentGamification.coins - reward.coinCost;
      final updatedGamification = currentGamification.copyWith(
        coins: newSpendableCoins,
        updatedAt: DateTime.now(),
      );

      // DECREMENT STOCK IF FINITE
      if (!reward.isUnlimitedStock) {
        final newStock = max(0, reward.availableStock - 1);
        transaction.update(rewardRef, {
          'availableStock': newStock,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      // WRITE UPDATED GAMIFICATION
      transaction.set(
        gamificationRef,
        updatedGamification.toMap(),
        SetOptions(merge: true),
      );

      // WRITE REDEMPTION DOCUMENT
      final now = DateTime.now();
      final redemption = RewardRedemptionModel(
        id: redemptionDocId,
        studentId: studentId,
        studentName: studentUser.name,
        studentRoll: studentUser.rollNumber,
        studentEmail: studentUser.email,
        rewardId: reward.id,
        rewardTitle: reward.title,
        rewardCategory: reward.category,
        coinCost: reward.coinCost,
        status: reward.fulfilmentType == 'automatic'
            ? RedemptionStatuses.approved
            : RedemptionStatuses.pending,
        statusReason: 'Redeemed with ${reward.coinCost} coins',
        idempotencyKey: redemptionDocId,
        redeemedAt: now,
      );

      final redemptionRef = _redemptionsCollection.doc(redemptionDocId);
      transaction.set(redemptionRef, redemption.toMap());

      // WRITE DEBIT LEDGER ENTRY
      final ledgerRef = _rewardHistoryCollection.doc('${redemptionDocId}_ledger');
      final ledgerEntry = CoinTransactionModel(
        id: '${redemptionDocId}_ledger',
        studentId: studentId,
        amount: -reward.coinCost,
        type: 'reward_redemption',
        title: 'Redeemed: ${reward.title}',
        description: 'Spent ${reward.coinCost} coins for ${reward.title}',
        refId: reward.id,
        idempotencyKey: redemptionDocId,
        createdAt: now,
      );
      transaction.set(ledgerRef, ledgerEntry.toMap());

      return redemption;
    });
  }

  /// Transactionally redeems a Free Event Registration reward and creates a genuine registration
  Future<({RewardRedemptionModel redemption, RegistrationModel registration})> redeemFreeEventRegistration({
    required String studentId,
    required String rewardId,
    required EventModel event,
    required UserModel studentUser,
  }) async {
    if (studentId.isEmpty || rewardId.isEmpty || event.id.isEmpty) {
      throw Exception('Invalid request parameters.');
    }

    final deterministicDocId = '${studentId}_${event.id}';
    final String redemptionDocId = 'FREE-REG-${DateTime.now().millisecondsSinceEpoch}-${studentId.substring(0, min(4, studentId.length))}';
    final String secureToken = 'TKT-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}-${studentId.substring(0, min(4, studentId.length)).toUpperCase()}';

    return await _db.runTransaction((transaction) async {
      // 1. READ REWARD
      final rewardRef = _rewardsCollection.doc(rewardId);
      final rewardDoc = await transaction.get(rewardRef);
      if (!rewardDoc.exists) throw Exception('Reward does not exist.');
      final reward = RewardModel.fromSnapshot(rewardDoc);

      if (!reward.isEnabled) throw Exception('This reward is disabled.');
      if (reward.isExpired) throw Exception('This reward has expired.');
      if (reward.isOutOfStock) throw Exception('This reward is out of stock.');

      // 2. READ EVENT
      final eventRef = _db.collection('events').doc(event.id);
      final eventDoc = await transaction.get(eventRef);
      if (!eventDoc.exists) throw Exception('Event not found.');

      final eventData = eventDoc.data()!;
      final int capacity = (eventData['capacity'] ?? eventData['maxSeats'] ?? 100) as int;
      final int registeredCount = (eventData['registeredCount'] ?? 0) as int;
      final int availableSeats = (capacity - registeredCount).clamp(0, capacity);

      if (eventData['status'] == EventStatuses.cancelled) {
        throw Exception('Registration for this event is closed.');
      }

      DateTime deadline = DateTime.now().add(const Duration(days: 365));
      final rawDeadline = eventData['registrationDeadline'] ?? eventData['date'];
      if (rawDeadline is Timestamp) {
        deadline = rawDeadline.toDate();
      }
      if (DateTime.now().isAfter(deadline)) {
        throw Exception('Registration deadline has passed.');
      }

      if (availableSeats <= 0 || registeredCount >= capacity) {
        throw Exception('Sorry, this event is already full.');
      }

      // Check event branch & year eligibility
      final List<String> allowedYears =
          (eventData['allowedYears'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final List<String> allowedDepts =
          (eventData['allowedDepartments'] as List?)?.map((e) => e.toString()).toList() ?? [];

      if (!studentUser.isStaff) {
        if (!AcademicYears.matches(allowedYears, studentUser.year)) {
          throw Exception('Ineligible: This event is not open to your academic year.');
        }
        if (!AcademicDepartments.matches(allowedDepts, studentUser.department)) {
          throw Exception('Ineligible: This event is not open to your department.');
        }
      }

      // 3. READ REGISTRATION (Duplicate check)
      final regRef = _db.collection('registrations').doc(deterministicDocId);
      final regDoc = await transaction.get(regRef);
      if (regDoc.exists) {
        final status = regDoc.data()?['registrationStatus'] as String? ?? '';
        if (status == 'confirmed' || status == RegistrationStatuses.registered) {
          throw Exception('You are already registered for this event.');
        }
      }

      // 4. READ GAMIFICATION (Balance check)
      final gamificationRef = _gamificationCollection.doc(studentId);
      final gamificationDoc = await transaction.get(gamificationRef);
      final currentGamification = gamificationDoc.exists
          ? GamificationModel.fromSnapshot(gamificationDoc)
          : GamificationModel(studentId: studentId);

      if (currentGamification.coins < reward.coinCost) {
        throw Exception(
          'Insufficient coins: You have ${currentGamification.coins} coins, but ${reward.coinCost} are required.',
        );
      }

      // --- WRITE PHASE ---
      final now = DateTime.now();

      // Decrement student spendable coins
      final newSpendableCoins = currentGamification.coins - reward.coinCost;
      transaction.set(
        gamificationRef,
        currentGamification.copyWith(coins: newSpendableCoins, updatedAt: now).toMap(),
        SetOptions(merge: true),
      );

      // Decrement reward stock if finite
      if (!reward.isUnlimitedStock) {
        transaction.update(rewardRef, {
          'availableStock': max(0, reward.availableStock - 1),
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      // Increment event seats
      final newRegisteredCount = registeredCount + 1;
      final newAvailable = (capacity - newRegisteredCount).clamp(0, capacity);
      transaction.update(eventRef, {
        'registeredCount': newRegisteredCount,
        'availableSeats': newAvailable,
        'updatedAt': Timestamp.fromDate(now),
      });

      // Create genuine RegistrationModel with reward-covered status
      final createdRegistration = RegistrationModel(
        id: deterministicDocId,
        eventId: event.id,
        studentId: studentId,
        eventTitle: event.title,
        studentName: studentUser.name,
        studentEmail: studentUser.email,
        rollNumber: studentUser.rollNumber,
        phone: studentUser.whatsappNumber,
        department: studentUser.department,
        year: studentUser.year,
        eventDate: event.dateFormatted,
        venue: event.venue,
        amount: 0.0,
        paymentStatus: 'reward_covered',
        paymentReference: 'REWARD_$redemptionDocId',
        registrationStatus: 'confirmed',
        ticketToken: secureToken,
        registeredAt: now,
        whatsappConsent: studentUser.whatsappConsent,
      );
      transaction.set(regRef, createdRegistration.toMap());

      // Create Redemption record
      final redemption = RewardRedemptionModel(
        id: redemptionDocId,
        studentId: studentId,
        studentName: studentUser.name,
        studentRoll: studentUser.rollNumber,
        studentEmail: studentUser.email,
        rewardId: reward.id,
        rewardTitle: reward.title,
        rewardCategory: RewardCategories.freeEvent,
        coinCost: reward.coinCost,
        status: RedemptionStatuses.fulfilled,
        statusReason: 'Free Registration Pass applied to "${event.title}"',
        linkedEventId: event.id,
        linkedRegistrationId: deterministicDocId,
        idempotencyKey: redemptionDocId,
        redeemedAt: now,
        fulfilledAt: now,
      );
      transaction.set(_redemptionsCollection.doc(redemptionDocId), redemption.toMap());

      // Write debit ledger transaction
      final ledgerRef = _rewardHistoryCollection.doc('${redemptionDocId}_ledger');
      final ledgerEntry = CoinTransactionModel(
        id: '${redemptionDocId}_ledger',
        studentId: studentId,
        amount: -reward.coinCost,
        type: 'reward_redemption',
        title: 'Free Event Pass: ${event.title}',
        description: 'Redeemed Free Event Registration for ${event.title}',
        refId: event.id,
        idempotencyKey: redemptionDocId,
        createdAt: now,
      );
      transaction.set(ledgerRef, ledgerEntry.toMap());

      return (redemption: redemption, registration: createdRegistration);
    });
  }

  /// Admin action to update redemption status (approve, fulfil, reject, or refund)
  Future<void> adminUpdateRedemptionStatus({
    required String redemptionId,
    required String newStatus,
    required String adminUid,
    String reason = '',
  }) async {
    final redemptionRef = _redemptionsCollection.doc(redemptionId);

    await _db.runTransaction((transaction) async {
      final redemptionDoc = await transaction.get(redemptionRef);
      if (!redemptionDoc.exists) {
        throw Exception('Redemption document not found.');
      }

      final redemption = RewardRedemptionModel.fromSnapshot(redemptionDoc);
      final String oldStatus = redemption.status;

      if (oldStatus == newStatus) return; // No change

      final now = DateTime.now();

      // Check if transitioning to a rejected/refunded status requiring coin refund
      final bool requiresCoinRefund =
          (newStatus == RedemptionStatuses.rejected ||
              newStatus == RedemptionStatuses.cancelled ||
              newStatus == RedemptionStatuses.refunded) &&
          oldStatus != RedemptionStatuses.rejected &&
          oldStatus != RedemptionStatuses.cancelled &&
          oldStatus != RedemptionStatuses.refunded;

      if (requiresCoinRefund) {
        // REFUND COINS TO STUDENT
        final gamificationRef = _gamificationCollection.doc(redemption.studentId);
        final gamificationDoc = await transaction.get(gamificationRef);

        if (gamificationDoc.exists) {
          final currentGamification = GamificationModel.fromSnapshot(gamificationDoc);
          final refundedSpendable = currentGamification.coins + redemption.coinCost;
          transaction.set(
            gamificationRef,
            currentGamification.copyWith(
              coins: refundedSpendable,
              updatedAt: now,
            ).toMap(),
            SetOptions(merge: true),
          );

          // WRITE REFUND LEDGER ENTRY
          final refundLedgerRef = _rewardHistoryCollection.doc('${redemptionId}_refund');
          final refundEntry = CoinTransactionModel(
            id: '${redemptionId}_refund',
            studentId: redemption.studentId,
            amount: redemption.coinCost,
            type: 'redemption_refund',
            title: 'Refund: ${redemption.rewardTitle}',
            description: reason.isNotEmpty ? reason : 'Redemption refund by administrator',
            refId: redemption.rewardId,
            idempotencyKey: '${redemptionId}_refund',
            createdAt: now,
          );
          transaction.set(refundLedgerRef, refundEntry.toMap());
        }

        // RESTORE STOCK TO REWARD IF FINITE
        final rewardRef = _rewardsCollection.doc(redemption.rewardId);
        final rewardDoc = await transaction.get(rewardRef);
        if (rewardDoc.exists) {
          final reward = RewardModel.fromSnapshot(rewardDoc);
          if (!reward.isUnlimitedStock) {
            transaction.update(rewardRef, {
              'availableStock': reward.availableStock + 1,
              'updatedAt': Timestamp.fromDate(now),
            });
          }
        }
      }

      // UPDATE REDEMPTION DOCUMENT
      transaction.update(redemptionRef, {
        'status': newStatus,
        'statusReason': reason.isNotEmpty ? reason : redemption.statusReason,
        'fulfilledAt': newStatus == RedemptionStatuses.fulfilled ? Timestamp.fromDate(now) : null,
        'fulfilledByAdminUid': adminUid,
      });
    });
  }

  // ==========================================
  // 5. ADMIN MANUAL COIN ADJUSTMENT
  // ==========================================

  /// Admin manual coin balance adjustment with auditable reason
  Future<void> adminManualCoinAdjustment({
    required String studentId,
    required int coinDelta,
    required String reason,
    required String adminUid,
  }) async {
    if (studentId.isEmpty || coinDelta == 0 || reason.trim().isEmpty) {
      throw Exception('Student ID, non-zero coin delta, and reason are required.');
    }

    final String adjustmentId = 'ADJ-${DateTime.now().millisecondsSinceEpoch}-${studentId.substring(0, min(4, studentId.length))}';

    await _db.runTransaction((transaction) async {
      final gamificationRef = _gamificationCollection.doc(studentId);
      final gamificationDoc = await transaction.get(gamificationRef);

      final currentGamification = gamificationDoc.exists
          ? GamificationModel.fromSnapshot(gamificationDoc)
          : GamificationModel(studentId: studentId);

      final int newSpendable = max(0, currentGamification.coins + coinDelta);
      final int newLifetime = coinDelta > 0
          ? currentGamification.lifetimeCoins + coinDelta
          : currentGamification.lifetimeCoins;

      final now = DateTime.now();

      transaction.set(
        gamificationRef,
        currentGamification.copyWith(
          coins: newSpendable,
          lifetimeCoins: newLifetime,
          updatedAt: now,
        ).toMap(),
        SetOptions(merge: true),
      );

      // WRITE AUDITABLE LEDGER ENTRY
      final ledgerRef = _rewardHistoryCollection.doc(adjustmentId);
      final ledgerEntry = CoinTransactionModel(
        id: adjustmentId,
        studentId: studentId,
        amount: coinDelta,
        type: 'admin_adjustment',
        title: coinDelta > 0 ? 'Admin Coin Award' : 'Admin Coin Deduction',
        description: '$reason (by admin: $adminUid)',
        refId: adminUid,
        idempotencyKey: adjustmentId,
        createdAt: now,
      );
      transaction.set(ledgerRef, ledgerEntry.toMap());
    });
  }

  // ==========================================
  // 6. SECURE REFERRALS
  // ==========================================

  /// Registers a referral code when a new student joins
  Future<bool> registerReferralCode({
    required String newStudentUid,
    required String newStudentName,
    required String enteredReferralCode,
  }) async {
    final cleanCode = enteredReferralCode.trim().toUpperCase();
    if (cleanCode.isEmpty) return false;

    try {
      // Find referrer by matching referralCode
      final query = await _gamificationCollection
          .where('referralCode', isEqualTo: cleanCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return false;

      final referrerUid = query.docs.first.id;
      if (referrerUid == newStudentUid) {
        throw Exception('Self-referrals are not allowed.');
      }

      final referralId = '${referrerUid}_$newStudentUid';
      final referralRef = _referralsCollection.doc(referralId);
      final existingDoc = await referralRef.get();

      if (existingDoc.exists) {
        return false; // Already recorded
      }

      final record = ReferralRecordModel(
        id: referralId,
        referrerUid: referrerUid,
        referrerCode: cleanCode,
        referredUid: newStudentUid,
        referredName: newStudentName,
        status: 'pending',
      );

      await referralRef.set(record.toMap());

      // Link in student's profile
      await _gamificationCollection.doc(newStudentUid).set({
        'referredBy': referrerUid,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint('Error registering referral code: $e');
      rethrow;
    }
  }

  /// Streams referrals made by a student
  Stream<List<ReferralRecordModel>> streamStudentReferrals(String studentId) {
    if (studentId.isEmpty) return Stream.value([]);
    return _referralsCollection
        .where('referrerUid', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ReferralRecordModel.fromSnapshot(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Awards referral coins once upon the referred student's first verified attendance
  Future<void> processReferralQualificationOnFirstAttendance({
    required String referredStudentId,
    required String eventId,
    int referrerCoins = 50,
    int referredCoins = 25,
  }) async {
    try {
      final query = await _referralsCollection
          .where('referredUid', isEqualTo: referredStudentId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (query.docs.isEmpty) return;

      final referralDoc = query.docs.first;
      final referral = ReferralRecordModel.fromSnapshot(referralDoc);
      final now = DateTime.now();

      await _db.runTransaction((transaction) async {
        // 1. Award coins to referrer
        final referrerGameRef = _gamificationCollection.doc(referral.referrerUid);
        final referrerDoc = await transaction.get(referrerGameRef);
        if (referrerDoc.exists) {
          final refGame = GamificationModel.fromSnapshot(referrerDoc);
          transaction.set(
            referrerGameRef,
            refGame.copyWith(
              coins: refGame.coins + referrerCoins,
              lifetimeCoins: refGame.lifetimeCoins + referrerCoins,
              updatedAt: now,
            ).toMap(),
            SetOptions(merge: true),
          );

          // Referrer Ledger
          final refLedger = _rewardHistoryCollection.doc('REF_BONUS_${referral.id}_referrer');
          transaction.set(refLedger, {
            'id': 'REF_BONUS_${referral.id}_referrer',
            'studentId': referral.referrerUid,
            'amount': referrerCoins,
            'coinsAwarded': referrerCoins,
            'type': 'referral_bonus',
            'rewardType': 'referral_bonus',
            'title': 'Referral Reward (+$referrerCoins Coins)',
            'rewardReason': 'Referral qualified by ${referral.referredName}',
            'refId': referredStudentId,
            'idempotencyKey': 'REF_BONUS_${referral.id}_referrer',
            'createdAt': Timestamp.fromDate(now),
          });
        }

        // 2. Award welcome coins to referred student
        final studentGameRef = _gamificationCollection.doc(referredStudentId);
        final studentDoc = await transaction.get(studentGameRef);
        if (studentDoc.exists) {
          final studGame = GamificationModel.fromSnapshot(studentDoc);
          transaction.set(
            studentGameRef,
            studGame.copyWith(
              coins: studGame.coins + referredCoins,
              lifetimeCoins: studGame.lifetimeCoins + referredCoins,
              updatedAt: now,
            ).toMap(),
            SetOptions(merge: true),
          );

          // Student Ledger
          final studLedger = _rewardHistoryCollection.doc('REF_BONUS_${referral.id}_student');
          transaction.set(studLedger, {
            'id': 'REF_BONUS_${referral.id}_student',
            'studentId': referredStudentId,
            'amount': referredCoins,
            'coinsAwarded': referredCoins,
            'type': 'referral_bonus',
            'rewardType': 'referral_bonus',
            'title': 'Referral Welcome Bonus (+$referredCoins Coins)',
            'rewardReason': 'Joined using referral code',
            'refId': referral.referrerUid,
            'idempotencyKey': 'REF_BONUS_${referral.id}_student',
            'createdAt': Timestamp.fromDate(now),
          });
        }

        // 3. Mark referral record qualified
        transaction.update(referralDoc.reference, {
          'status': 'qualified',
          'coinsAwarded': referrerCoins,
          'qualifiedAt': Timestamp.fromDate(now),
        });
      });
    } catch (e) {
      debugPrint('Error processing referral qualification: $e');
    }
  }

  // ==========================================
  // 7. CONFIGURABLE EARNING RULES
  // ==========================================

  /// Streams configured earning rules
  Stream<List<GamificationRuleModel>> streamRules() {
    return _rulesCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => GamificationRuleModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Saves or updates an earning rule
  Future<void> saveRule(GamificationRuleModel rule) async {
    final ref = _rulesCollection.doc(rule.id);
    await ref.set(rule.toMap(), SetOptions(merge: true));
  }

  /// Gets attendance coin award (default 50 if unconfigured)
  Future<int> getAttendanceCoinAward() async {
    try {
      final doc = await _rulesCollection.doc('attendance').get();
      if (doc.exists) {
        return (doc.data()?['coinAmount'] ?? 50) as int;
      }
    } catch (_) {}
    return 50;
  }

  // ==========================================
  // 8. LEADERBOARD (AUTHORITATIVE LIFETIME RANKINGS)
  // ==========================================

  /// Streams top students by lifetimeCoins (descending) so spending does not drop rank!
  Stream<List<GamificationModel>> streamLeaderboard({int limit = 50}) {
    return _gamificationCollection
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => GamificationModel.fromSnapshot(doc))
              .toList();

          // Stable tie-breaking: lifetimeCoins desc, then totalEventsAttended desc
          list.sort((a, b) {
            final cmp = b.lifetimeCoins.compareTo(a.lifetimeCoins);
            if (cmp != 0) return cmp;
            return b.totalEventsAttended.compareTo(a.totalEventsAttended);
          });

          return list.take(limit).toList();
        });
  }
}
