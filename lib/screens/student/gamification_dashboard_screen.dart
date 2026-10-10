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
    if (coins >= 500) return '💎 Diamond Legend';
    if (coins >= 250) return '🏆 Gold Champion';
    if (coins >= 100) return '🌟 Silver Pioneer';
    if (coins >= 50) return '🥉 Bronze Scholar';
    return '🌱 Rookie Explorer';
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
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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

              // Badge Emoji Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isUnlocked ? AppColors.peachLight : AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isUnlocked
                        ? AppColors.pastelPeach
                        : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    badge.emoji,
                    style: TextStyle(
                      fontSize: 36,
                      color: isUnlocked ? null : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                badge.name,
                style: TextStyle(
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
                      ? AppColors.sageLight
                      : AppColors.lavenderLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUnlocked
                        ? AppColors.primarySage
                        : AppColors.pastelLavender,
                  ),
                ),
                child: Text(
                  isUnlocked
                      ? '✓ UNLOCKED'
                      : 'IN PROGRESS (${(progress * 100).toInt()}%)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked
                        ? AppColors.sageDark
                        : AppColors.lavenderDark,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                badge.description,
                textAlign: TextAlign.center,
                style: TextStyle(
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
                        Text(
                          'Requirement',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        Text(
                          badge.isStreakBadge
                              ? '${badge.requiredStreakDays} consecutive days streak'
                              : '${badge.requiredEvents} distinct verified events',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textMain,
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 18, color: AppColors.border),
                    if (isUnlocked && unlockedAt != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Unlocked Date',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          Text(
                            DateFormatter.formatFullDateTime(unlockedAt),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.sageDark,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Current Progress',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                progressText,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.sageDark,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primarySage,
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
                    backgroundColor: AppColors.primarySage,
                    foregroundColor: AppColors.sageDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
    if (_activeStudentId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gamification & Rewards')),
        body: Center(
          child: Text(
            'Please log in to view achievements.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Achievements & Rewards'), elevation: 0),
      body: StreamBuilder<GamificationModel?>(
        stream: _gamificationService.streamGamification(_activeStudentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.sageDark),
            );
          }

          final gamification =
              snapshot.data ?? GamificationModel(studentId: _activeStudentId);

          final int coins = gamification.coins;
          final int streak = gamification.currentStreak;
          final int longestStreak = gamification.longestStreak;
          final int totalAttended = gamification.totalEventsAttended;
          final int badgesCount = gamification.totalBadgesUnlocked;
          final nextBadge = gamification.nextBadge;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                        bg: AppColors.sageLight,
                        color: AppColors.sageDark,
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
                        bg: AppColors.peachLight,
                        color: AppColors.peachDark,
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
                    Text(
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
                      style: TextStyle(
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
                Text(
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
        gradient: LinearGradient(
          colors: [
            AppColors.pastelSage,
            AppColors.pastelLavender,
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
                  color: AppColors.cardWhite.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primarySage),
                ),
                child: Text(
                  rankTitle,
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.peachLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.pastelPeach),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      '+50 / Event',
                      style: TextStyle(
                        color: AppColors.peachDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Text(
                '$coins',
                style: TextStyle(
                  color: AppColors.textMain,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Campus Coins',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Earn 50 coins automatically each time your attendance is verified at a college event!',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(int streak, int longestStreak) {
    final bool isStreakActive = streak > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isStreakActive ? AppColors.pastelPeach : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isStreakActive
                  ? AppColors.peachLight
                  : AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Text(
              '🔥',
              style: TextStyle(
                fontSize: 26,
                color: isStreakActive ? null : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$streak Day Streak',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isStreakActive
                            ? AppColors.peachDark
                            : AppColors.textMain,
                      ),
                    ),
                    if (isStreakActive) ...[
                      const SizedBox(width: 6),
                      const Text('⚡', style: TextStyle(fontSize: 14)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isStreakActive
                      ? 'Attend events on consecutive days to maintain your active streak!'
                      : 'Attend an event today to start a new attendance streak!',
                  style: TextStyle(
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: bg,
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
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
        border: Border.all(
          color: AppColors.pastelSage,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(badge.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'Next Achievement',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.sageDark,
                    ),
                  ),
                ],
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.sageDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            badge.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badge.description,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.sageLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primarySage,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              progressText,
              style: TextStyle(
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
          color: isUnlocked
              ? AppColors.pastelPeach
              : AppColors.border,
        ),
      ),
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
            color: isUnlocked ? AppColors.peachLight : AppColors.background,
            shape: BoxShape.circle,
            border: Border.all(
              color: isUnlocked
                  ? AppColors.pastelPeach
                  : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              badge.emoji,
              style: TextStyle(
                fontSize: 22,
                color: isUnlocked ? null : AppColors.textSecondary,
              ),
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
                  color: AppColors.sageLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primarySage),
                ),
                child: Text(
                  'UNLOCKED',
                  style: TextStyle(
                    color: AppColors.sageDark,
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
                    Icon(
                      Icons.lock_outline,
                      size: 10,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
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
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            if (isUnlocked && unlockedAt != null)
              Text(
                'Earned on ${DateFormatter.formatDate(unlockedAt)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sageDark,
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
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primarySage,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    progressText,
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
      ),
    );
  }

  Widget _buildRewardHistoryStream() {
    return StreamBuilder<List<RewardHistoryModel>>(
      stream: _gamificationService.streamRewardHistory(_activeStudentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.sageDark),
            ),
          );
        }

        final rewards = snapshot.data ?? [];

        if (rewards.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 10),
                Text(
                  'No attendance rewards recorded yet',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Attend your registered events and get your QR code verified to earn 50 coins and unlock badges!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rewards.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final reward = rewards[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.peachLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('🪙', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reward.eventTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormatter.formatFullDateTime(reward.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
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
                      color: AppColors.sageLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primarySage),
                    ),
                    child: Text(
                      '+${reward.coinsAwarded}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.sageDark,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
