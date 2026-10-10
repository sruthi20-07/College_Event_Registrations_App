import 'package:flutter/material.dart';

import '../../models/event_model.dart';
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
  final EventService _eventService = EventService();

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
    return Scaffold(
      appBar: AppBar(title: const Text('Explore Events')),
      body: Padding(
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
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppColors.textSecondary),
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

            // CATEGORY CHIPS
            SizedBox(
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

            const SizedBox(height: 20),

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
                            child: Icon(
                              Icons.event_busy,
                              size: 44,
                              color: AppColors.lavenderDark,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No events found',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textMain,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try adjusting your search or category filter',
                            style: TextStyle(
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
      ),
    );
  }
}
