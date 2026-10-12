import 'package:flutter/material.dart';

import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../utils/constants.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/event_card.dart';
import '../../data/event_data.dart' as mock_data;
import 'event_details_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String selectedCategory = 'All';
  String searchQuery = '';
  bool filterEligibleOnly = true;
  final EventService _eventService = EventService();
  final AuthService _authService = AuthService();

  final List<String> categories = [
    'All',
    'Technical',
    'Workshop',
    'Cultural',
    'Sports',
    'Hackathon',
  ];

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Explore Events')),
      body: StreamBuilder<UserModel?>(
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

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // SEARCH
                TextField(
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by title, venue or organizer...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                            onPressed: () {
                              setState(() {
                                searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 15),

                // CATEGORY CHIPS & ELIGIBILITY TOGGLE
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            return CategoryChip(
                              label: category,
                              isSelected: selectedCategory == category,
                              onTap: () {
                                setState(() {
                                  selectedCategory = category;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    if (!isStaff && userProfile != null && !isProfileIncomplete) ...[
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(
                          filterEligibleOnly ? '🎓 Eligible' : '🌐 All',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: filterEligibleOnly
                                ? AppColors.lavenderDark
                                : AppColors.textSecondary,
                          ),
                        ),
                        selected: filterEligibleOnly,
                        selectedColor: AppColors.lavenderLight,
                        checkmarkColor: AppColors.lavenderDark,
                        onSelected: (val) {
                          setState(() {
                            filterEligibleOnly = val;
                          });
                        },
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // EVENTS LIST
                Expanded(
                  child: StreamBuilder<List<EventModel>>(
                    stream: _eventService.streamEventsByCategory(selectedCategory),
                    builder: (context, snapshot) {
                      List<EventModel> filteredEvents = [];

                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        filteredEvents = snapshot.data!;
                      } else {
                        filteredEvents = mock_data.events.where((event) {
                          final matchesCategory =
                              selectedCategory == 'All' ||
                              event.category == selectedCategory;
                          return matchesCategory;
                        }).toList();
                      }

                      if (searchQuery.isNotEmpty) {
                        filteredEvents = filteredEvents.where((event) {
                          return event.title.toLowerCase().contains(searchQuery) ||
                              event.venue.toLowerCase().contains(searchQuery) ||
                              event.organizer.toLowerCase().contains(searchQuery);
                        }).toList();
                      }

                      // Apply student eligibility filter
                      if (filterEligibleOnly && !isStaff && userProfile != null && !isProfileIncomplete) {
                        filteredEvents = filteredEvents
                            .where((event) => event.isEligibleFor(userProfile))
                            .toList();
                      }

                      if (filteredEvents.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppColors.lavenderLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.event_busy,
                                  size: 44,
                                  color: AppColors.lavenderDark,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No events found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textMain,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                filterEligibleOnly && userProfile != null
                                    ? 'No eligible events for ${userProfile.year} • ${userProfile.department}'
                                    : 'Try adjusting your search or category filter',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: filteredEvents.length,
                        itemBuilder: (context, index) {
                          final event = filteredEvents[index];
                          return EventCard(
                            event: event,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventDetailsScreen(event: event),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
