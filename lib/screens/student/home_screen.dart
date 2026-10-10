import 'package:flutter/material.dart';

import '../../models/event_model.dart';
import '../../models/gamification_model.dart';
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
import 'student_feedback_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final EventService _eventService = EventService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

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
    return SafeArea(
      child: SingleChildScrollView(
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
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
                            AuthService().currentUid ?? '',
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
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // SEARCH BAR (Functional, with clear button, filter icon removed)
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

                const SizedBox(height: 18),

                // CATEGORIES
                SizedBox(
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

                const SizedBox(height: 22),

                // EVENTS CONTENT STREAM (COMBINED SEARCH & CATEGORY)
                StreamBuilder<List<EventModel>>(
                  stream: _eventService.streamEvents(),
                  builder: (context, snapshot) {
                    final allEvents =
                        (snapshot.hasData && snapshot.data!.isNotEmpty)
                            ? snapshot.data!
                            : mock_data.events;

                    // Filter by category and search query
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
                      return matchesCategory && matchesSearch;
                    }).toList();

                    final isFiltering =
                        _searchQuery.isNotEmpty || _selectedCategory != 'All';

                    if (isFiltering) {
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
                                    inherit: true,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textMain,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isFiltering)
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
                                      inherit: true,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  child: const Text(
                                    'Reset Filters',
                                    style: TextStyle(inherit: true),
                                  ),
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
                                      'Try a different keyword or category.',
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

                    // STANDARD HOME VIEW (Featured + Upcoming)
                    final featuredEvent =
                        allEvents.isNotEmpty ? allEvents.first : null;
                    final upcomingList = allEvents.length > 1
                        ? allEvents.skip(1).toList()
                        : allEvents;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (featuredEvent != null) ...[
                          const Text(
                            'Featured Event',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                              letterSpacing: -0.3,
                            ),
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
                                  inherit: true,
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
                                  inherit: true,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              child: const Text(
                                'See All',
                                style: TextStyle(inherit: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (upcomingList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'No upcoming events at the moment.',
                                style: TextStyle(color: AppColors.textSecondary),
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

                // APP FEEDBACK BANNER
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderLight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.lavender.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.lavender),
                        ),
                        child: const Icon(
                          Icons.rate_review_outlined,
                          color: AppColors.lavenderDark,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Feedback About the App',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMain,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Rate your experience or share suggestions',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => StudentFeedbackDialog.show(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.coral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Rate App',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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
