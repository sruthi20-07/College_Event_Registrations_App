import 'package:flutter/material.dart';

import '../../data/event_data.dart' as mock_data;
import '../../models/event_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/registration_service.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';
import '../../widgets/event_card.dart';

class SavedEventsScreen extends StatefulWidget {
  const SavedEventsScreen({super.key});

  @override
  State<SavedEventsScreen> createState() => _SavedEventsScreenState();
}

class _SavedEventsScreenState extends State<SavedEventsScreen> {
  final EventService _eventService = EventService();
  final RegistrationService _registrationService = RegistrationService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Events'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<String>>(
        stream: uid.isNotEmpty
            ? _registrationService.streamSavedEventIds(uid)
            : Stream.value([]),
        builder: (context, savedSnapshot) {
          return FutureBuilder<List<String>>(
            future: StorageService.getSavedEvents(),
            builder: (context, localSnapshot) {
              final firestoreSaved = savedSnapshot.data ?? [];
              final localSaved = localSnapshot.data ?? [];
              final Set<String> allSavedIds = {
                ...firestoreSaved,
                ...localSaved,
              };

              return StreamBuilder<List<EventModel>>(
                stream: _eventService.streamEvents(),
                builder: (context, eventSnapshot) {
                  final allEvents =
                      (eventSnapshot.hasData && eventSnapshot.data!.isNotEmpty)
                          ? eventSnapshot.data!
                          : mock_data.events;

                  final savedEvents = allEvents
                      .where((event) => allSavedIds.contains(event.id))
                      .toList();

                  if (savedEvents.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.coralLight,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.coral.withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Icon(
                                Icons.bookmark_border_rounded,
                                size: 48,
                                color: AppColors.coral,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No saved events yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.textMain,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Tap the bookmark icon on any event to save it here for quick access.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
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
              );
            },
          );
        },
      ),
    );
  }
}
