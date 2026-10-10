import 'package:flutter/material.dart';

import '../../data/event_data.dart' as mock_data;
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';
import '../../widgets/event_card.dart';

class SavedEventsScreen extends StatefulWidget {
  const SavedEventsScreen({super.key});

  @override
  State<SavedEventsScreen> createState() => _SavedEventsScreenState();
}

class _SavedEventsScreenState extends State<SavedEventsScreen> {
  List<String> savedIds = [];
  final EventService _eventService = EventService();

  @override
  void initState() {
    super.initState();
    loadSavedEvents();
  }

  Future<void> loadSavedEvents() async {
    final result = await StorageService.getSavedEvents();
    if (mounted) {
      setState(() {
        savedIds = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Events')),
      body: StreamBuilder<List<EventModel>>(
        stream: _eventService.streamEvents(),
        builder: (context, snapshot) {
          final allEvents = (snapshot.hasData && snapshot.data!.isNotEmpty)
              ? snapshot.data!
              : mock_data.events;

          final savedEvents = allEvents
              .where((event) => savedIds.contains(event.id))
              .toList();

          if (savedEvents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.pinkLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_border,
                      size: 44,
                      color: AppColors.pinkDark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No saved events yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textMain,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap the heart icon on any event to save it here',
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
            padding: const EdgeInsets.all(20),
            itemCount: savedEvents.length,
            itemBuilder: (context, index) {
              return EventCard(event: savedEvents[index]);
            },
          );
        },
      ),
    );
  }
}
