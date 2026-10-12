import 'package:flutter/material.dart';

import '../../models/gamification_model.dart';
import '../../models/registration_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/gamification_service.dart';
import '../../services/registration_service.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';
import '../auth/auth_wrapper.dart';
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
                    color: AppColors.coralLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.coral, width: 2),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 50,
                    color: AppColors.coral,
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
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFEDE6),
                              Color(0xFFEDE9FE),
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
                                color: AppColors.cardWhite,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(
                                Icons.monetization_on,
                                color: AppColors.coral,
                                size: 22,
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
                                        style: const TextStyle(
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
                                            color: AppColors.coralLight,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: AppColors.coral,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.local_fire_department,
                                                size: 11,
                                                color: AppColors.coral,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${game.currentStreak}d',
                                                style: const TextStyle(
                                                  color: AppColors.coralDark,
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
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
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
                  AppColors.coralLight,
                  AppColors.coral,
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
                  Icons.bookmark_outline_rounded,
                  'Saved Events',
                  AppColors.coralLight,
                  AppColors.coralDark,
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
                  Icons.chat_bubble_outline_rounded,
                  'WhatsApp Notification Preferences',
                  AppColors.mintLight,
                  AppColors.mintDark,
                  () {
                    _showWhatsAppPreferencesSheet(context, user, authService);
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
                  AppColors.yellowLight,
                  AppColors.yellowDark,
                  () {
                    StudentFeedbackDialog.show(context);
                  },
                ),

                profileOption(
                  context,
                  Icons.info_outline,
                  'About App',
                  AppColors.mintLight,
                  AppColors.mintDark,
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

  void _showWhatsAppPreferencesSheet(
    BuildContext context,
    UserModel? user,
    AuthService authService,
  ) {
    final uid = authService.currentUid;
    if (uid == null) return;

    final phoneController = TextEditingController(
      text: user?.whatsappNumber.isNotEmpty == true
          ? user!.whatsappNumber
          : '',
    );
    bool consent = user?.whatsappConsent ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
              decoration: const BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppColors.mintDark,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'WhatsApp Notification Preferences',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Receive digital ticket updates, confirmation passes, and schedule reminders directly on WhatsApp.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp Number (with Country Code)',
                      hintText: '+91 9876543210',
                      prefixIcon: Icon(Icons.phone_android),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: consent,
                          activeColor: AppColors.coral,
                          onChanged: (val) {
                            setModalState(() => consent = val ?? false);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'I agree to receive WhatsApp messages about my event registration and ticket.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMain,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final rawNumber = phoneController.text.trim();
                        try {
                          await authService.updateWhatsAppPreferences(
                            uid: uid,
                            whatsappNumber: rawNumber,
                            whatsappConsent: consent,
                          );
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'WhatsApp preferences saved successfully!',
                                ),
                                backgroundColor: AppColors.mintDark,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update: $e'),
                                backgroundColor: AppColors.pinkDark,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Save Preferences'),
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
                  await authService.signOut();
                } catch (e) {
                  debugPrint('Logout error: $e');
                }

                if (!context.mounted) return;

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthWrapper()),
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
