import 'package:flutter/material.dart';

import '../../data/event_data.dart' as mock_data;
import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/registration_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_formatter.dart';
import 'event_details_screen.dart';
import 'registration_confirmation_screen.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final EventService _eventService = EventService();
  final RegistrationService _registrationService = RegistrationService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleCancelRegistration(
    RegistrationModel registration,
    String eventTitle,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Cancel Registration',
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to cancel your registration for "$eventTitle"? Your seat will be restored for other students.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              child: const Text('Keep Registration'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pinkLight,
                foregroundColor: AppColors.pinkDark,
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel Registration'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _registrationService.cancelRegistration(
          registration.id,
          registration.eventId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Registration cancelled successfully. Seat restored.',
              ),
              backgroundColor: AppColors.peachDark,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cancellation failed: ${e.toString()}'),
              backgroundColor: AppColors.pinkDark,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUid ?? 'demo_user';

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Registrations',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.coral,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.coral,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: StreamBuilder<List<RegistrationModel>>(
          stream: _registrationService.streamStudentRegistrations(currentUid),
          builder: (context, regSnapshot) {
            if (regSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.coral),
              );
            }

            final allRegs = regSnapshot.data ?? [];

            return StreamBuilder<List<EventModel>>(
              stream: _eventService.streamEvents(),
              builder: (context, eventSnapshot) {
                final allEvents =
                    (eventSnapshot.hasData && eventSnapshot.data!.isNotEmpty)
                    ? eventSnapshot.data!
                    : mock_data.events;

                final Map<String, EventModel> eventMap = {
                  for (var e in allEvents) e.id: e,
                };

                final activeRegs = allRegs
                    .where((r) => r.isRegistered)
                    .toList();
                final upcomingRegs = activeRegs.where((r) {
                  final event = eventMap[r.eventId];
                  if (event == null) return true;
                  return !event.isDeadlinePassed;
                }).toList();

                final completedRegs = activeRegs.where((r) {
                  final event = eventMap[r.eventId];
                  if (event == null) return false;
                  return event.isDeadlinePassed;
                }).toList();

                final cancelledRegs = allRegs
                    .where((r) => r.isCancelled)
                    .toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRegistrationList(
                      upcomingRegs,
                      eventMap,
                      isUpcoming: true,
                    ),
                    _buildRegistrationList(
                      completedRegs,
                      eventMap,
                      isCompleted: true,
                    ),
                    _buildRegistrationList(
                      cancelledRegs,
                      eventMap,
                      isCancelled: true,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildRegistrationList(
    List<RegistrationModel> registrations,
    Map<String, EventModel> eventMap, {
    bool isUpcoming = false,
    bool isCompleted = false,
    bool isCancelled = false,
  }) {
    if (registrations.isEmpty) {
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
                isCancelled
                    ? Icons.cancel_outlined
                    : (isCompleted
                          ? Icons.event_available_outlined
                          : Icons.confirmation_num_outlined),
                size: 48,
                color: isCancelled
                    ? AppColors.pinkDark
                    : (isCompleted
                          ? AppColors.sageDark
                          : AppColors.lavenderDark),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              isCancelled
                  ? 'No cancelled registrations'
                  : (isCompleted
                        ? 'No completed events'
                        : 'You haven\'t registered for any events yet.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your registered events will appear here.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: registrations.length,
      itemBuilder: (context, index) {
        final reg = registrations[index];
        final event = eventMap[reg.eventId];

        final eventTitle = event?.title ?? 'College Event (${reg.eventId})';
        final eventDate = event != null
            ? event.dateFormatted
            : DateFormatter.formatDate(reg.registeredAt);
        final eventVenue = event?.venue ?? 'Main Campus';

        final formattedRegId = reg.id.length > 8
            ? 'REG-${reg.id.substring(0, 8).toUpperCase()}'
            : 'REG-${reg.id.toUpperCase()}';

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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER ROW: REG ID & STATUS BADGE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedRegId,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: reg.isCancelled
                            ? AppColors.pinkLight
                            : (reg.isPaid
                                  ? AppColors.sageLight
                                  : AppColors.lavenderLight),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: reg.isCancelled
                              ? AppColors.pastelPink
                              : (reg.isPaid
                                    ? AppColors.primarySage
                                    : AppColors.pastelLavender),
                        ),
                      ),
                      child: Text(
                        reg.isCancelled
                            ? 'CANCELLED'
                            : (reg.isPaid ? 'PAID ✓' : 'REGISTERED'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: reg.isCancelled
                              ? AppColors.pinkDark
                              : (reg.isPaid
                                    ? AppColors.sageDark
                                    : AppColors.lavenderDark),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // EVENT TITLE
                Text(
                  eventTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      eventDate,
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
                        eventVenue,
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
                Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 6),

                // ACTION BUTTONS
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (event != null)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventDetailsScreen(event: event),
                            ),
                          );
                        },
                        icon: Icon(Icons.info_outline, size: 16, color: AppColors.sageDark),
                        label: Text('Event Info', style: TextStyle(color: AppColors.sageDark)),
                      ),

                    if (event != null && !reg.isCancelled)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegistrationConfirmationScreen(
                                event: event,
                                registration: reg,
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.sageDark),
                        label: Text('View Ticket', style: TextStyle(color: AppColors.sageDark)),
                      ),

                    if (isUpcoming && !reg.isCancelled)
                      TextButton.icon(
                        onPressed: () =>
                            _handleCancelRegistration(reg, eventTitle),
                        icon: Icon(
                          Icons.cancel_outlined,
                          size: 16,
                          color: AppColors.pinkDark,
                        ),
                        label: Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.pinkDark),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
