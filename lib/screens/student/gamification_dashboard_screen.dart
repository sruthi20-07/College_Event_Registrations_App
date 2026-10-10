import 'package:flutter/material.dart';

import '../../models/gamification_model.dart';
import '../../services/auth_service.dart';
import '../../services/gamification_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_formatter.dart';

class GamificationDashboardScreen extends StatefulWidget {
  final String? studentId;

  const GamificationDashboardScreen({super.key, this.studentId});

  @override
  State<GamificationDashboardScreen> createState() =>
      _GamificationDashboardScreenState();
}

class _GamificationDashboardScreenState
    extends State<GamificationDashboardScreen> {
  final GamificationService _gamificationService = GamificationService();
  final AuthService _authService = AuthService();

  String get _activeStudentId =>
      widget.studentId ?? _authService.currentUid ?? '';

  String _getRankTitle(int coins) {
    if (coins >= 500) return 'Diamond Legend';
    if (coins >= 250) return 'Gold Champion';
    if (coins >= 100) return 'Silver Pioneer';
    if (coins >= 50) return 'Bronze Scholar';
    return 'Rookie Explorer';
  }

  IconData _getBadgeIcon(String badgeId) {
    switch (badgeId) {
      case 'first_step':
        return Icons.confirmation_number_outlined;
      case 'event_explorer':
        return Icons.explore_outlined;
      case 'campus_champion':
        return Icons.emoji_events_outlined;
      case 'consistency_star':
        return Icons.local_fire_department_outlined;
      case 'elite_participant':
        return Icons.diamond_outlined;
      default:
        return Icons.star_outline;
    }
  }

  void _showBadgeDetailsModal(
    BuildContext context,
    BadgeDefinition badge,
    bool isUnlocked,
    DateTime? unlockedAt,
    double progress,
    String progressText,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Badge Icon Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isUnlocked ? AppColors.coralLight : AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isUnlocked ? AppColors.coral : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getBadgeIcon(badge.id),
                    size: 38,
                    color: isUnlocked ? AppColors.coral : AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                badge.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),

              const SizedBox(height: 6),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? AppColors.mintLight
                      : AppColors.lavenderLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUnlocked
                        ? AppColors.mint
                        : AppColors.lavender,
                  ),
                ),
                child: Text(
                  isUnlocked
                      ? 'UNLOCKED'
                      : 'IN PROGRESS (${(progress * 100).toInt()}%)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked
                        ? AppColors.mintDark
                        : AppColors.lavenderDark,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                badge.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 20),

              // Progress or Unlocked Time Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Requirement',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        Text(
                          badge.isStreakBadge
                              ? '${badge.requiredStreakDays} consecutive days streak'
                              : '${badge.requiredEvents} distinct verified events',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textMain,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18, color: AppColors.border),
                    if (isUnlocked && unlockedAt != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Unlocked Date',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          Text(
                            DateFormatter.formatFullDateTime(unlockedAt),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.mintDark,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Current Progress',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                progressText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.coral,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.coral,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Achievements & Rewards'),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<GamificationModel?>(
        stream: _gamificationService.streamGamification(_activeStudentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.coral),
            );
          }

          final gamification = snapshot.data ??
              GamificationModel(
                studentId: _activeStudentId,
                coins: 0,
                totalEventsAttended: 0,
                currentStreak: 0,
                longestStreak: 0,
                unlockedBadges: {},
              );

          final int coins = gamification.coins;
          final int streak = gamification.currentStreak;
          final int longestStreak = gamification.longestStreak;
          final int totalAttended = gamification.totalEventsAttended;
          final int badgesCount = gamification.totalBadgesUnlocked;
          final nextBadge = gamification.nextBadge;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. COIN BALANCE HERO BANNER
                    _buildHeroCoinCard(coins),

                    const SizedBox(height: 16),

                    // 2. STREAK HERO CARD
                    _buildStreakCard(streak, longestStreak),

                    const SizedBox(height: 16),

                    // 3. STATS ROW
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickStatCard(
                            title: 'Attended',
                            value: '$totalAttended',
                            icon: Icons.how_to_reg_outlined,
                            bg: AppColors.mintLight,
                            color: AppColors.mintDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildQuickStatCard(
                            title: 'Badges',
                            value: '$badgesCount / 5',
                            icon: Icons.emoji_events_outlined,
                            bg: AppColors.lavenderLight,
                            color: AppColors.lavenderDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildQuickStatCard(
                            title: 'Best Streak',
                            value: '$longestStreak Days',
                            icon: Icons.local_fire_department_outlined,
                            bg: AppColors.coralLight,
                            color: AppColors.coralDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 4. NEXT ACHIEVEMENT PROGRESS
                    if (nextBadge != null) ...[
                      _buildNextMilestoneCard(gamification, nextBadge),
                      const SizedBox(height: 24),
                    ],

                    // 5. BADGES COLLECTION HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Badge Collection',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMain,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '$badgesCount / ${BadgeDefinition.allBadges.length} Unlocked',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 6. BADGES LIST
                    ...BadgeDefinition.allBadges.map((badge) {
                      final isUnlocked = gamification.isBadgeUnlocked(badge.id);
                      final unlockedAt = gamification.getBadgeUnlockedDate(
                        badge.id,
                      );
                      final progress = gamification.getBadgeProgress(badge);
                      final progressText = gamification.getBadgeProgressText(badge);

                      return _buildBadgeCard(
                        badge: badge,
                        isUnlocked: isUnlocked,
                        unlockedAt: unlockedAt,
                        progress: progress,
                        progressText: progressText,
                      );
                    }),

                    const SizedBox(height: 24),

                    // 7. REWARD HISTORY SECTION
                    const Text(
                      'Recent Rewards & Points History',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                        letterSpacing: -0.3,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _buildRewardHistoryStream(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroCoinCard(int coins) {
    final rankTitle = _getRankTitle(coins);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFEDE6),
            Color(0xFFEDE9FE),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium_outlined, size: 14, color: AppColors.coral),
                    const SizedBox(width: 4),
                    Text(
                      rankTitle,
                      style: const TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.coralLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.coral),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monetization_on, size: 14, color: AppColors.coralDark),
                    SizedBox(width: 4),
                    Text(
                      '+50 / Event',
                      style: TextStyle(
                        color: AppColors.coralDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'CAMPUS REWARD BALANCE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$coins',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppColors.coralDark,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Coins',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Earn verified coins automatically whenever you attend registered events.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(int streak, int longestStreak) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.coralLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.coral),
            ),
            child: const Icon(
              Icons.local_fire_department,
              size: 28,
              color: AppColors.coral,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$streak Day Attendance Streak',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  streak > 0
                      ? 'Keep attending daily events to multiply your streaks!'
                      : 'Attend back-to-back events to build your attendance streak.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color bg,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: bg,
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextMilestoneCard(
    GamificationModel gamification,
    BadgeDefinition badge,
  ) {
    final progress = gamification.getBadgeProgress(badge);
    final progressText = gamification.getBadgeProgressText(badge);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(_getBadgeIcon(badge.id), color: AppColors.coral, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Next Achievement',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.coralDark,
                    ),
                  ),
                ],
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.coralDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            badge.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badge.description,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.coral,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              progressText,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard({
    required BadgeDefinition badge,
    required bool isUnlocked,
    required DateTime? unlockedAt,
    required double progress,
    required String progressText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked ? AppColors.coral : AppColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onTap: () => _showBadgeDetailsModal(
            context,
            badge,
            isUnlocked,
            unlockedAt,
            progress,
            progressText,
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isUnlocked ? AppColors.coralLight : AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(
                color: isUnlocked ? AppColors.coral : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                _getBadgeIcon(badge.id),
                size: 24,
                color: isUnlocked ? AppColors.coral : AppColors.textSecondary,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  badge.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isUnlocked
                        ? AppColors.textMain
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              if (isUnlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.mintLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.mint),
                  ),
                  child: const Text(
                    'UNLOCKED',
                    style: TextStyle(
                      color: AppColors.mintDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 10,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                badge.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              if (isUnlocked && unlockedAt != null)
                Text(
                  'Earned on ${DateFormatter.formatDate(unlockedAt)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mintDark,
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.coral,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      progressText,
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
        ),
      ),
    );
  }

  Widget _buildRewardHistoryStream() {
    return StreamBuilder<List<RewardHistoryModel>>(
      stream: _gamificationService.streamRewardHistory(_activeStudentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.coral),
            ),
          );
        }

        final history = snapshot.data ?? [];

        if (history.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.history_toggle_off_outlined,
                  size: 40,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: 10),
                Text(
                  'No Points Earned Yet',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Attend college events and get your QR ticket scanned to earn points!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: history.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.coralLight,
                    radius: 18,
                    child: const Icon(
                      Icons.monetization_on,
                      size: 18,
                      color: AppColors.coral,
                    ),
                  ),
                  title: Text(
                    item.rewardReason.isNotEmpty
                        ? item.rewardReason
                        : item.eventTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textMain,
                    ),
                  ),
                  subtitle: Text(
                    DateFormatter.formatFullDateTime(item.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mintLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${item.coinsAwarded}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.mintDark,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
