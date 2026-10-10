import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/gamification_model.dart';
import '../../models/registration_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/gamification_service.dart';
import '../../services/registration_service.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';
import '../auth/login_screen.dart';
import 'gamification_dashboard_screen.dart';
import 'saved_events_screen.dart';
import 'student_feedback_dialog.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final uid = authService.currentUid;

    return SafeArea(
      child: StreamBuilder<UserModel?>(
        stream: uid != null
            ? authService.streamUserProfile(uid)
            : Stream.value(null),
        builder: (context, snapshot) {
          final user = snapshot.data;
          final displayName = user?.name.isNotEmpty == true
              ? user!.name
              : (authService.currentUser?.email?.split('@').first ?? 'Student');
          final displayDetail = user != null && user.department.isNotEmpty
              ? '${user.department} • ${user.year}'
              : (authService.currentUser?.email ?? 'Student Account');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // PROFILE IMAGE
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.sageLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primarySage, width: 2),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: 50,
                    color: AppColors.sageDark,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  displayDetail,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),

                const SizedBox(height: 24),

                StreamBuilder<List<RegistrationModel>>(
                  stream: RegistrationService().streamStudentRegistrations(
                    uid ?? 'demo_user',
                  ),
                  builder: (context, regSnap) {
                    final activeRegs = (regSnap.data ?? [])
                        .where((r) => r.isRegistered)
                        .toList();
                    final int registeredCount = activeRegs.length;

                    return StreamBuilder<List<String>>(
                      stream: RegistrationService().streamSavedEventIds(
                        uid ?? 'demo_user',
                      ),
                      builder: (context, savedSnap) {
                        final firestoreSaved = savedSnap.data ?? [];
                        return FutureBuilder<List<String>>(
                          future: StorageService.getSavedEvents(),
                          builder: (context, localSnap) {
                            final localSaved = localSnap.data ?? [];
                            final allSaved = {
                              ...firestoreSaved,
                              ...localSaved,
                            }.toList();
                            final int savedCount = allSaved.length;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cardWhite,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        '$registeredCount',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.sageDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Events',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    height: 30,
                                    width: 1,
                                    color: AppColors.border,
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        '$savedCount',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.lavenderDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Saved',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 14),

                // GAMIFICATION & REWARDS BANNER
                StreamBuilder<GamificationModel?>(
                  stream: GamificationService().streamGamification(uid ?? ''),
                  builder: (context, gameSnap) {
                    final game =
                        gameSnap.data ??
                        GamificationModel(studentId: uid ?? '');
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                GamificationDashboardScreen(studentId: uid),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.pastelSage,
                              AppColors.pastelLavender,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.cardWhite.withValues(
                                  alpha: 0.8,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                '🪙',
                                style: TextStyle(fontSize: 22),
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
                                        '${game.coins} Coins',
                                        style: TextStyle(
                                          color: AppColors.textMain,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (game.currentStreak > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.peachLight,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: AppColors.pastelPeach,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                '🔥',
                                                style: TextStyle(fontSize: 10),
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${game.currentStreak}d',
                                                style: TextStyle(
                                                  color: AppColors.peachDark,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${game.totalBadgesUnlocked} / 5 Badges Unlocked • View Rewards',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 18),

                profileOption(
                  context,
                  Icons.emoji_events_outlined,
                  'Achievements & Rewards',
                  AppColors.sageLight,
                  AppColors.sageDark,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            GamificationDashboardScreen(studentId: uid),
                      ),
                    );
                  },
                ),

                profileOption(
                  context,
                  Icons.favorite_outline,
                  'Saved Events',
                  AppColors.pinkLight,
                  AppColors.pinkDark,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SavedEventsScreen(),
                      ),
                    );
                  },
                ),

                profileOption(
                  context,
                  Icons.notifications_none,
                  'Notifications',
                  AppColors.skyBlueLight,
                  AppColors.skyBlueDark,
                  () {},
                ),

                profileOption(
                  context,
                  Icons.settings_outlined,
                  'Settings',
                  AppColors.lavenderLight,
                  AppColors.lavenderDark,
                  () {},
                ),

                profileOption(
                  context,
                  Icons.rate_review_outlined,
                  'Feedback About the App',
                  AppColors.peachLight,
                  AppColors.peachDark,
                  () {
                    StudentFeedbackDialog.show(context);
                  },
                ),

                profileOption(
                  context,
                  Icons.info_outline,
                  'About App',
                  AppColors.sageLight,
                  AppColors.sageDark,
                  () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'College Events',
                      applicationVersion: '1.0.0',
                      applicationLegalese: 'College Event Management App',
                    );
                  },
                ),

                profileOption(
                  context,
                  Icons.logout,
                  'Logout',
                  AppColors.pinkLight,
                  AppColors.pinkDark,
                  () {
                    _showLogoutDialog(context, authService);
                  },
                  isDestructive: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Logout',
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to log out?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pinkLight,
                foregroundColor: AppColors.pinkDark,
                elevation: 0,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await FirebaseAuth.instance.signOut();
                  await authService.signOut();
                } catch (e) {
                  debugPrint('Logout error: $e');
                }

                if (!context.mounted) return;

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Widget profileOption(
    BuildContext context,
    IconData icon,
    String title,
    Color iconBg,
    Color iconColor,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isDestructive ? AppColors.pinkDark : AppColors.textMain,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: isDestructive ? AppColors.pinkDark : AppColors.textSecondary,
            size: 20,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
