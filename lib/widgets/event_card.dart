import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../services/auth_service.dart';
import '../services/registration_service.dart';
import '../services/storage_service.dart';
import '../screens/student/event_details_screen.dart';
import '../utils/constants.dart';

class EventCard extends StatefulWidget {
  final EventModel event;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.event, this.onTap});

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool isSaved = false;
  final RegistrationService _registrationService = RegistrationService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    loadSavedStatus();
  }

  Future<void> loadSavedStatus() async {
    final localResult = await StorageService.isSaved(widget.event.id);
    if (mounted) {
      setState(() {
        isSaved = localResult;
      });
    }
  }

  Future<void> toggleSave() async {
    final currentSaved = isSaved;
    final nextSaved = !currentSaved;

    // Optimistic UI update
    setState(() {
      isSaved = nextSaved;
    });

    try {
      await StorageService.toggleSavedEvent(widget.event.id);
      final uid = _authService.currentUid;
      if (uid != null && uid.isNotEmpty) {
        await _registrationService.toggleSaveEvent(uid, widget.event.id);
      }
    } catch (e) {
      // Revert if error
      if (mounted) {
        setState(() {
          isSaved = currentSaved;
        });
      }
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'technical':
      case 'hackathon':
        return AppColors.skyBlue;
      case 'cultural':
        return AppColors.pink;
      case 'workshop':
      case 'seminar':
        return AppColors.primaryLight;
      case 'sports':
        return AppColors.peach;
      default:
        return AppColors.lavender;
    }
  }

  Color _getCategoryDarkColor(String category) {
    switch (category.toLowerCase()) {
      case 'technical':
      case 'hackathon':
        return AppColors.skyBlueDark;
      case 'cultural':
        return AppColors.pinkDark;
      case 'workshop':
      case 'seminar':
        return AppColors.primaryDark;
      case 'sports':
        return AppColors.peachDark;
      default:
        return AppColors.lavenderDark;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'technical':
        return Icons.code_rounded;
      case 'hackathon':
        return Icons.terminal_rounded;
      case 'cultural':
        return Icons.palette_outlined;
      case 'workshop':
      case 'seminar':
        return Icons.school_outlined;
      case 'sports':
        return Icons.fitness_center_rounded;
      default:
        return Icons.event_available_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _getCategoryColor(widget.event.category);
    final catDarkColor = _getCategoryDarkColor(widget.event.category);
    final catIcon = _getCategoryIcon(widget.event.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onTap ??
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailsScreen(event: widget.event),
                  ),
                );
              },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // PASTEL ICON BOX
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: catColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    catIcon,
                    color: catDarkColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                // DETAILS
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.event.category.toUpperCase(),
                          style: TextStyle(
                            color: catDarkColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.event.dateFormatted,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (widget.event.venue.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const Text('•', style: TextStyle(color: AppColors.border)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.event.venue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // BOOKMARK / SAVED ICON
                IconButton(
                  onPressed: toggleSave,
                  tooltip: isSaved ? 'Remove from Saved' : 'Save Event',
                  icon: Icon(
                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isSaved ? AppColors.coral : AppColors.textSecondary,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
