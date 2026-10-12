import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_formatter.dart';

enum BadgeCategory { attendance, streak, explorer, elite }

/// Exactly five selectable streak symbols per requirements
class StreakSymbols {
  static const String fire = '🔥';
  static const String lightning = '⚡';
  static const String star = '🌟';
  static const String diamond = '💎';
  static const String blossom = '🌸';

  static const List<String> all = [fire, lightning, star, diamond, blossom];

  static const Map<String, String> labels = {
    fire: 'Fire',
    lightning: 'Lightning',
    star: 'Star',
    diamond: 'Diamond',
    blossom: 'Blossom',
  };

  static String getLabel(String symbol) => labels[symbol] ?? 'Fire';
  static String labelFor(String symbol) => getLabel(symbol);
  static bool isValid(String symbol) => all.contains(symbol);
}

class BadgeDefinition {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final int requiredEvents;
  final int requiredStreakDays;
  final bool isStreakBadge;
  final bool isDailyStreakBadge;
  final BadgeCategory category;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    this.requiredEvents = 0,
    this.requiredStreakDays = 0,
    this.isStreakBadge = false,
    this.isDailyStreakBadge = false,
    this.category = BadgeCategory.attendance,
  });

  static const List<BadgeDefinition> allBadges = [
    BadgeDefinition(
      id: 'first_step',
      name: 'First Step',
      emoji: '🎟️',
      description: 'Attend 1 college event with verified check-in.',
      requiredEvents: 1,
      category: BadgeCategory.attendance,
    ),
    BadgeDefinition(
      id: 'event_explorer',
      name: 'Event Explorer',
      emoji: '🌟',
      description: 'Attend 5 different college events.',
      requiredEvents: 5,
      category: BadgeCategory.explorer,
    ),
    BadgeDefinition(
      id: 'campus_champion',
      name: 'Campus Champion',
      emoji: '🏆',
      description: 'Attend 10 different college events.',
      requiredEvents: 10,
      category: BadgeCategory.attendance,
    ),
    BadgeDefinition(
      id: 'consistency_star',
      name: 'Consistency Star',
      emoji: '🔥',
      description: 'Attend events on 3 consecutive calendar days.',
      requiredStreakDays: 3,
      isStreakBadge: true,
      category: BadgeCategory.streak,
    ),
    BadgeDefinition(
      id: 'daily_streak_3',
      name: '3-Day Pioneer',
      emoji: '🔥',
      description: 'Open the app 3 consecutive days.',
      requiredStreakDays: 3,
      isDailyStreakBadge: true,
      category: BadgeCategory.streak,
    ),
    BadgeDefinition(
      id: 'daily_streak_7',
      name: '7-Day Spark',
      emoji: '⚡',
      description: 'Open the app 7 consecutive days.',
      requiredStreakDays: 7,
      isDailyStreakBadge: true,
      category: BadgeCategory.streak,
    ),
    BadgeDefinition(
      id: 'daily_streak_14',
      name: '14-Day Momentum',
      emoji: '🌟',
      description: 'Open the app 14 consecutive days.',
      requiredStreakDays: 14,
      isDailyStreakBadge: true,
      category: BadgeCategory.streak,
    ),
    BadgeDefinition(
      id: 'daily_streak_30',
      name: '30-Day Legend',
      emoji: '👑',
      description: 'Open the app 30 consecutive days.',
      requiredStreakDays: 30,
      isDailyStreakBadge: true,
      category: BadgeCategory.elite,
    ),
    BadgeDefinition(
      id: 'elite_participant',
      name: 'Elite Participant',
      emoji: '💎',
      description: 'Attend 20 different college events.',
      requiredEvents: 20,
      category: BadgeCategory.elite,
    ),
  ];

  static BadgeDefinition? findById(String id) {
    try {
      return allBadges.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }
}

class GamificationModel {
  final String studentId;
  final int coins; // spendable coin balance
  final int
  lifetimeCoins; // lifetime coins earned (used for rankings and achievements)
  final int totalEventsAttended;
  final int currentStreak;
  final int longestStreak;
  final String lastAttendedDate; // YYYY-MM-DD
  final List<String> distinctAttendedDates;
  final int dailyStreak; // app-open consecutive day streak
  final int longestDailyStreak; // best app-open streak
  final String lastDailyOpenDate; // YYYY-MM-DD
  final List<String> distinctDailyOpenDates;
  final String lastDailyPollDate; // YYYY-MM-DD of latest poll vote
  final String streakSymbol; // 🔥, ⚡, 🌟, 💎, 🌸
  final Map<String, DateTime> unlockedBadges; // badgeId -> unlockedAt
  final String referralCode;
  final String referredBy;
  final DateTime updatedAt;

