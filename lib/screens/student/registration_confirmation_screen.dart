import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../models/whatsapp_notification_model.dart';
import '../../services/registration_service.dart';
import '../../services/whatsapp_service.dart';
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
  final WhatsAppService _whatsAppService = WhatsAppService();

  String _activeTicketToken = '';
  bool _isSharingWhatsApp = false;
  bool _isSendingCloudApi = false;
  String _selectedDeliveryMode = 'manual'; // 'manual' | 'cloud_api'

  @override
  void initState() {
    super.initState();
    _activeTicketToken = widget.registration.ticketToken;
    _selectedDeliveryMode = widget.registration.whatsappDeliveryMode.isNotEmpty
        ? widget.registration.whatsappDeliveryMode
        : 'manual';
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

  Future<void> _handleManualWhatsAppShare(RegistrationModel reg) async {
    if (_isSharingWhatsApp) return;

    setState(() => _isSharingWhatsApp = true);

    final targetReg = reg.ticketToken.isNotEmpty
        ? reg
        : reg.copyWith(ticketToken: _activeTicketToken);

    final result = await _whatsAppService.shareTicketOnWhatsApp(
      registration: targetReg,
      event: widget.event,
    );

    if (mounted) {
      setState(() {
        _isSharingWhatsApp = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.info_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor:
              result.success ? AppColors.mintDark : AppColors.coral,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _handleCloudApiSend(RegistrationModel reg) async {
    if (_isSendingCloudApi) return;

    if (!reg.whatsappConsent) {
      _showConsentModal(reg);
      return;
    }

    setState(() => _isSendingCloudApi = true);

    final targetReg = reg.ticketToken.isNotEmpty
        ? reg
        : reg.copyWith(ticketToken: _activeTicketToken);

    final result = await _whatsAppService.sendCloudApiWhatsAppNotification(
      registration: targetReg,
      event: widget.event,
    );

    if (mounted) {
      setState(() {
        _isSendingCloudApi = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.success ? Icons.cloud_done : Icons.error_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor:
              result.success ? AppColors.lavenderDark : AppColors.pinkDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _copyTicketDetails(RegistrationModel reg) {
    final message = WhatsAppService.buildTicketMessage(
      registration: reg.ticketToken.isNotEmpty
          ? reg
          : reg.copyWith(ticketToken: _activeTicketToken),
      event: widget.event,
    );

    Clipboard.setData(ClipboardData(text: message));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.copy_all, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Ticket details copied to clipboard!'),
          ],
        ),
        backgroundColor: AppColors.textMain,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showConsentModal(RegistrationModel reg) {
    final phoneCtrl = TextEditingController(
      text: reg.whatsappNumber.isNotEmpty ? reg.whatsappNumber : reg.phone,
    );
    bool consent = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
              decoration: const BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppColors.mintDark,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'WhatsApp Notification Preference',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp Mobile Number',
                      hintText: '+91 9876543210',
                      prefixIcon: Icon(Icons.phone_android),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: consent,
                          activeColor: AppColors.coral,
                          onChanged: (v) {
                            setModalState(() => consent = v ?? false);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'I agree to receive WhatsApp messages about my event registration and ticket.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final String num = phoneCtrl.text.trim();
                        if (num.isNotEmpty) {
                          await _registrationService.updateWhatsAppStatus(
                            registrationId: reg.id,
                            whatsappNumber: num,
                            whatsappConsent: consent,
                            whatsappStatus: consent ? 'ready_to_share' : 'none',
                          );
                        }
                        if (context.mounted) {
                          Navigator.pop(sheetContext);
                        }
                      },
                      child: const Text('Save & Update Preferences'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
            final ticketToken = reg.ticketToken.isNotEmpty
                ? reg.ticketToken
                : _activeTicketToken;

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

                        // TICKET MIDDLE: QR CODE DISPLAY
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Column(
                            children: [
                              if (isCancelled)
                                Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: AppColors.pinkLight,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: AppColors.pink,
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.block,
                                        size: 54,
                                        color: AppColors.pinkDark,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'TICKET VOID',
                                        style: TextStyle(
                                          color: AppColors.pinkDark,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Registration was cancelled',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.cardWhite,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: isAttended
                                              ? AppColors.mint
                                              : AppColors.border,
                                          width: 2,
                                        ),
                                      ),
                                      child: ticketToken.isEmpty
                                          ? const SizedBox(
                                              width: 190,
                                              height: 190,
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(
                                                  color: AppColors.coral,
                                                ),
                                              ),
                                            )
                                          : QrImageView(
                                              data: ticketToken,
                                              version: QrVersions.auto,
                                              size: 190,
                                              backgroundColor: Colors.white,
                                              eyeStyle: QrEyeStyle(
                                                eyeShape: QrEyeShape.square,
                                                color: isAttended
                                                    ? AppColors.mintDark
                                                    : AppColors.textMain,
                                              ),
                                              dataModuleStyle:
                                                  QrDataModuleStyle(
                                                dataModuleShape:
                                                    QrDataModuleShape.square,
                                                color: isAttended
                                                    ? AppColors.mintDark
                                                    : AppColors.textMain,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isAttended
                                          ? '✓ Checked-In by Event Admin'
                                          : 'Scan at the venue entrance to check in',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isAttended
                                            ? AppColors.mintDark
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),

                              const SizedBox(height: 16),
                              const Divider(height: 1, color: AppColors.border),
                              const SizedBox(height: 14),

                              // TICKET BOTTOM: PARTICIPANT DETAILS
                              _buildTicketField(
                                'Attendee Name',
                                reg.studentName,
                              ),
                              _buildTicketField(
                                'Student ID / Roll',
                                reg.rollNumber,
                              ),
                              _buildTicketField(
                                'Branch / Dept',
                                '${reg.department} (${reg.section})',
                              ),
                              _buildTicketField('Academic Year', reg.year),
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

                  const SizedBox(height: 20),

                  // WHATSAPP EVENT CONFIRMATION & DIGITAL TICKET CARD
                  _buildWhatsAppConfirmationSection(reg),

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

  Widget _buildWhatsAppConfirmationSection(RegistrationModel reg) {
    final String targetNumber = reg.whatsappNumber.isNotEmpty
        ? reg.whatsappNumber
        : reg.phone;
    final String cleanRecipient = WhatsAppService.normalizeForWaMe(targetNumber);

    return StreamBuilder<WhatsAppNotificationModel?>(
      stream: _whatsAppService.streamNotificationLog(reg.id),
      builder: (context, notifSnapshot) {
        final notifLog = notifSnapshot.data;
        final String currentStatus = notifLog?.status ?? reg.whatsappStatus;
        final String? providerMessageId = notifLog?.providerMessageId ??
            (reg.whatsappMessageId.isNotEmpty ? reg.whatsappMessageId : null);
        final String? notifErr = notifLog?.lastError;
        final String? lastError = (notifErr != null && notifErr.isNotEmpty)
            ? notifErr
            : (reg.whatsappError.isNotEmpty ? reg.whatsappError : null);

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CARD HEADER
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.mintLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.mint),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: AppColors.mintDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WhatsApp Confirmation & Ticket',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cleanRecipient.isNotEmpty
                              ? 'Recipient: +$cleanRecipient (Student)'
                              : 'No WhatsApp number provided',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: reg.whatsappConsent
                          ? AppColors.mintLight
                          : AppColors.yellowLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: reg.whatsappConsent
                            ? AppColors.mint
                            : AppColors.sunnyYellow,
                      ),
                    ),
                    child: Text(
                      reg.whatsappConsent ? 'CONSENTED' : 'NO CONSENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: reg.whatsappConsent
                            ? AppColors.mintDark
                            : AppColors.yellowDark,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // DELIVERY MODE SELECTOR TABS
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedDeliveryMode = 'manual'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedDeliveryMode == 'manual'
                                ? AppColors.cardWhite
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedDeliveryMode == 'manual'
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Mode A: Quick Share',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _selectedDeliveryMode == 'manual'
                                    ? AppColors.coral
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedDeliveryMode = 'cloud_api'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedDeliveryMode == 'cloud_api'
                                ? AppColors.cardWhite
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedDeliveryMode == 'cloud_api'
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Mode B: Cloud API',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _selectedDeliveryMode == 'cloud_api'
                                    ? AppColors.lavender
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // MODE SPECIFIC ACTIONS & STATUS
              if (_selectedDeliveryMode == 'manual') ...[
                Text(
                  'Opens WhatsApp with the confirmed ticket prefilled for recipient +$cleanRecipient. Note: You must press Send in WhatsApp.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: _isSharingWhatsApp
                            ? null
                            : () => _handleManualWhatsAppShare(reg),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isSharingWhatsApp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: const Text(
                          'Share Ticket on WhatsApp',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () => _copyTicketDetails(reg),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Icon(Icons.copy, size: 18),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // CLOUD API INFO & ROLES
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildConfigRow('Sender Role', 'College WhatsApp Business Account'),
                      const SizedBox(height: 4),
                      _buildConfigRow(
                        'Recipient',
                        cleanRecipient.isNotEmpty ? '+$cleanRecipient' : 'Not provided',
                        isBold: true,
                      ),
                      const SizedBox(height: 4),
                      _buildConfigRow('Template', 'event_registration_confirmation'),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // REAL-TIME CLOUD API STATUS PILL
                if (currentStatus != 'none') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(currentStatus),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusBorderColor(currentStatus)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getStatusIcon(currentStatus),
                              size: 16,
                              color: _getStatusTextColor(currentStatus),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getStatusTitle(currentStatus),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getStatusTextColor(currentStatus),
                              ),
                            ),
                          ],
                        ),
                        if (providerMessageId != null && providerMessageId.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Provider ID: $providerMessageId',
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (lastError != null && lastError.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            lastError,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.pinkDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSendingCloudApi
                        ? null
                        : () => _handleCloudApiSend(reg),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lavender,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isSendingCloudApi
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: Text(
                      reg.whatsappConsent
                          ? (currentStatus == 'failed' || currentStatus == 'unconfigured'
                              ? 'Retry via WhatsApp Cloud API'
                              : 'Send via WhatsApp Cloud API')
                          : 'Provide Consent & Send',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],

              if (!reg.whatsappConsent) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _showConsentModal(reg),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          size: 14,
                          color: AppColors.coral,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Update WhatsApp Number or Consent Settings',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.coral,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfigRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: AppColors.textMain,
          ),
        ),
      ],
    );
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'delivered':
      case 'read':
        return AppColors.mintLight;
      case 'accepted':
        return AppColors.lavenderLight;
      case 'pending':
      case 'queued':
      case 'ready_to_share':
        return AppColors.yellowLight;
      case 'failed':
      case 'unconfigured':
      case 'no_consent':
      default:
        return AppColors.pinkLight;
    }
  }

  Color _getStatusBorderColor(String status) {
    switch (status) {
      case 'delivered':
      case 'read':
        return AppColors.mint;
      case 'accepted':
        return AppColors.lavender;
      case 'pending':
      case 'queued':
      case 'ready_to_share':
        return AppColors.sunnyYellow;
      case 'failed':
      case 'unconfigured':
      case 'no_consent':
      default:
        return AppColors.pink;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'delivered':
      case 'read':
        return AppColors.mintDark;
      case 'accepted':
        return AppColors.lavenderDark;
      case 'pending':
      case 'queued':
      case 'ready_to_share':
        return AppColors.yellowDark;
      case 'failed':
      case 'unconfigured':
      case 'no_consent':
      default:
        return AppColors.pinkDark;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'delivered':
      case 'read':
        return Icons.done_all_rounded;
      case 'accepted':
        return Icons.check_circle_outline_rounded;
      case 'pending':
      case 'queued':
        return Icons.hourglass_top_rounded;
      case 'ready_to_share':
        return Icons.send_rounded;
      case 'unconfigured':
        return Icons.vpn_key_outlined;
      case 'failed':
      default:
        return Icons.error_outline_rounded;
    }
  }

  String _getStatusTitle(String status) {
    switch (status) {
      case 'delivered':
        return 'Delivered to Student Device ✓';
      case 'read':
        return 'Read by Student ✓';
      case 'accepted':
        return 'Accepted by Meta WhatsApp Platform';
      case 'queued':
        return 'Queued in Firestore (Awaiting Cloud Function)';
      case 'pending':
        return 'Processing Cloud API Request...';
      case 'ready_to_share':
        return 'Ready to Share via WhatsApp';
      case 'unconfigured':
        return 'Cloud API Credentials Needed in Firebase Secrets';
      case 'failed':
        return 'Delivery Attempt Failed';
      default:
        return 'Notification Status: ${status.toUpperCase()}';
    }
  }

  Widget _buildTicketField(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
