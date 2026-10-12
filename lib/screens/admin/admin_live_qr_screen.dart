import 'package:flutter/material.dart';

import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../utils/constants.dart';
import 'event_live_attendance_qr_screen.dart';

class AdminLiveQrScreen extends StatelessWidget {
  const AdminLiveQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final EventService eventService = EventService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Live Attendance QR',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
          ),
        ),
        backgroundColor: AppColors.cardWhite,
        foregroundColor: AppColors.textMain,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<EventModel>>(
        stream: eventService.streamAllEventsAdmin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.lavenderDark),
            );
          }

          final allEvents = snapshot.data ?? [];
          // Show ONLY published events eligible for live QR attendance
          final publishedEvents =
              allEvents.where((e) => e.isPublished).toList();

          if (publishedEvents.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: const BoxDecoration(
                        color: AppColors.lavenderLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        size: 54,
                        color: AppColors.lavenderDark,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Published Events Available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Only published events are eligible for live attendance sessions. Publish an event from Manage Events to take attendance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                itemCount: publishedEvents.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildGuidanceBanner();
                  }
                  final event = publishedEvents[index - 1];
                  return _buildEventSelectionCard(context, event);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGuidanceBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.lavenderLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.pastelLavender),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: AppColors.lavenderDark,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Select an event to open its live attendance QR code and rotation controls.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.lavenderDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSelectionCard(BuildContext context, EventModel event) {
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
          onTap: () => _navigateToEventQr(context, event),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CATEGORY BADGE
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.pastelLavender),
                  ),
                  child: Text(
                    event.category.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.lavenderDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // EVENT NAME
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),

                // EVENT DATE & VENUE
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      event.dateFormatted,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (event.venue.isNotEmpty) ...[
                      const SizedBox(width: 14),
                      const Icon(
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
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // VIEW QR CODE ACTION
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToEventQr(context, event),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lavenderDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Text(
                      'View QR Code',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToEventQr(BuildContext context, EventModel event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventLiveAttendanceQrScreen(event: event),
      ),
    );
  }
}