  GamificationModel({
    required this.studentId,
    this.coins = 0,
    int? lifetimeCoins,
    this.totalEventsAttended = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastAttendedDate = '',
    List<String>? distinctAttendedDates,
    this.dailyStreak = 0,
    this.longestDailyStreak = 0,
    this.lastDailyOpenDate = '',
    List<String>? distinctDailyOpenDates,
    this.lastDailyPollDate = '',
    this.streakSymbol = StreakSymbols.fire,
    Map<String, DateTime>? unlockedBadges,
    String? referralCode,
    this.referredBy = '',
    DateTime? updatedAt,
  }) : lifetimeCoins =
           lifetimeCoins ??
           (coins > totalEventsAttended * 50
               ? coins
               : totalEventsAttended * 50),
       distinctAttendedDates = distinctAttendedDates ?? const [],
       distinctDailyOpenDates = distinctDailyOpenDates ?? const [],
       unlockedBadges = unlockedBadges ?? const {},
       referralCode =
           referralCode ??
           (studentId.isNotEmpty
               ? 'CAMPUS-${studentId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase().padRight(6, 'X').substring(0, 6)}'
               : ''),
       updatedAt = updatedAt ?? DateTime.now();

  bool isBadgeUnlocked(String badgeId) => unlockedBadges.containsKey(badgeId);

  DateTime? getBadgeUnlockedDate(String badgeId) => unlockedBadges[badgeId];

  int get totalBadgesUnlocked => unlockedBadges.length;

  bool isDailyOpenClaimedForDate(String dateKey) =>
      lastDailyOpenDate == dateKey || distinctDailyOpenDates.contains(dateKey);

  /// Determines next milestone badge to show on dashboard
  BadgeDefinition? get nextBadge {
    for (final badge in BadgeDefinition.allBadges) {
      if (!isBadgeUnlocked(badge.id)) {
        return badge;
      }
    }
    return null;
  }

  /// Calculates progress (0.0 to 1.0) towards a given badge
  double getBadgeProgress(BadgeDefinition badge) {
    if (isBadgeUnlocked(badge.id)) return 1.0;
    if (badge.isDailyStreakBadge) {
      if (badge.requiredStreakDays <= 0) return 1.0;
      final best = dailyStreak > longestDailyStreak
          ? dailyStreak
          : longestDailyStreak;
      return (best / badge.requiredStreakDays).clamp(0.0, 1.0);
    } else if (badge.isStreakBadge) {
      if (badge.requiredStreakDays <= 0) return 1.0;
      final best = currentStreak > longestStreak
          ? currentStreak
          : longestStreak;
      return (best / badge.requiredStreakDays).clamp(0.0, 1.0);
    } else {
      if (badge.requiredEvents <= 0) return 1.0;
      return (totalEventsAttended / badge.requiredEvents).clamp(0.0, 1.0);
    }
  }

  String getBadgeProgressText(BadgeDefinition badge) {
    if (isBadgeUnlocked(badge.id)) return 'Completed';
    if (badge.isDailyStreakBadge) {
      final best = dailyStreak > longestDailyStreak
          ? dailyStreak
          : longestDailyStreak;
      return '$best / ${badge.requiredStreakDays} days';
    } else if (badge.isStreakBadge) {
      final best = currentStreak > longestStreak
          ? currentStreak
          : longestStreak;
      return '$best / ${badge.requiredStreakDays} days';
    } else {
      return '$totalEventsAttended / ${badge.requiredEvents} events';
    }
  }

  factory GamificationModel.fromMap(
    Map<String, dynamic> map,
    String studentId,
  ) {
    final Map<String, DateTime> badges = {};
    if (map['unlockedBadges'] is Map) {
      final rawMap = map['unlockedBadges'] as Map;
      rawMap.forEach((key, val) {
        badges[key.toString()] = DateFormatter.parseDateTime(val);
      });
    }

    final List<String> dates = [];
    if (map['distinctAttendedDates'] is List) {
      for (final d in (map['distinctAttendedDates'] as List)) {
        dates.add(d.toString());
      }
    }

    final List<String> dailyDates = [];
    if (map['distinctDailyOpenDates'] is List) {
      for (final d in (map['distinctDailyOpenDates'] as List)) {
        dailyDates.add(d.toString());
      }
    }

    final int spendable = (map['coins'] ?? 0) as int;
    final int attended = (map['totalEventsAttended'] ?? 0) as int;
    final int fallbackLifetime = spendable > attended * 50
        ? spendable
        : attended * 50;
    final int lifetime = (map['lifetimeCoins'] ?? fallbackLifetime) as int;

    String refCode = map['referralCode'] as String? ?? '';
    if (refCode.isEmpty && studentId.isNotEmpty) {
      final clean = studentId
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toUpperCase();
      refCode = clean.length >= 6
          ? 'CAMPUS-${clean.substring(0, 6)}'
          : 'CAMPUS-${clean.padRight(6, 'X')}';
    }

    return GamificationModel(
      studentId: studentId,
      coins: spendable,
      lifetimeCoins: lifetime,
      totalEventsAttended: attended,
      currentStreak: (map['currentStreak'] ?? 0) as int,
      longestStreak: (map['longestStreak'] ?? 0) as int,
      lastAttendedDate: map['lastAttendedDate'] as String? ?? '',
      distinctAttendedDates: dates,
      dailyStreak: (map['dailyStreak'] ?? 0) as int,
      longestDailyStreak: (map['longestDailyStreak'] ?? 0) as int,
      lastDailyOpenDate: map['lastDailyOpenDate'] as String? ?? '',
      distinctDailyOpenDates: dailyDates,
      lastDailyPollDate: map['lastDailyPollDate'] as String? ?? '',
      streakSymbol:
          (map['streakSymbol'] is String &&
              StreakSymbols.isValid(map['streakSymbol'] as String))
          ? (map['streakSymbol'] as String)
          : StreakSymbols.fire,
      unlockedBadges: badges,
      referralCode: refCode,
      referredBy: map['referredBy'] as String? ?? '',
      updatedAt: DateFormatter.parseDateTime(map['updatedAt']),
    );
  }

