import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/registration_service.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_formatter.dart';
import 'profile_screen.dart';
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
  UserModel? _userProfile;

  @override
  void initState() {
    super.initState();
    loadSavedStatus();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final currentUid = _authService.currentUid;
    if (currentUid != null && currentUid.isNotEmpty) {
      final profile = await _authService.getUserProfile(currentUid);
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    }
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

  Future<void> _launchUrl(String uriString) async {
    final Uri uri = Uri.parse(uriString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching url $uriString: $e');
    }
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
            final bool hasProfile = _userProfile != null;
            final bool isStaff = _userProfile?.isStaff ?? false;
            final bool isProfileIncomplete = hasProfile &&
                !isStaff &&
                (_userProfile!.year.trim().isEmpty ||
                    _userProfile!.department.trim().isEmpty);
            final bool isEligible = isStaff ||
                (!isProfileIncomplete && liveEvent.isEligibleFor(_userProfile));

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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // POSTER / HEADER IMAGE
                        Container(
                          width: double.infinity,
                          height: 190,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getCategoryColor(liveEvent.category).withValues(alpha: 0.7),
                                AppColors.lavenderLight,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: liveEvent.posterUrl.startsWith('http')
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Image.network(
                                    liveEvent.posterUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardWhite.withValues(alpha: 0.9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getCategoryIcon(liveEvent.category),
                                          color: _getCategoryDarkColor(liveEvent.category),
                                          size: 48,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardWhite.withValues(alpha: 0.9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(liveEvent.category),
                                      color: _getCategoryDarkColor(liveEvent.category),
                                      size: 48,
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
                                style: const TextStyle(
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
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 14, color: AppColors.sageDark),
                                    SizedBox(width: 4),
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
                          style: const TextStyle(
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

                        const SizedBox(height: 20),

                        // ELIGIBILITY STATUS CARD
                        _buildEligibilityCard(
                          context,
                          liveEvent,
                          isStaff,
                          isProfileIncomplete,
                          isEligible,
                        ),

                        const SizedBox(height: 22),

                        const Text(
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
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.6,
                            fontSize: 14,
                          ),
                        ),

                        // REQUIREMENTS / PREREQUISITES SECTION
                        if (liveEvent.requirements.isNotEmpty || liveEvent.minCgpa > 0) ...[
                          const SizedBox(height: 22),
                          const Text(
                            'Requirements & Prerequisites',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.cardWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (liveEvent.minCgpa > 0)
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.yellowLight,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.star_rounded,
                                          color: AppColors.yellowDark,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Minimum CGPA Required: ${liveEvent.minCgpa.toStringAsFixed(1)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.textMain,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (liveEvent.minCgpa > 0 && liveEvent.requirements.isNotEmpty)
                                  const SizedBox(height: 10),
                                if (liveEvent.requirements.isNotEmpty)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.skyBlueLight,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.check_circle_outline,
                                          color: AppColors.skyBlueDark,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          liveEvent.requirements,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],

                        // COORDINATORS SECTION
                        if (liveEvent.coordinators.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Event Coordinators',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: liveEvent.coordinators.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final coord = liveEvent.coordinators[index];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.cardWhite,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.lavenderLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.person_pin_rounded,
                                        color: AppColors.lavenderDark,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                coord.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: AppColors.textMain,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.lavenderLight,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  coord.role,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.lavenderDark,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${coord.phone} • ${coord.email}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (coord.phone.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.phone_in_talk, color: AppColors.sageDark, size: 20),
                                        tooltip: 'Call Coordinator',
                                        onPressed: () => _launchUrl('tel:${coord.phone}'),
                                      ),
                                    if (coord.whatsapp.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.chat_outlined, color: AppColors.mintDark, size: 20),
                                        tooltip: 'WhatsApp Coordinator',
                                        onPressed: () {
                                          final cleanNumber = coord.whatsapp.replaceAll(RegExp(r'\D'), '');
                                          _launchUrl('https://wa.me/$cleanNumber');
                                        },
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],

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
                          isStaff,
                          isProfileIncomplete,
                          isEligible,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEligibilityCard(
    BuildContext context,
    EventModel event,
    bool isStaff,
    bool isProfileIncomplete,
    bool isEligible,
  ) {
    if (isStaff) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.lavenderLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lavender.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: AppColors.lavenderDark, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Admin/Staff View • Criteria: ${event.eligibilitySummary}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lavenderDark,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isProfileIncomplete) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.yellowLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.sunnyYellow),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.yellowDark, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile Details Incomplete',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.yellowDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Set your academic year and department in your profile to check eligibility.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      ).then((_) => _loadUserProfile());
                    },
                    child: const Text(
                      'Complete Profile →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.coral,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (!isEligible) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.pinkLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.pink),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.highlight_off_rounded, color: AppColors.pinkDark, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Not Eligible for Your Profile',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pinkDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Event Criteria: ${event.eligibilitySummary}\nYour Profile: ${_userProfile?.year ?? 'N/A'} • ${_userProfile?.department ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Eligible
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mintLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.mint),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, color: AppColors.mintDark, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You Are Eligible to Register',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mintDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.isAllYears && event.isAllDepartments
                      ? 'Open to all academic years and departments'
                      : 'Open to: ${event.eligibilitySummary}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    EventModel event,
    bool isAlreadyRegistered,
    RegistrationModel existingReg,
    bool isStaff,
    bool isProfileIncomplete,
    bool isEligible,
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
            icon: const Icon(Icons.receipt_long, color: AppColors.sageDark),
            label: const Text(
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
      return const SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(AppColors.border),
          ),
          onPressed: null,
          child: Text(
            'EVENT CLOSED',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    if (event.isDeadlinePassed) {
      return const SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(AppColors.border),
          ),
          onPressed: null,
          child: Text(
            'REGISTRATION CLOSED',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    if (event.isFull) {
      return const SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(AppColors.border),
          ),
          onPressed: null,
          child: Text(
            'EVENT FULL',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    if (isProfileIncomplete) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sunnyYellow,
            foregroundColor: AppColors.yellowDark,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ).then((_) => _loadUserProfile());
          },
          child: const Text(
            'COMPLETE PROFILE TO REGISTER',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (!isEligible) {
      return const SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(AppColors.border),
          ),
          onPressed: null,
          child: Text(
            'INELIGIBLE (YEAR / BRANCH RESTRICTION)',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
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
              style: const TextStyle(
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
            style: const TextStyle(
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
