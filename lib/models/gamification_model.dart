import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_formatter.dart';

enum BadgeCategory { attendance, streak, explorer, elite }

class BadgeDefinition {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final int requiredEvents;
  final int requiredStreakDays;
  final bool isStreakBadge;
  final BadgeCategory category;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    this.requiredEvents = 0,
    this.requiredStreakDays = 0,
    this.isStreakBadge = false,
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
  final int coins;
  final int totalEventsAttended;
  final int currentStreak;
  final int longestStreak;
  final String lastAttendedDate; // YYYY-MM-DD
  final List<String> distinctAttendedDates;
  final Map<String, DateTime> unlockedBadges; // badgeId -> unlockedAt
  final DateTime updatedAt;

  GamificationModel({
    required this.studentId,
    this.coins = 0,
    this.totalEventsAttended = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastAttendedDate = '',
    List<String>? distinctAttendedDates,
    Map<String, DateTime>? unlockedBadges,
    DateTime? updatedAt,
  }) : distinctAttendedDates = distinctAttendedDates ?? const [],
       unlockedBadges = unlockedBadges ?? const {},
       updatedAt = updatedAt ?? DateTime.now();

  bool isBadgeUnlocked(String badgeId) => unlockedBadges.containsKey(badgeId);

  DateTime? getBadgeUnlockedDate(String badgeId) => unlockedBadges[badgeId];

  int get totalBadgesUnlocked => unlockedBadges.length;

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
    if (badge.isStreakBadge) {
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
    if (badge.isStreakBadge) {
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

    return GamificationModel(
      studentId: studentId,
      coins: (map['coins'] ?? 0) as int,
      totalEventsAttended: (map['totalEventsAttended'] ?? 0) as int,
      currentStreak: (map['currentStreak'] ?? 0) as int,
      longestStreak: (map['longestStreak'] ?? 0) as int,
      lastAttendedDate: map['lastAttendedDate'] as String? ?? '',
      distinctAttendedDates: dates,
      unlockedBadges: badges,
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
      'totalEventsAttended': totalEventsAttended,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastAttendedDate': lastAttendedDate,
      'distinctAttendedDates': distinctAttendedDates,
      'unlockedBadges': badgesMap,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
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
