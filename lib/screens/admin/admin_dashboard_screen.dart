import 'package:flutter/material.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/registration_service.dart';
import '../../utils/constants.dart';
import '../auth/auth_wrapper.dart';
import 'create_edit_event_screen.dart';
import 'event_registrations_screen.dart';
import 'manage_events_screen.dart';
import 'admin_feedback_screen.dart';
import 'admin_gamification_screen.dart';
import 'admin_live_qr_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  final EventService _eventService = EventService();
  final RegistrationService _registrationService = RegistrationService();

  Future<void> _handleAdminLogout(BuildContext context) async {
    try {
      await _authService.signOut();
    } catch (e) {
      debugPrint('Admin logout error: $e');
    }

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            // SIDEBAR NAVIGATION RAIL
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              backgroundColor: AppColors.cardWhite,
              indicatorColor: AppColors.coralLight,
              selectedIconTheme: const IconThemeData(color: AppColors.coral),
              unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.coral,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelTextStyle: const TextStyle(color: AppColors.textSecondary),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: CircleAvatar(
                  backgroundColor: AppColors.coralLight,
                  radius: 24,
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: AppColors.coral,
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event),
                  label: Text('Events'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_alt_outlined),
                  selectedIcon: Icon(Icons.people_alt),
                  label: Text('Registrations'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profile'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1, color: AppColors.border),
            Expanded(child: _buildBody()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.cardWhite,
          selectedItemColor: AppColors.coral,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_outlined),
              activeIcon: Icon(Icons.event),
              label: 'Events',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_outlined),
              activeIcon: Icon(Icons.people_alt),
              label: 'Registrations',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardOverview();
      case 1:
        return const ManageEventsScreen();
      case 2:
        return const EventRegistrationsScreen();
      case 3:
        return _buildAdminProfile();
      default:
        return _buildDashboardOverview();
    }
  }

  Widget _buildDashboardOverview() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          // TOP-BAR EVENT QR CODES & ATTENDANCE ACTION ICON
          IconButton(
            tooltip: 'Event QR Codes & Attendance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminLiveQrScreen(),
                ),
              );
            },
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.mintLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.mintDark.withValues(alpha: 0.3),
                  width: 1.0,
                ),
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                size: 19,
                color: AppColors.mintDark,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textMain),
            tooltip: 'Logout',
            onPressed: () => _handleAdminLogout(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: _buildFeedbackFloatingButton(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. WELCOME BANNER (CORAL TO LAVENDER GRADIENT)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFEDE6),
                        Color(0xFFEDE9FE),
                      ],
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
                          Icons.admin_panel_settings_outlined,
                          color: AppColors.coral,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome back, Admin',
                              style: TextStyle(
                                color: AppColors.textMain,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _authService.currentUser?.email ?? 'admin@college.edu',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. OVERVIEW STATISTICS
                const Text(
                  'Overview Statistics',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 12),

                // SUMMARY CARDS (STREAM BACKED)
                StreamBuilder<List<EventModel>>(
                  stream: _eventService.streamAllEventsAdmin(),
                  builder: (context, eventSnapshot) {
                    final events = eventSnapshot.data ?? [];
                    final totalEvents = events.length;
                    final activeEvents = events.where((e) => e.isPublished).length;
                    final upcomingEvents = events
                        .where((e) => !e.isDeadlinePassed)
                        .length;

                    return StreamBuilder<List<RegistrationModel>>(
                      stream: _registrationService.streamEventRegistrations(''),
                      builder: (context, regSnapshot) {
                        final regs = regSnapshot.data ?? [];
                        final totalRegistrations = regs
                            .where((r) => r.isRegistered)
                            .length;

                        return GridView.count(
                          crossAxisCount: MediaQuery.of(context).size.width > 700
                              ? 4
                              : 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: MediaQuery.of(context).size.width > 700
                              ? 1.15
                              : 1.25,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildSummaryCard(
                              'Total Events',
                              '$totalEvents',
                              Icons.event_outlined,
                              AppColors.skyBlueLight,
                              AppColors.skyBlueDark,
                            ),
                            _buildSummaryCard(
                              'Active Events',
                              '$activeEvents',
                              Icons.check_circle_outline,
                              AppColors.mintLight,
                              AppColors.mintDark,
                            ),
                            _buildSummaryCard(
                              'Registrations',
                              '$totalRegistrations',
                              Icons.people_alt_outlined,
                              AppColors.coralLight,
                              AppColors.coralDark,
                            ),
                            _buildSummaryCard(
                              'Upcoming',
                              '$upcomingEvents',
                              Icons.schedule_outlined,
                              AppColors.lavenderLight,
                              AppColors.lavenderDark,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 20),

                // 3. QUICK ACTIONS — COMPACT REDESIGN
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                        letterSpacing: -0.3,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _selectedIndex = 1);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.coral,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 14),
                      label: const Text(
                        'View All Events',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ROW OF COMPACT PRIMARY/SECONDARY ACTIONS
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.coral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateEditEventScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(
                          'Add New Event',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.cardWhite,
                          foregroundColor: AppColors.textMain,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          setState(() => _selectedIndex = 2);
                        },
                        icon: const Icon(Icons.format_list_bulleted, size: 18, color: AppColors.lavender),
                        label: const Text(
                          'View Registrations',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // CAMPUS REWARDS & GAMIFICATION MANAGEMENT ACTION
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.cardWhite,
                      foregroundColor: AppColors.textMain,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminGamificationScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.military_tech_outlined,
                      size: 20,
                      color: AppColors.coral,
                    ),
                    label: const Text(
                      'Campus Rewards & Gamification',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),

                const SizedBox(height: 70),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackFloatingButton(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'admin_feedback_fab',
      elevation: 2.5,
      highlightElevation: 4.0,
      backgroundColor: AppColors.lavenderLight,
      shape: CircleBorder(
        side: BorderSide(
          color: AppColors.lavender.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      tooltip: 'Feedback & Reviews',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminFeedbackScreen(),
          ),
        );
      },
      child: const Icon(
        Icons.rate_review_rounded,
        size: 20,
        color: AppColors.lavenderDark,
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String count,
    IconData icon,
    Color bg,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: bg,
            child: Icon(icon, color: iconColor, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminProfile() {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Profile'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                CircleAvatar(
                  radius: 45,
                  backgroundColor: AppColors.coralLight,
                  child: const Icon(
                    Icons.admin_panel_settings,
                    size: 50,
                    color: AppColors.coral,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'System Administrator',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'admin@college.edu',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.lavender),
                  ),
                  child: const Text(
                    'ROLE: ADMIN / FACULTY',
                    style: TextStyle(
                      color: AppColors.lavenderDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pinkLight,
                      foregroundColor: AppColors.pinkDark,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.pink),
                      ),
                    ),
                    onPressed: () => _handleAdminLogout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'LOGOUT OF ADMIN PANEL',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
