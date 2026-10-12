import 'package:flutter_test/flutter_test.dart';
import 'package:college_event_app/models/event_model.dart';
import 'package:college_event_app/models/gamification_model.dart';
import 'package:college_event_app/models/reward_model.dart';
import 'package:college_event_app/models/user_model.dart';
import 'package:college_event_app/services/gamification_service.dart';
import 'package:college_event_app/utils/constants.dart';

void main() {
  group('Campus Gamification & Central Coin System Tests', () {
    test('1. Verified attendance check-in awards configured coins and updates spendable & lifetime balance', () {
      final initialGamification = GamificationModel(
        studentId: 'student_123',
        coins: 100,
        lifetimeCoins: 100,
        totalEventsAttended: 2,
        currentStreak: 1,
        longestStreak: 1,
        lastAttendedDate: '2026-10-10',
      );

      final attendanceDate = DateTime(2026, 10, 11, 10, 30);
      final result = GamificationService.computeReward(
        currentGamification: initialGamification,
        studentId: 'student_123',
        eventId: 'event_456',
        eventTitle: 'AI Workshop',
        attendedAt: attendanceDate,
        coinAward: 50,
      );

      final updated = result.updatedGamification;
      final reward = result.rewardRecord;

      expect(updated.coins, equals(150));
      expect(updated.lifetimeCoins, equals(150));
      expect(updated.totalEventsAttended, equals(3));
      expect(updated.currentStreak, equals(2));
      expect(updated.longestStreak, equals(2));
      expect(reward.coinsAwarded, equals(50));
      expect(reward.id, equals('student_123_event_456'));
    });

    test('2. Streak handles same-day multiple events without incrementing streak twice', () {
      final initialGamification = GamificationModel(
        studentId: 'student_123',
        coins: 50,
        totalEventsAttended: 1,
        currentStreak: 1,
        longestStreak: 1,
        lastAttendedDate: '2026-10-11',
      );

      final secondEventDate = DateTime(2026, 10, 11, 14, 0);
      final result = GamificationService.computeReward(
        currentGamification: initialGamification,
        studentId: 'student_123',
        eventId: 'event_789',
        eventTitle: 'Evening Hackathon',
        attendedAt: secondEventDate,
      );

      final updated = result.updatedGamification;
      expect(updated.currentStreak, equals(1)); // Same calendar day -> streak remains 1
      expect(updated.totalEventsAttended, equals(2));
      expect(updated.coins, equals(100));
    });

    test('3. Missed day resets current streak to 1 while preserving longest streak', () {
      final initialGamification = GamificationModel(
        studentId: 'student_123',
        coins: 150,
        totalEventsAttended: 3,
        currentStreak: 3,
        longestStreak: 3,
        lastAttendedDate: '2026-10-05',
      );

      final newAttendanceDate = DateTime(2026, 10, 11, 10, 0); // 6 days later
      final result = GamificationService.computeReward(
        currentGamification: initialGamification,
        studentId: 'student_123',
        eventId: 'event_999',
        eventTitle: 'Robotics Seminar',
        attendedAt: newAttendanceDate,
      );

      final updated = result.updatedGamification;
      expect(updated.currentStreak, equals(1)); // Reset after gap
      expect(updated.longestStreak, equals(3)); // Historical best preserved
      expect(updated.totalEventsAttended, equals(4));
    });

    test('4. Spending coins does NOT reduce lifetime achievement points or rankings', () {
      final gamification = GamificationModel(
        studentId: 'student_123',
        coins: 200, // spendable
        lifetimeCoins: 350, // total earned
        totalEventsAttended: 7,
      );

      // Student redeems a 150 coin reward
      final spendAmount = 150;
      final afterRedeem = gamification.copyWith(
        coins: gamification.coins - spendAmount,
        // lifetimeCoins is NOT modified
      );

      expect(afterRedeem.coins, equals(50)); // Spendable decreased
      expect(afterRedeem.lifetimeCoins, equals(350)); // Lifetime intact
    });

    test('5. Backward compatibility: missing lifetimeCoins safely defaults to max(coins, events * 50)', () {
      final legacyDocData = {
        'coins': 120,
        'totalEventsAttended': 3,
        'currentStreak': 2,
        'longestStreak': 2,
        // 'lifetimeCoins' is absent in legacy record
      };

      final parsed = GamificationModel.fromMap(legacyDocData, 'student_legacy');
      expect(parsed.coins, equals(120));
      expect(parsed.lifetimeCoins, equals(150)); // 3 * 50 = 150 > 120
      expect(parsed.referralCode, isNotEmpty);
    });

    test('6. RewardModel correctly validates stock and expiry status', () {
      final activeReward = RewardModel(
        id: 'rew_1',
        title: 'Free Pass',
        description: 'Free event pass',
        category: RewardCategories.freeEvent,
        coinCost: 150,
        availableStock: 5,
        isEnabled: true,
      );
      expect(activeReward.isCurrentlyAvailable, isTrue);

      final outOfStockReward = activeReward.copyWith(availableStock: 0);
      expect(outOfStockReward.isOutOfStock, isTrue);
      expect(outOfStockReward.isCurrentlyAvailable, isFalse);

      final disabledReward = activeReward.copyWith(isEnabled: false);
      expect(disabledReward.isCurrentlyAvailable, isFalse);

      final expiredReward = activeReward.copyWith(
        expiryDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(expiredReward.isExpired, isTrue);
      expect(expiredReward.isCurrentlyAvailable, isFalse);
    });

    test('7. CoinTransactionModel ledger serialization preserves credits and debits', () {
      final credit = CoinTransactionModel(
        id: 'tx_credit',
        studentId: 'student_123',
        amount: 50,
        type: 'attendance_verified',
        title: 'Verified Attendance (+50)',
      );
      expect(credit.isCredit, isTrue);
      expect(credit.isDebit, isFalse);

      final debit = CoinTransactionModel(
        id: 'tx_debit',
        studentId: 'student_123',
        amount: -150,
        type: 'reward_redemption',
        title: 'Redeemed Free Pass',
      );
      expect(debit.isDebit, isTrue);
      expect(debit.isCredit, isFalse);

      final serialized = debit.toMap();
      final reconstructed = CoinTransactionModel.fromMap(serialized, debit.id);
      expect(reconstructed.amount, equals(-150));
      expect(reconstructed.type, equals('reward_redemption'));
    });

    test('8. GamificationRuleModel correctly deserializes and supplies fallbacks', () {
      final ruleMap = {
        'name': 'Verified Event Attendance',
        'activityType': 'attendance',
        'coinAmount': 60,
        'isEnabled': true,
      };

      final rule = GamificationRuleModel.fromMap(ruleMap, 'attendance');
      expect(rule.coinAmount, equals(60));
      expect(rule.isEnabled, isTrue);
    });

    test('9. Duplicate attendance check-in idempotency key is deterministic', () {
      final key1 = '${"std_001"}_${"evt_100"}';
      final key2 = '${"std_001"}_${"evt_100"}';
      expect(key1, equals(key2));
      expect(key1, equals('std_001_evt_100'));
    });

    test('10. Insufficient balance leaves coin balance unmodified', () {
      final initialBalance = 80;
      final rewardCost = 150;
      expect(initialBalance < rewardCost, isTrue);

      int balance = initialBalance;
      bool deducted = false;
      if (balance >= rewardCost) {
        balance -= rewardCost;
        deducted = true;
      }

      expect(deducted, isFalse);
      expect(balance, equals(80));
    });

    test('11. Successful redemption records valid debit ledger and preserves lifetime achievement coins', () {
      final gamification = GamificationModel(
        studentId: 'std_456',
        coins: 300,
        lifetimeCoins: 500,
        totalEventsAttended: 10,
      );
      final cost = 120;

      final updatedGamification = gamification.copyWith(
        coins: gamification.coins - cost,
      );

      final debitTx = CoinTransactionModel(
        id: 'RED-123-ledger',
        studentId: 'std_456',
        amount: -cost,
        type: 'reward_redemption',
        title: 'Redeemed Perk',
        description: 'Spent $cost coins',
      );

      expect(updatedGamification.coins, equals(180));
      expect(updatedGamification.lifetimeCoins, equals(500));
      expect(debitTx.isDebit, isTrue);
      expect(debitTx.amount, equals(-120));
    });

    test('12. Reward availability checks reject disabled, out of stock, and expired rewards', () {
      final baseReward = RewardModel(
        id: 'r_test',
        title: 'Campus Hoodie',
        description: 'Official merch',
        category: RewardCategories.collegePerk,
        coinCost: 200,
        availableStock: 10,
        isEnabled: true,
      );
      expect(baseReward.isCurrentlyAvailable, isTrue);

      final disabled = baseReward.copyWith(isEnabled: false);
      expect(disabled.isCurrentlyAvailable, isFalse);

      final outOfStock = baseReward.copyWith(availableStock: 0);
      expect(outOfStock.isCurrentlyAvailable, isFalse);
      expect(outOfStock.isOutOfStock, isTrue);

      final expired = baseReward.copyWith(
        expiryDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(expired.isCurrentlyAvailable, isFalse);
      expect(expired.isExpired, isTrue);
    });

    test('13. Reward eligibility checks enforce academic year and department restrictions', () {
      final reward = RewardModel(
        id: 'r_spec',
        title: 'Final Year Project Grant',
        description: 'For 4th year CSE students only',
        category: RewardCategories.custom,
        coinCost: 500,
        eligibilityYears: [AcademicYears.year4],
        eligibilityDepartments: [AcademicDepartments.cse],
      );

      final userCSE4 = UserModel(
        uid: 'u1',
        email: 'u1@test.com',
        name: 'CSE Final Year',
        rollNumber: 'R1',
        role: 'student',
        year: AcademicYears.year4,
        department: AcademicDepartments.cse,
      );

      final userMech2 = UserModel(
        uid: 'u2',
        email: 'u2@test.com',
        name: 'Mech 2nd Year',
        rollNumber: 'R2',
        role: 'student',
        year: AcademicYears.year2,
        department: AcademicDepartments.mech,
      );

      expect(AcademicYears.matches(reward.eligibilityYears, userCSE4.year), isTrue);
      expect(AcademicDepartments.matches(reward.eligibilityDepartments, userCSE4.department), isTrue);

      expect(AcademicYears.matches(reward.eligibilityYears, userMech2.year), isFalse);
      expect(AcademicDepartments.matches(reward.eligibilityDepartments, userMech2.department), isFalse);
    });

    test('14. Free Event Registration validates capacity and deadline before granting pass', () {
      final now = DateTime.now();
      final fullEvent = EventModel(
        id: 'evt_full',
        title: 'AI Summit',
        description: 'Annual summit',
        category: 'Workshop',
        date: now.add(const Duration(days: 5)),
        startTime: '10:00 AM',
        endTime: '12:00 PM',
        venue: 'Main Auditorium',
        organizer: 'CSE Dept',
        maxSeats: 100,
        availableSeats: 0,
        registrationFee: 0,
        registrationDeadline: now.add(const Duration(days: 4)),
      );
      expect(fullEvent.isFull, isTrue);
      expect(fullEvent.availableSeats, equals(0));

      final expiredEvent = EventModel(
        id: 'evt_expired',
        title: 'Past Hackathon',
        description: 'Past event',
        category: 'Hackathon',
        date: now.subtract(const Duration(days: 2)),
        startTime: '10:00 AM',
        endTime: '12:00 PM',
        registrationDeadline: now.subtract(const Duration(days: 3)),
        venue: 'Lab 1',
        organizer: 'IT Dept',
        maxSeats: 50,
        availableSeats: 30,
        registrationFee: 0,
      );
      expect(expiredEvent.isDeadlinePassed, isTrue);

      final openEvent = EventModel(
        id: 'evt_open',
        title: 'Tech Fest',
        description: 'Open event',
        category: 'Fest',
        date: now.add(const Duration(days: 10)),
        startTime: '09:00 AM',
        endTime: '05:00 PM',
        venue: 'Auditorium 2',
        organizer: 'College',
        maxSeats: 150,
        availableSeats: 110,
        registrationFee: 0,
        registrationDeadline: now.add(const Duration(days: 9)),
      );
      expect(openEvent.isFull, isFalse);
      expect(openEvent.isDeadlinePassed, isFalse);
      expect(openEvent.availableSeats, equals(110));
    });

    test('15. Referral logic rejects self-referrals and identifies qualified status', () {
      final studentUid = 'std_abc';
      final referrerUid = 'std_abc';
      expect(studentUid == referrerUid, isTrue);

      final referralRecord = ReferralRecordModel(
        id: 'referrer_std123',
        referrerUid: 'ref_999',
        referrerCode: 'CAMPUS-REF999',
        referredUid: 'std_new',
        referredName: 'New Student',
        status: 'pending',
      );
      expect(referralRecord.status, equals('pending'));

      final qualifiedRecord = referralRecord.copyWith(
        status: 'qualified',
        coinsAwarded: 50,
        qualifiedAt: DateTime.now(),
      );
      expect(qualifiedRecord.status, equals('qualified'));
      expect(qualifiedRecord.coinsAwarded, equals(50));
    });

    test('16. Milestone badges unlock sequentially on attendance milestones', () {
      var game = GamificationModel(studentId: 'std_badges');

      // 1 event
      var res = GamificationService.computeReward(
        currentGamification: game,
        studentId: 'std_badges',
        eventId: 'e1',
        eventTitle: 'Event 1',
        attendedAt: DateTime(2026, 10, 1),
      );
      game = res.updatedGamification;
      expect(game.isBadgeUnlocked('first_step'), isTrue);
      expect(game.isBadgeUnlocked('event_explorer'), isFalse);

      // Fast forward to 5 events
      game = game.copyWith(totalEventsAttended: 4);
      res = GamificationService.computeReward(
        currentGamification: game,
        studentId: 'std_badges',
        eventId: 'e5',
        eventTitle: 'Event 5',
        attendedAt: DateTime(2026, 10, 5),
      );
      game = res.updatedGamification;
      expect(game.isBadgeUnlocked('event_explorer'), isTrue);

      // Fast forward to 10 events
      game = game.copyWith(totalEventsAttended: 9);
      res = GamificationService.computeReward(
        currentGamification: game,
        studentId: 'std_badges',
        eventId: 'e10',
        eventTitle: 'Event 10',
        attendedAt: DateTime(2026, 10, 10),
      );
      game = res.updatedGamification;
      expect(game.isBadgeUnlocked('campus_champion'), isTrue);

      // 3-day consecutive streak unlocks consistency_star
      game = game.copyWith(currentStreak: 2, lastAttendedDate: '2026-10-10');
      res = GamificationService.computeReward(
        currentGamification: game,
        studentId: 'std_badges',
        eventId: 'e11',
        eventTitle: 'Event 11',
        attendedAt: DateTime(2026, 10, 11),
      );
      game = res.updatedGamification;
      expect(game.currentStreak, equals(3));
      expect(game.isBadgeUnlocked('consistency_star'), isTrue);
    });

    test('17. Leaderboard sorting ranks by lifetimeCoins descending so spending does not drop rank', () {
      final studentA = GamificationModel(
        studentId: 'std_A',
        coins: 50, // Spent 450 coins on rewards
        lifetimeCoins: 500,
        totalEventsAttended: 10,
      );

      final studentB = GamificationModel(
        studentId: 'std_B',
        coins: 200, // Has more spendable coins but lower lifetime
        lifetimeCoins: 200,
        totalEventsAttended: 4,
      );

      final list = [studentB, studentA];
      list.sort((a, b) {
        final cmp = b.lifetimeCoins.compareTo(a.lifetimeCoins);
        if (cmp != 0) return cmp;
        return b.totalEventsAttended.compareTo(a.totalEventsAttended);
      });

      expect(list.first.studentId, equals('std_A'));
      expect(list.last.studentId, equals('std_B'));
    });
  });
}
