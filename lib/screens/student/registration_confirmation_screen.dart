import 'package:flutter/material.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../services/registration_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_formatter.dart';
import '../main_screen.dart';

class RegistrationConfirmationScreen extends StatefulWidget {
  final EventModel event;
  final RegistrationModel registration;

  const RegistrationConfirmationScreen({
    super.key,
    required this.event,
    required this.registration,
  });

  @override
  State<RegistrationConfirmationScreen> createState() =>
      _RegistrationConfirmationScreenState();
}

class _RegistrationConfirmationScreenState
    extends State<RegistrationConfirmationScreen> {
  final RegistrationService _registrationService = RegistrationService();

  String _activeTicketToken = '';

  @override
  void initState() {
    super.initState();
    _activeTicketToken = widget.registration.ticketToken;
    if (_activeTicketToken.isEmpty) {
      _initTicketToken();
    }
  }

  Future<void> _initTicketToken() async {
    final token = await _registrationService.ensureTicketToken(
      widget.registration,
    );
    if (mounted) {
      setState(() {
        _activeTicketToken = token;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Ticket & Pass'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const MainScreen(initialIndex: 2),
                ),
                (route) => false,
              );
            }
          },
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<RegistrationModel?>(
          stream: _registrationService.streamRegistration(
            widget.registration.id,
          ),
          builder: (context, snapshot) {
            final reg = snapshot.data ?? widget.registration;

            final formattedRegId = reg.id.length > 8
                ? 'REG-${reg.id.substring(0, 8).toUpperCase()}'
                : 'REG-${reg.id.toUpperCase()}';

            final paymentId = reg.paymentId.isNotEmpty
                ? reg.paymentId
                : (widget.event.isPaid ? 'PAID-ONLINE' : 'FREE');

            final bool isAttended = reg.isAttended;
            final bool isCancelled = reg.isCancelled;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                children: [
                  // HEADER STATUS CHIP
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isCancelled
                          ? AppColors.pinkLight
                          : (isAttended
                              ? AppColors.mintLight
                              : AppColors.lavenderLight),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCancelled
                            ? AppColors.pink
                            : (isAttended
                                ? AppColors.mint
                                : AppColors.lavender),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCancelled
                              ? Icons.cancel_outlined
                              : (isAttended
                                  ? Icons.verified_rounded
                                  : Icons.confirmation_number_outlined),
                          size: 18,
                          color: isCancelled
                              ? AppColors.pinkDark
                              : (isAttended
                                  ? AppColors.mintDark
                                  : AppColors.lavenderDark),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCancelled
                              ? 'REGISTRATION CANCELLED / VOID'
                              : (isAttended
                                  ? 'ATTENDANCE VERIFIED ✓'
                                  : 'OFFICIAL ADMISSION TICKET'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCancelled
                                ? AppColors.pinkDark
                                : (isAttended
                                    ? AppColors.mintDark
                                    : AppColors.lavenderDark),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // DIGITAL TICKET CARD
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // TICKET TOP: EVENT INFO
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFFFDED6),
                                Color(0xFFE5E1FD),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(23),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardWhite.withValues(
                                        alpha: 0.85,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      widget.event.category.toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.textMain,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formattedRegId,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.event.title,
                                style: const TextStyle(
                                  color: AppColors.textMain,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.event.dateFormatted,
                                    style: const TextStyle(
                                      color: AppColors.textMain,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.event.time,
                                    style: const TextStyle(
                                      color: AppColors.textMain,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      widget.event.venue,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // CUTOUT TEAR LINE
                        Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 32,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(16),
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                              ),
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Flex(
                                    direction: Axis.horizontal,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.max,
                                    children: List.generate(
                                      (constraints.constrainWidth() / 10)
                                          .floor(),
                                      (_) => const SizedBox(
                                        width: 5,
                                        height: 1.5,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: AppColors.border,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(
                              width: 16,
                              height: 32,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(16),
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // TICKET DETAILS: ATTENDEE & REGISTRATION INFO (NO QR CODE)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTicketField(
                                'Attendee Name',
                                reg.studentName,
                                isBold: true,
                              ),
                              _buildTicketField(
                                'Student ID / Roll',
                                reg.rollNumber,
                              ),
                              _buildTicketField(
                                'Branch / Dept',
                                '${reg.department} (${reg.section})',
                              ),
                              _buildTicketField(
                                'Academic Year',
                                reg.year,
                              ),
                              _buildTicketField(
                                'Payment Status',
                                reg.isPaid
                                    ? 'PAID ✓'
                                    : (widget.event.isPaid
                                        ? 'PENDING'
                                        : 'FREE'),
                                valueColor: reg.isPaid
                                    ? AppColors.mintDark
                                    : (widget.event.isPaid
                                        ? AppColors.yellowDark
                                        : AppColors.lavenderDark),
                                isBold: true,
                              ),
                              if (reg.isPaid)
                                _buildTicketField(
                                  'Payment Reference',
                                  paymentId,
                                ),
                              _buildTicketField(
                                'Attendance Status',
                                isAttended
                                    ? 'ATTENDANCE VERIFIED ✓'
                                    : 'NOT YET ATTENDED',
                                valueColor: isAttended
                                    ? AppColors.mintDark
                                    : AppColors.yellowDark,
                                isBold: true,
                              ),
                              if (reg.attendedAt != null)
                                _buildTicketField(
                                  'Checked-In At',
                                  DateFormatter.formatDate(reg.attendedAt!),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // NAVIGATION ACTION BUTTONS
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MainScreen(
                              initialIndex: 2,
                            ), // Index 2: My Events
                          ),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.confirmation_number_outlined),
                      label: const Text(
                        'View All My Registrations',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MainScreen(
                              initialIndex: 1,
                            ), // Index 1: Events
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text('Back to Explore Events'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTicketField(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Flexible(
            child: Text(
              value.isNotEmpty ? value : 'Not provided',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? AppColors.textMain,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
