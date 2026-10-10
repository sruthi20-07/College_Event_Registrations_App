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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
                        'Welcome Back 👋',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                              color: AppColors.lavenderLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.pastelLavender,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '🪙',
                                  style: TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$coins',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.lavenderDark,
                                  ),
                                ),
                                if (streak > 0) ...[
                                  const SizedBox(width: 6),
                                  const Text(
                                    '🔥',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '$streak',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppColors.peachDark,
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
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.notifications_none, color: AppColors.textMain),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // SEARCH BAR
            TextField(
              decoration: InputDecoration(
                hintText: 'Search events, workshops, fests...',
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.sageLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primarySage),
                  ),
                  child: Icon(Icons.tune, color: AppColors.sageDark, size: 20),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // CATEGORIES
            SizedBox(
              height: 45,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  CategoryChip(label: 'All', isSelected: true),
                  CategoryChip(label: 'Technical'),
                  CategoryChip(label: 'Workshop'),
                  CategoryChip(label: 'Cultural'),
                  CategoryChip(label: 'Sports'),
                  CategoryChip(label: 'Hackathon'),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // FEATURED SECTION
            Text(
              'Featured Event',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 14),

            StreamBuilder<List<EventModel>>(
              stream: _eventService.streamEvents(),
              builder: (context, snapshot) {
                final displayEvents =
                    (snapshot.hasData && snapshot.data!.isNotEmpty)
                    ? snapshot.data!
                    : mock_data.events;

                if (displayEvents.isEmpty) {
                  return const SizedBox.shrink();
                }

                final featuredEvent = displayEvents.first;

                return FeaturedEventCard(
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
                );
              },
            ),

            const SizedBox(height: 25),

            // UPCOMING EVENTS HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Events',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                    letterSpacing: -0.3,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EventsScreen()),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.sageDark,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: const Text('See All'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            StreamBuilder<List<EventModel>>(
              stream: _eventService.streamEvents(),
              builder: (context, snapshot) {
                final displayEvents =
                    (snapshot.hasData && snapshot.data!.isNotEmpty)
                    ? snapshot.data!
                    : mock_data.events;

                final upcomingList = displayEvents.length > 1
                    ? displayEvents.skip(1).toList()
                    : displayEvents;

                if (upcomingList.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No upcoming events at the moment.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }

                return ListView.builder(
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
                            builder: (_) => EventDetailsScreen(event: item),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // APP FEEDBACK BANNER
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.lavenderLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.pastelLavender,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.pastelLavender,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.rate_review_rounded,
                      color: AppColors.lavenderDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feedback About the App',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
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
                      backgroundColor: AppColors.primarySage,
                      foregroundColor: AppColors.sageDark,
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
    );
  }
}
