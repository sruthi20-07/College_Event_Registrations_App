import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/registration_service.dart';
import '../../utils/constants.dart';
import '../auth/login_screen.dart';
import 'create_edit_event_screen.dart';
import 'event_registrations_screen.dart';
import 'manage_events_screen.dart';
import 'qr_scanner_screen.dart';
import 'admin_feedback_screen.dart';

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
      await FirebaseAuth.instance.signOut();
      await _authService.signOut();
    } catch (e) {
      debugPrint('Admin logout error: $e');
    }

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      return Scaffold(
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
              indicatorColor: AppColors.sageLight,
              selectedIconTheme: IconThemeData(color: AppColors.sageDark),
              unselectedIconTheme: IconThemeData(color: AppColors.textSecondary),
              selectedLabelTextStyle: TextStyle(
                color: AppColors.sageDark,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelTextStyle: TextStyle(color: AppColors.textSecondary),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: CircleAvatar(
                  backgroundColor: AppColors.sageLight,
                  radius: 24,
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: AppColors.sageDark,
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
            VerticalDivider(thickness: 1, width: 1, color: AppColors.border),
            Expanded(child: _buildBody()),
          ],
        ),
      );
    }

    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.cardWhite,
        selectedItemColor: AppColors.sageDark,
        unselectedItemColor: AppColors.textSecondary,
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
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: AppColors.textMain),
            tooltip: 'Logout',
            onPressed: () => _handleAdminLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WELCOME BANNER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.pastelSage,
                    AppColors.pastelLavender,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, Admin 👋',
                    style: TextStyle(
                      color: AppColors.textMain,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _authService.currentUser?.email ?? 'admin@college.edu',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Overview Statistics',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 14),

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
                      crossAxisCount: MediaQuery.of(context).size.width > 600
                          ? 4
                          : 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildSummaryCard(
                          'Total Events',
                          '$totalEvents',
                          Icons.event,
                          AppColors.skyBlueLight,
                          AppColors.skyBlueDark,
                        ),
                        _buildSummaryCard(
                          'Active Events',
                          '$activeEvents',
                          Icons.check_circle_outline,
                          AppColors.sageLight,
                          AppColors.sageDark,
                        ),
                        _buildSummaryCard(
                          'Registrations',
                          '$totalRegistrations',
                          Icons.people_outline,
                          AppColors.lavenderLight,
                          AppColors.lavenderDark,
                        ),
                        _buildSummaryCard(
                          'Upcoming',
                          '$upcomingEvents',
                          Icons.schedule,
                          AppColors.peachLight,
                          AppColors.peachDark,
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // QUICK ACTIONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                    letterSpacing: -0.3,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedIndex = 1);
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.sageDark),
                  child: const Text('View All Events'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primarySage,
                      foregroundColor: AppColors.sageDark,
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
                    label: const Text('Add New Event'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _selectedIndex = 2);
                    },
                    icon: Icon(Icons.format_list_bulleted, size: 18, color: AppColors.textMain),
                    label: const Text('View Registrations'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sageLight,
                  foregroundColor: AppColors.sageDark,
                  side: BorderSide(color: AppColors.primarySage),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                  );
                },
                icon: Icon(Icons.qr_code_scanner, size: 20, color: AppColors.sageDark),
                label: Text(
                  'Scan QR / Verify Attendance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.sageDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.lavenderLight,
                  foregroundColor: AppColors.lavenderDark,
                  side: BorderSide(color: AppColors.pastelLavender),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminFeedbackScreen(),
                    ),
                  );
                },
                icon: Icon(Icons.rate_review_outlined, size: 20, color: AppColors.lavenderDark),
                label: Text(
                  'Student App Feedback & Reviews',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.lavenderDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: bg,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
      appBar: AppBar(title: const Text('Admin Profile')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            CircleAvatar(
              radius: 45,
              backgroundColor: AppColors.sageLight,
              child: Icon(
                Icons.admin_panel_settings,
                size: 50,
                color: AppColors.sageDark,
              ),
            ),
            const SizedBox(height: 15),
            Text(
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
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.lavenderLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.pastelLavender),
              ),
              child: Text(
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
                ),
                onPressed: () => _handleAdminLogout(context),
                icon: const Icon(Icons.logout),
                label: const Text('LOGOUT OF ADMIN PANEL'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
