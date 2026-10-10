import 'package:flutter/material.dart';

import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../utils/constants.dart';
import 'create_edit_event_screen.dart';
import 'event_participants_screen.dart';

class ManageEventsScreen extends StatelessWidget {
  const ManageEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final EventService eventService = EventService();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Events')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateEditEventScreen()),
          );
        },
        backgroundColor: AppColors.primarySage,
        foregroundColor: AppColors.sageDark,
        elevation: 2,
        icon: Icon(Icons.add, color: AppColors.sageDark),
        label: Text(
          'Add Event',
          style: TextStyle(color: AppColors.sageDark, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<EventModel>>(
        stream: eventService.streamAllEventsAdmin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.sageDark),
            );
          }

          final events = snapshot.data ?? [];

          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.lavenderLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.event_note_outlined,
                      size: 48,
                      color: AppColors.lavenderDark,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'No events created yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap "Add Event" below to create your first event.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return _buildAdminEventCard(context, event, eventService);
            },
          );
        },
      ),
    );
  }

  Widget _buildAdminEventCard(
    BuildContext context,
    EventModel event,
    EventService eventService,
  ) {
    final bool isPublished = event.status == EventStatuses.upcoming;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EventParticipantsScreen(event: event),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TOP HEADER: CATEGORY & STATUS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lavenderLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.pastelLavender),
                      ),
                      child: Text(
                        event.category.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.lavenderDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPublished
                            ? AppColors.sageLight
                            : AppColors.pinkLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPublished
                              ? AppColors.primarySage
                              : AppColors.pastelPink,
                        ),
                      ),
                      child: Text(
                        event.status.toUpperCase(),
                        style: TextStyle(
                          color: isPublished
                              ? AppColors.sageDark
                              : AppColors.pinkDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // TITLE
                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 8),

                // DETAILS ROW
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      event.dateFormatted,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        event.venue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // CAPACITY / SEATS STATS
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem('Capacity', '${event.maxSeats}'),
                      _statItem('Registered', '${event.registeredCount}'),
                      _statItem(
                        'Available',
                        '${event.availableSeats}',
                        textColor: event.isFull ? AppColors.pinkDark : AppColors.sageDark,
                      ),
                      _statItem(
                        'Fee',
                        event.fee == 0 ? 'FREE' : '₹${event.fee.toInt()}',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // PARTICIPANT SUMMARY ROW (TAP HINT)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.people_alt_outlined,
                          size: 15,
                          color: AppColors.sageDark,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'View Participants (${event.registeredCount})',
                          style: TextStyle(
                            color: AppColors.sageDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.sageDark,
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 6),

                // ACTIONS BAR
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    // PARTICIPANTS BUTTON
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EventParticipantsScreen(event: event),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.people_outline,
                        size: 18,
                        color: AppColors.sageDark,
                      ),
                      label: Text(
                        'Participants',
                        style: TextStyle(
                          color: AppColors.sageDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // EDIT BUTTON
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateEditEventScreen(event: event),
                          ),
                        );
                      },
                      icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.textMain),
                      label: Text('Edit', style: TextStyle(color: AppColors.textMain)),
                    ),

                    // PUBLISH / UNPUBLISH TOGGLE
                    TextButton.icon(
                      onPressed: () async {
                        await eventService.togglePublishEvent(
                          event.id,
                          event.status,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isPublished
                                    ? 'Event unpublished'
                                    : 'Event published',
                              ),
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        isPublished
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: isPublished ? AppColors.peachDark : AppColors.sageDark,
                      ),
                      label: Text(
                        isPublished ? 'Unpublish' : 'Publish',
                        style: TextStyle(
                          color: isPublished ? AppColors.peachDark : AppColors.sageDark,
                        ),
                      ),
                    ),

                    // DELETE BUTTON
                    TextButton.icon(
                      onPressed: () =>
                          _confirmDelete(context, event, eventService),
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.pinkDark,
                      ),
                      label: Text(
                        'Delete',
                        style: TextStyle(color: AppColors.pinkDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, {Color? textColor}) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: textColor ?? AppColors.textMain,
          ),
        ),
      ],
    );
  }

  void _confirmDelete(
    BuildContext context,
    EventModel event,
    EventService eventService,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Delete Event',
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "${event.title}"? This action cannot be undone.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pinkLight,
                foregroundColor: AppColors.pinkDark,
                elevation: 0,
                minimumSize: const Size(90, 40),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await eventService.deleteEvent(event.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Event deleted successfully')),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