  factory GamificationModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return GamificationModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> badgesMap = {};
    unlockedBadges.forEach((key, val) {
      badgesMap[key] = Timestamp.fromDate(val);
    });

    return {
      'studentId': studentId,
      'coins': coins,
      'lifetimeCoins': lifetimeCoins,
      'totalEventsAttended': totalEventsAttended,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastAttendedDate': lastAttendedDate,
      'distinctAttendedDates': distinctAttendedDates,
      'dailyStreak': dailyStreak,
      'longestDailyStreak': longestDailyStreak,
      'lastDailyOpenDate': lastDailyOpenDate,
      'distinctDailyOpenDates': distinctDailyOpenDates,
      'lastDailyPollDate': lastDailyPollDate,
      'streakSymbol': streakSymbol,
      'unlockedBadges': badgesMap,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  GamificationModel copyWith({
    String? studentId,
    int? coins,
    int? lifetimeCoins,
    int? totalEventsAttended,
    int? currentStreak,
    int? longestStreak,
    String? lastAttendedDate,
    List<String>? distinctAttendedDates,
    int? dailyStreak,
    int? longestDailyStreak,
    String? lastDailyOpenDate,
    List<String>? distinctDailyOpenDates,
    String? lastDailyPollDate,
    String? streakSymbol,
    Map<String, DateTime>? unlockedBadges,
    String? referralCode,
    String? referredBy,
    DateTime? updatedAt,
  }) {
    return GamificationModel(
      studentId: studentId ?? this.studentId,
      coins: coins ?? this.coins,
      lifetimeCoins: lifetimeCoins ?? this.lifetimeCoins,
      totalEventsAttended: totalEventsAttended ?? this.totalEventsAttended,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastAttendedDate: lastAttendedDate ?? this.lastAttendedDate,
      distinctAttendedDates:
          distinctAttendedDates ?? this.distinctAttendedDates,
      dailyStreak: dailyStreak ?? this.dailyStreak,
      longestDailyStreak: longestDailyStreak ?? this.longestDailyStreak,
      lastDailyOpenDate: lastDailyOpenDate ?? this.lastDailyOpenDate,
      distinctDailyOpenDates:
          distinctDailyOpenDates ?? this.distinctDailyOpenDates,
      lastDailyPollDate: lastDailyPollDate ?? this.lastDailyPollDate,
      streakSymbol: streakSymbol ?? this.streakSymbol,
      unlockedBadges: unlockedBadges ?? this.unlockedBadges,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RewardHistoryModel {
  final String id; // deterministic '${studentId}_${eventId}'
  final String studentId;
  final String eventId;
  final String eventTitle;
  final int coinsAwarded;
  final String rewardType;
  final String rewardReason;
  final DateTime createdAt;

  RewardHistoryModel({
    required this.id,
    required this.studentId,
    required this.eventId,
    required this.eventTitle,
    this.coinsAwarded = 50,
    this.rewardType = 'attendance_verified',
    required this.rewardReason,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RewardHistoryModel.fromMap(Map<String, dynamic> map, String docId) {
    return RewardHistoryModel(
      id: docId,
      studentId: map['studentId'] as String? ?? '',
      eventId: map['eventId'] as String? ?? '',
      eventTitle: map['eventTitle'] as String? ?? '',
      coinsAwarded: (map['coinsAwarded'] ?? 50) as int,
      rewardType: map['rewardType'] as String? ?? 'attendance_verified',
      rewardReason: map['rewardReason'] as String? ?? 'Verified Attendance',
      createdAt: DateFormatter.parseDateTime(map['createdAt']),
    );
  }

  factory RewardHistoryModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return RewardHistoryModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'eventId': eventId,
      'eventTitle': eventTitle,
      'coinsAwarded': coinsAwarded,
      'rewardType': rewardType,
      'rewardReason': rewardReason,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
