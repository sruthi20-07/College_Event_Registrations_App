import 'package:flutter/material.dart';

import '../../models/event_model.dart';
import '../../models/gamification_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/gamification_service.dart';
import '../../utils/constants.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/event_card.dart';
import '../../widgets/featured_event_card.dart';
import '../../data/event_data.dart' as mock_data;
import 'event_details_screen.dart';
import 'events_screen.dart';
import 'gamification_dashboard_screen.dart';
import 'profile_screen.dart';
import 'student_attendance_scanner_screen.dart';
import 'student_feedback_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final EventService _eventService = EventService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _filterEligibleOnly = true;

  final List<String> _categories = const [
    'All',
    'Technical',
    'Workshop',
    'Cultural',
    'Sports',
    'Hackathon',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUid ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _buildFeedbackFloatingButton(context),
      body: SafeArea(
        child: StreamBuilder<UserModel?>(
        stream: currentUid.isNotEmpty
            ? _authService.streamUserProfile(currentUid)
            : Stream.value(null),
        builder: (context, userSnapshot) {
          final userProfile = userSnapshot.data;
          final bool isStaff = userProfile?.isStaff ?? false;
          final bool isProfileIncomplete = userProfile != null &&
              !isStaff &&
              (userProfile.year.trim().isEmpty ||
                  userProfile.department.trim().isEmpty);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userProfile != null && userProfile.name.isNotEmpty
                                    ? 'Welcome, ${userProfile.name}'
                                    : 'Welcome Back',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Discover Events',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMain,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            StreamBuilder<GamificationModel?>(
                              stream: GamificationService().streamGamification(
                                currentUid,
                              ),
                              builder: (context, gameSnap) {
                                final game = gameSnap.data;
                                final coins = game?.coins ?? 0;
                                final streak = game?.currentStreak ?? 0;

                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const GamificationDashboardScreen(),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.coralLight,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.coral,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.monetization_on,
                                          size: 15,
                                          color: AppColors.coral,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$coins',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppColors.coralDark,
                                          ),
                                        ),
                                        if (streak > 0) ...[
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.local_fire_department,
                                            size: 14,
                                            color: AppColors.coral,
                                          ),
                                          Text(
                                            '$streak',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: AppColors.coralDark,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            // SMALL TOP-BAR SCANNER ICON
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const StudentAttendanceScannerScreen(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppColors.lavenderLight,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.lavenderDark.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 1.0,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.qr_code_scanner_rounded,
                                  size: 18,
                                  color: AppColors.lavenderDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),


                    // INCOMPLETE PROFILE BANNER
                    if (isProfileIncomplete) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.yellowLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.sunnyYellow),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.yellowDark, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Complete your profile with Year & Branch to filter events tailored for you.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMain,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.coralDark,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // SEARCH BAR
                    TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search events, workshops, fests...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // CATEGORIES & ELIGIBILITY TOGGLE
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final category = _categories[index];
                                final isSelected = _selectedCategory == category;
                                return CategoryChip(
                                  label: category,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = category;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                        if (!isStaff && userProfile != null && !isProfileIncomplete) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: _filterEligibleOnly
                                ? 'Showing events eligible for you'
                                : 'Showing all college events',
                            child: FilterChip(
                              label: Text(
                                _filterEligibleOnly ? '🎓 Eligible' : '🌐 All',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _filterEligibleOnly
                                      ? AppColors.lavenderDark
                                      : AppColors.textSecondary,
                                ),
                              ),
                              selected: _filterEligibleOnly,
                              selectedColor: AppColors.lavenderLight,
                              checkmarkColor: AppColors.lavenderDark,
                              onSelected: (val) {
                                setState(() {
                                  _filterEligibleOnly = val;
                                });
                              },
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 22),

                    // EVENTS CONTENT STREAM (COMBINED SEARCH, CATEGORY & ELIGIBILITY)
                    StreamBuilder<List<EventModel>>(
                      stream: _eventService.streamEvents(),
                      builder: (context, snapshot) {
                        final allEvents =
                            (snapshot.hasData && snapshot.data!.isNotEmpty)
                                ? snapshot.data!
                                : mock_data.events;

                        // Filter by category, search query, and eligibility
                        final filteredEvents = allEvents.where((event) {
                          final matchesCategory = _selectedCategory == 'All' ||
                              event.category.toLowerCase() ==
                                  _selectedCategory.toLowerCase();
                          final matchesSearch = _searchQuery.isEmpty ||
                              event.title.toLowerCase().contains(_searchQuery) ||
                              event.category.toLowerCase().contains(_searchQuery) ||
                              event.description.toLowerCase().contains(_searchQuery) ||
                              event.venue.toLowerCase().contains(_searchQuery) ||
                              event.organizer.toLowerCase().contains(_searchQuery);

                          // Eligibility filter: if active and student profile exists
                          final bool matchesEligibility = isStaff ||
                              !_filterEligibleOnly ||
                              isProfileIncomplete ||
                              userProfile == null ||
                              event.isEligibleFor(userProfile);

                          return matchesCategory && matchesSearch && matchesEligibility;
                        }).toList();

                        if (_searchQuery.isNotEmpty || _selectedCategory != 'All') {
                          // FILTERED / SEARCH RESULTS VIEW
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _searchQuery.isNotEmpty
                                          ? 'Search Results (${filteredEvents.length})'
                                          : '$_selectedCategory Events (${filteredEvents.length})',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textMain,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _selectedCategory = 'All';
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.coral,
                                      textStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    child: const Text('Reset Filters'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (filteredEvents.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 36),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(18),
                                          decoration: BoxDecoration(
                                            color: AppColors.lavenderLight,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.event_busy_rounded,
                                            size: 40,
                                            color: AppColors.lavenderDark,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        const Text(
                                          'No matching events found',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textMain,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Try adjusting your search or category filter.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filteredEvents.length,
                                  itemBuilder: (context, index) {
                                    final item = filteredEvents[index];
                                    return EventCard(
                                      event: item,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                EventDetailsScreen(event: item),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                            ],
                          );
                        }

                        // STANDARD HOME VIEW (Featured + Eligible Upcoming)
                        final featuredEvent =
                            filteredEvents.isNotEmpty ? filteredEvents.first : null;
                        final upcomingList = filteredEvents.length > 1
                            ? filteredEvents.skip(1).toList()
                            : filteredEvents;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (featuredEvent != null) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Featured Event',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textMain,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  if (_filterEligibleOnly && userProfile != null && !isStaff)
                                    Text(
                                      'For ${userProfile.year}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.lavenderDark,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              FeaturedEventCard(
                                event: featuredEvent,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EventDetailsScreen(event: featuredEvent),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Upcoming Events',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textMain,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const EventsScreen(),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.coral,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  child: const Text('See All'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (upcomingList.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const Icon(Icons.event_available, size: 36, color: AppColors.textSecondary),
                                      const SizedBox(height: 8),
                                      Text(
                                        _filterEligibleOnly && userProfile != null
                                            ? 'No upcoming events found for ${userProfile.year} • ${userProfile.department}'
                                            : 'No upcoming events at the moment.',
                                        style: const TextStyle(color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: upcomingList.length,
                                itemBuilder: (context, index) {
                                  final item = upcomingList[index];
                                  return EventCard(
                                    event: item,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              EventDetailsScreen(event: item),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    const SizedBox(height: 70),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

  Widget _buildFeedbackFloatingButton(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'student_feedback_fab',
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
      onPressed: () => StudentFeedbackDialog.show(context),
      child: const Icon(
        Icons.rate_review_rounded,
        size: 20,
        color: AppColors.lavenderDark,
      ),
    );
  }
}
