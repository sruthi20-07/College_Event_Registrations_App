import 'package:flutter_test/flutter_test.dart';
import 'package:college_event_app/models/gamification_model.dart';
import 'package:college_event_app/models/feedback_model.dart';
import 'package:college_event_app/services/gamification_service.dart';

void main() {
  group('Gamification Models and Badge Thresholds', () {
    test('Badge definitions are correctly configured', () {
      expect(BadgeDefinition.allBadges.length, 5);

      final firstStep = BadgeDefinition.findById('first_step');
      expect(firstStep, isNotNull);
      expect(firstStep!.requiredEvents, 1);
      expect(firstStep.emoji, '🎟️');

      final explorer = BadgeDefinition.findById('event_explorer');
      expect(explorer, isNotNull);
      expect(explorer!.requiredEvents, 5);
      expect(explorer.emoji, '🌟');

      final champion = BadgeDefinition.findById('campus_champion');
      expect(champion, isNotNull);
      expect(champion!.requiredEvents, 10);
      expect(champion.emoji, '🏆');

      final consistency = BadgeDefinition.findById('consistency_star');
      expect(consistency, isNotNull);
      expect(consistency!.isStreakBadge, isTrue);
      expect(consistency.requiredStreakDays, 3);
      expect(consistency.emoji, '🔥');

      final elite = BadgeDefinition.findById('elite_participant');
      expect(elite, isNotNull);
      expect(elite!.requiredEvents, 20);
      expect(elite.emoji, '💎');
    });

    test('GamificationModel badge progress calculations', () {
      final model = GamificationModel(
        studentId: 'student_123',
        coins: 150,
        totalEventsAttended: 3,
        currentStreak: 2,
        longestStreak: 2,
        unlockedBadges: {'first_step': DateTime(2026, 10, 1)},
      );

      final firstStep = BadgeDefinition.findById('first_step')!;
      final explorer = BadgeDefinition.findById('event_explorer')!;
      final consistency = BadgeDefinition.findById('consistency_star')!;

      // First step is unlocked
      expect(model.isBadgeUnlocked('first_step'), isTrue);
      expect(model.getBadgeProgress(firstStep), 1.0);

      // Event explorer: 3 / 5 = 0.6
      expect(model.isBadgeUnlocked('event_explorer'), isFalse);
      expect(model.getBadgeProgress(explorer), closeTo(0.6, 0.01));
      expect(model.getBadgeProgressText(explorer), '3 / 5 events');

      // Consistency star: 2 / 3 = 0.666
      expect(model.isBadgeUnlocked('consistency_star'), isFalse);
      expect(model.getBadgeProgress(consistency), closeTo(0.666, 0.01));
      expect(model.getBadgeProgressText(consistency), '2 / 3 days');
    });
  });

  group('Gamification Calendar Date and Streak Calculation', () {
    test('Date key conversion format YYYY-MM-DD', () {
      final date = DateTime(2026, 10, 8, 14, 30);
      final key = GamificationService.getCalendarDateKey(date);
      expect(key, '2026-10-08');
    });

    test('Consecutive day difference', () {
      expect(GamificationService.daysDifference('2026-10-08', '2026-10-09'), 1);
      expect(GamificationService.daysDifference('2026-10-08', '2026-10-08'), 0);
      expect(GamificationService.daysDifference('2026-10-08', '2026-10-10'), 2);
    });
  });

  group('Feedback Model Serialization and Bounds', () {
    test('FeedbackModel maps correctly and clamps rating between 1 and 5', () {
      final feedback = FeedbackModel(
        id: 'fb_100',
        studentUid: 'student_123',
        studentName: 'Alice',
        studentEmail: 'alice@example.com',
        rating: 5,
        feedback: 'Super smooth check-in!',
        category: 'General',
        createdAt: DateTime(2026, 10, 10, 10, 0),
      );

      final map = feedback.toMap();
      expect(map['rating'], 5);
      expect(map['studentUid'], 'student_123');
      expect(map['feedback'], 'Super smooth check-in!');

      final parsed = FeedbackModel.fromMap({
        'studentUid': 'student_456',
        'studentName': 'Bob',
        'studentEmail': 'bob@example.com',
        'rating': 10, // Exceeds 5
        'feedback': 'Needs dark mode',
        'category': 'Suggestions',
      }, 'fb_101');

      expect(parsed.rating, 5); // Clamped to 5
      expect(parsed.studentName, 'Bob');
    });
  });
}
