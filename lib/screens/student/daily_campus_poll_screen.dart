import 'package:flutter/material.dart';

import '../../models/gamification_model.dart';
import '../../services/gamification_service.dart';
import '../../utils/constants.dart';
import '../../widgets/daily_campus_poll_card.dart';
import '../../widgets/streak_symbol_selector_dialog.dart';

/// Dedicated Daily Campus Poll screen for students.
/// Accessible via the compact top-bar icon button on the student Home screen.
class DailyCampusPollScreen extends StatelessWidget {
  final String studentId;
  final String studentName;

  const DailyCampusPollScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    final gamificationService = GamificationService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.textMain,
          ),
          tooltip: 'Back to Home',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Daily Campus Poll',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppColors.textMain,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Voice your preference • Build your streak',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (studentId.isNotEmpty)
            StreamBuilder<GamificationModel?>(
              stream: gamificationService.streamGamification(studentId),
              builder: (context, snapshot) {
                final game = snapshot.data;
                final symbol = game?.streakSymbol ?? StreakSymbols.fire;
                final streak = game?.dailyStreak ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Center(
                    child: Tooltip(
                      message: 'Choose Streak Symbol',
                      child: InkWell(
                        onTap: () {
                          StreakSymbolSelectorDialog.show(
                            context,
                            studentId: studentId,
                            currentSymbol: symbol,
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.coralLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.coral.withValues(alpha: 0.4),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                symbol,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Day $streak',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.coralDark,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.arrow_drop_down,
                                size: 14,
                                color: AppColors.coralDark,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. WELCOME HERO BANNER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFEDE6), Color(0xFFEDE9FE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.how_to_vote_rounded,
                          color: AppColors.coral,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Make Your Voice Heard 🗳️',
                              style: TextStyle(
                                color: AppColors.textMain,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Your vote directly shapes campus workshops, hackathons, and activities. Vote daily to build your engagement streak!',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 2. CHOOSE YOUR STREAK SYMBOL QUICK SELECTOR
                if (studentId.isNotEmpty)
                  StreamBuilder<GamificationModel?>(
                    stream: gamificationService.streamGamification(studentId),
                    builder: (context, snapshot) {
                      final game = snapshot.data;
                      final currentSymbol =
                          game?.streakSymbol ?? StreakSymbols.fire;

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.palette_outlined,
                                  size: 15,
                                  color: AppColors.lavenderDark,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Choose Your Streak Symbol',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Current: $currentSymbol ${StreakSymbols.getLabel(currentSymbol)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: StreakSymbols.all.map((symbol) {
                                final isSelected = symbol == currentSymbol;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    child: InkWell(
                                      onTap: () async {
                                        if (!isSelected) {
                                          await gamificationService
                                              .updateStreakSymbol(
                                                studentId,
                                                symbol,
                                              );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.coralLight
                                              : AppColors.background,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.coral
                                                : AppColors.border,
                                            width: isSelected ? 1.6 : 1.0,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              symbol,
                                              style: TextStyle(
                                                fontSize: isSelected ? 19 : 17,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              StreakSymbols.getLabel(symbol),
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isSelected
                                                    ? AppColors.coralDark
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 14),

                // 3. MAIN ANIMATED DAILY CAMPUS POLL CARD
                DailyCampusPollCard(
                  studentId: studentId,
                  studentName: studentName,
                  showEmptyState: true,
                ),

                const SizedBox(height: 8),

                // 4. PARTICIPATION & INTEGRITY GUIDELINES
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.verified_outlined,
                            size: 14,
                            color: AppColors.mintDark,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'How Daily Campus Polls Work',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildBulletItem(
                        '1 vote per student: Your vote is securely recorded and uniquely counted.',
                      ),
                      _buildBulletItem(
                        'Vote editing: Change your mind? Tap "Edit My Vote" while the poll is open to update your selection.',
                      ),
                      _buildBulletItem(
                        'Engagement streak: Your first valid vote each calendar day advances your daily streak.',
                      ),
                      _buildBulletItem(
                        'Decision support: Real-time results guide college organizers in hosting the most requested workshops and events.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.coral,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
