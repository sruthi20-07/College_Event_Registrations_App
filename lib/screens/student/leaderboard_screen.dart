import 'package:flutter/material.dart';
import '../../models/gamification_model.dart';
import '../../services/auth_service.dart';
import '../../services/gamification_service.dart';
import '../../utils/constants.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  String _getTierName(int lifetimeCoins) {
    if (lifetimeCoins >= 500) return 'Diamond Legend';
    if (lifetimeCoins >= 250) return 'Gold Champion';
    if (lifetimeCoins >= 100) return 'Silver Pioneer';
    if (lifetimeCoins >= 50) return 'Bronze Scholar';
    return 'Campus Explorer';
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFB800); // Gold
      case 2:
        return const Color(0xFF9E9E9E); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.lavender;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final gamificationService = GamificationService();
    final currentUid = authService.currentUid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Campus Leaderboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<GamificationModel>>(
        stream: gamificationService.streamLeaderboard(limit: 50),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.coral),
            );
          }

          final leaderboard = snapshot.data ?? [];

          if (leaderboard.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: AppColors.lavenderLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events_outlined,
                        size: 48,
                        color: AppColors.lavenderDark,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No Leaderboard Records Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Attend events and verify attendance to earn campus points and claim the top spots!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Find current student's rank
          int studentRank = -1;
          GamificationModel? currentStudentData;
          for (int i = 0; i < leaderboard.length; i++) {
            if (leaderboard[i].studentId == currentUid) {
              studentRank = i + 1;
              currentStudentData = leaderboard[i];
              break;
            }
          }

          return Column(
            children: [
              // HEADER EXPLANATORY CARD
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.lavender.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: AppColors.lavenderDark),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Rankings are based on Lifetime Coins earned from verified event attendance. Spending coins on rewards never reduces your rank!',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.lavenderDark,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // CURRENT USER HIGHLIGHT BAR (IF FOUND)
              if (currentStudentData != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFEDE6), Color(0xFFEDE9FE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.coral),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.coral,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '#$studentRank',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Standing',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textMain,
                                ),
                              ),
                              Text(
                                '${_getTierName(currentStudentData.lifetimeCoins)} • ${currentStudentData.totalEventsAttended} Events Attended',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${currentStudentData.lifetimeCoins} pts',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.coralDark,
                              ),
                            ),
                            Text(
                              '${currentStudentData.coins} spendable',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // LEADERBOARD LIST
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: leaderboard.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = leaderboard[index];
                    final rank = index + 1;
                    final isCurrentUser = item.studentId == currentUid;
                    final rankColor = _getRankColor(rank);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isCurrentUser
                            ? AppColors.coralLight.withValues(alpha: 0.6)
                            : AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrentUser ? AppColors.coral : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Rank indicator
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: rank <= 3
                                  ? rankColor.withValues(alpha: 0.15)
                                  : AppColors.background,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: rank <= 3 ? rankColor : AppColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$rank',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: rank <= 3 ? rankColor : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Student details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      isCurrentUser
                                          ? 'You (${item.studentId.substring(0, 4).toUpperCase()})'
                                          : 'Student ${item.studentId.substring(0, 4).toUpperCase()}',
                                      style: TextStyle(
                                        fontWeight: isCurrentUser
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.textMain,
                                      ),
                                    ),
                                    if (isCurrentUser) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.coral,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'YOU',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_getTierName(item.lifetimeCoins)} • ${item.totalEventsAttended} events attended',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Points
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${item.lifetimeCoins} pts',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.lavenderDark,
                                ),
                              ),
                              if (item.currentStreak > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.local_fire_department,
                                      size: 12,
                                      color: AppColors.coral,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${item.currentStreak}d streak',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.coralDark,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
