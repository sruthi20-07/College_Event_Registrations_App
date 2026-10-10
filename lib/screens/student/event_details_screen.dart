import 'package:flutter/material.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/registration_service.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_formatter.dart';
import 'registration_confirmation_screen.dart';
import 'registration_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final EventService _eventService = EventService();
  final RegistrationService _registrationService = RegistrationService();
  final AuthService _authService = AuthService();

  bool isSaved = false;

  @override
  void initState() {
    super.initState();
    loadSavedStatus();
  }

  Future<void> loadSavedStatus() async {
    final result = await StorageService.isSaved(widget.event.id);
    if (mounted) {
      setState(() {
        isSaved = result;
      });
    }
  }

  Future<void> toggleSave() async {
    final currentUid = _authService.currentUid;
    if (currentUid != null) {
      await _registrationService.toggleSaveEvent(currentUid, widget.event.id);
    }
    await StorageService.toggleSavedEvent(widget.event.id);
    setState(() {
      isSaved = !isSaved;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUid ?? 'demo_user';

    return StreamBuilder<EventModel?>(
      stream: _eventService.streamEvent(widget.event.id),
      builder: (context, eventSnapshot) {
        final liveEvent = eventSnapshot.data ?? widget.event;

        return StreamBuilder<List<RegistrationModel>>(
          stream: _registrationService.streamStudentRegistrations(currentUid),
          builder: (context, regSnapshot) {
            final userRegs = regSnapshot.data ?? [];
            final existingReg = userRegs.firstWhere(
              (r) => r.eventId == liveEvent.id && r.isRegistered,
              orElse: () => RegistrationModel(
                id: '',
                eventId: '',
                studentId: '',
                studentName: '',
                studentEmail: '',
                rollNumber: '',
                department: '',
                year: '',
              ),
            );

            final bool isAlreadyRegistered = existingReg.id.isNotEmpty;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Event Details'),
                actions: [
                  IconButton(
                    onPressed: toggleSave,
                    icon: Icon(
                      isSaved ? Icons.favorite : Icons.favorite_border,
                      color: isSaved ? AppColors.pinkDark : AppColors.textMain,
                    ),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // POSTER / HEADER IMAGE
                    Container(
                      width: double.infinity,
                      height: 190,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFDED6),
                            Color(0xFFE5E1FD),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.event_seat_rounded,
                            color: AppColors.coral,
                            size: 52,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // CATEGORY CHIP & STATUS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lavenderLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.pastelLavender),
                          ),
                          child: Text(
                            liveEvent.category.toUpperCase(),
                            style: TextStyle(
                              color: AppColors.lavenderDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),

                        if (isAlreadyRegistered)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.sageLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.primarySage),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 14, color: AppColors.sageDark),
                                const SizedBox(width: 4),
                                Text(
                                  'REGISTERED',
                                  style: TextStyle(
                                    color: AppColors.sageDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      liveEvent.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 18),

                    infoRow(
                      Icons.calendar_today_outlined,
                      liveEvent.dateFormatted,
                      AppColors.sageLight,
                      AppColors.sageDark,
                    ),
                    infoRow(
                      Icons.access_time_rounded,
                      liveEvent.time,
                      AppColors.lavenderLight,
                      AppColors.lavenderDark,
                    ),
                    infoRow(
                      Icons.location_on_outlined,
                      liveEvent.venue,
                      AppColors.peachLight,
                      AppColors.peachDark,
                    ),
                    infoRow(
                      Icons.groups_outlined,
                      liveEvent.organizer,
                      AppColors.skyBlueLight,
                      AppColors.skyBlueDark,
                    ),
                    infoRow(
                      Icons.event_available_outlined,
                      'Deadline: ${DateFormatter.formatDate(liveEvent.registrationDeadline)}',
                      AppColors.pinkLight,
                      AppColors.pinkDark,
                    ),

                    const SizedBox(height: 22),

                    Text(
                      'About Event',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                        letterSpacing: -0.3,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      liveEvent.description,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.6,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // CAPACITY & SEATS SUMMARY BOXES
                    Row(
                      children: [
                        Expanded(
                          child: infoBox(
                            'Registration Fee',
                            liveEvent.fee == 0
                                ? 'FREE'
                                : '₹${liveEvent.fee.toInt()}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: infoBox('Capacity', '${liveEvent.maxSeats}'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: infoBox(
                            'Available Seats',
                            '${liveEvent.availableSeats}',
                            highlightColor: liveEvent.isFull
                                ? AppColors.pinkDark
                                : AppColors.sageDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // DYNAMIC ACTION BUTTON LOGIC
                    _buildActionButton(
                      context,
                      liveEvent,
                      isAlreadyRegistered,
                      existingReg,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    EventModel event,
    bool isAlreadyRegistered,
    RegistrationModel existingReg,
  ) {
    if (isAlreadyRegistered) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.border,
              disabledBackgroundColor: AppColors.border,
              disabledForegroundColor: AppColors.textSecondary,
            ),
            onPressed: null,
            child: const Text(
              'ALREADY REGISTERED',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RegistrationConfirmationScreen(
                    event: event,
                    registration: existingReg,
                  ),
                ),
              );
            },
            icon: Icon(Icons.receipt_long, color: AppColors.sageDark),
            label: Text(
              'VIEW MY TICKET',
              style: TextStyle(
                color: AppColors.sageDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    if (!event.isPublished ||
        event.status == EventStatuses.cancelled ||
        event.status == EventStatuses.completed) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.border,
            disabledBackgroundColor: AppColors.border,
            disabledForegroundColor: AppColors.textSecondary,
          ),
          onPressed: null,
          child: const Text(
            'EVENT CLOSED',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (event.isDeadlinePassed) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.border,
            disabledBackgroundColor: AppColors.border,
            disabledForegroundColor: AppColors.textSecondary,
          ),
          onPressed: null,
          child: const Text(
            'REGISTRATION CLOSED',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (event.isFull) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.border,
            disabledBackgroundColor: AppColors.border,
            disabledForegroundColor: AppColors.textSecondary,
          ),
          onPressed: null,
          child: const Text(
            'EVENT FULL',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RegistrationScreen(event: event)),
          );
        },
        child: const Text(
          'REGISTER NOW',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget infoRow(IconData icon, String text, Color bg, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget infoBox(String title, String value, {Color? highlightColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: highlightColor ?? AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}
