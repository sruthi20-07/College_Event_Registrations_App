import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/attendance_scan_result.dart';
import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../services/registration_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_formatter.dart';

class QrScannerScreen extends StatefulWidget {
  final EventModel? event;

  const QrScannerScreen({super.key, this.event});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final RegistrationService _registrationService = RegistrationService();
  late final MobileScannerController _scannerController;

  bool _isProcessing = false;
  bool _isTorchOn = false;
  CameraFacing _currentFacing = CameraFacing.back;
  String _lastScannedValue = '';
  DateTime? _lastScanTimestamp;

  final TextEditingController _manualInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _manualInputController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    final String cleanValue = rawValue.trim();

    // Debounce duplicate scans within 2.5 seconds
    final now = DateTime.now();
    if (_lastScannedValue == cleanValue &&
        _lastScanTimestamp != null &&
        now.difference(_lastScanTimestamp!).inMilliseconds < 2500) {
      return;
    }

    _lastScannedValue = cleanValue;
    _lastScanTimestamp = now;

    await _processTicketVerification(cleanValue);
  }

  Future<void> _processTicketVerification(String rawToken) async {
    if (!mounted || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    // Pause camera scanning during verification
    try {
      await _scannerController.stop();
    } catch (_) {}

    // Show loading modal
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            color: AppColors.cardWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.sageDark,
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'Verifying Ticket...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textMain,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Validating against Firestore',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    AttendanceScanResult result;
    try {
      result = await _registrationService.verifyAndRecordAttendance(
        rawToken: rawToken,
        expectedEventId: widget.event?.id,
      );
    } catch (e) {
      result = AttendanceScanResult(
        status: AttendanceScanStatus.error,
        message: 'Network or server error: ${e.toString()}',
      );
    }

    // Dismiss loading dialog
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // Show Result Dialog
    if (!mounted) return;
    await _showScanResultDialog(result, rawToken);

    // Resume camera scanning after dialog is closed
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      try {
        await _scannerController.start();
      } catch (_) {}
    }
  }

  Future<void> _showScanResultDialog(
    AttendanceScanResult result,
    String rawToken,
  ) async {
    Color themeColor;
    Color themeBg;
    IconData statusIcon;

    switch (result.status) {
      case AttendanceScanStatus.verified:
        themeColor = AppColors.sageDark;
        themeBg = AppColors.sageLight;
        statusIcon = Icons.check_circle_outline;
        break;
      case AttendanceScanStatus.alreadyCheckedIn:
        themeColor = AppColors.peachDark;
        themeBg = AppColors.peachLight;
        statusIcon = Icons.history;
        break;
      case AttendanceScanStatus.wrongEvent:
        themeColor = AppColors.pinkDark;
        themeBg = AppColors.pinkLight;
        statusIcon = Icons.wrong_location_outlined;
        break;
      case AttendanceScanStatus.registrationCancelled:
        themeColor = AppColors.pinkDark;
        themeBg = AppColors.pinkLight;
        statusIcon = Icons.cancel_outlined;
        break;
      case AttendanceScanStatus.paymentPending:
        themeColor = AppColors.peachDark;
        themeBg = AppColors.peachLight;
        statusIcon = Icons.pending_actions_outlined;
        break;
      case AttendanceScanStatus.unauthorizedAdmin:
        themeColor = AppColors.lavenderDark;
        themeBg = AppColors.lavenderLight;
        statusIcon = Icons.admin_panel_settings_outlined;
        break;
      case AttendanceScanStatus.sessionExpired:
      case AttendanceScanStatus.sessionInactive:
      case AttendanceScanStatus.notRegistered:
      case AttendanceScanStatus.ineligible:
      case AttendanceScanStatus.invalidTicket:
      case AttendanceScanStatus.error:
        themeColor = AppColors.pinkDark;
        themeBg = AppColors.pinkLight;
        statusIcon = Icons.error_outline;
        break;
    }


    final reg = result.registration;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HANDLE BAR
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // STATUS ICON & BANNER
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, size: 48, color: themeColor),
              ),
              const SizedBox(height: 12),

              Text(
                result.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                result.message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),

              // STUDENT & REGISTRATION DETAILS CARD
              if (reg != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        'Student Name',
                        reg.studentName.isNotEmpty
                            ? reg.studentName
                            : 'Registered Student',
                        isBold: true,
                      ),
                      const Divider(height: 16, color: AppColors.border),
                      _buildDetailRow(
                        'Roll / Student ID',
                        reg.rollNumber.isNotEmpty ? reg.rollNumber : 'N/A',
                      ),
                      const Divider(height: 16, color: AppColors.border),
                      _buildDetailRow(
                        'Event',
                        reg.eventTitle.isNotEmpty
                            ? reg.eventTitle
                            : (widget.event?.title ?? 'College Event'),
                      ),
                      const Divider(height: 16, color: AppColors.border),
                      _buildDetailRow(
                        'Registration ID',
                        reg.id.length > 12
                            ? 'REG-${reg.id.substring(0, 10).toUpperCase()}'
                            : reg.id.toUpperCase(),
                      ),
                      const Divider(height: 16, color: AppColors.border),
                      _buildDetailRow(
                        'Department & Year',
                        '${reg.department} — ${reg.year}',
                      ),
                      const Divider(height: 16, color: AppColors.border),
                      _buildDetailRow(
                        'Payment Status',
                        reg.isPaid
                            ? 'PAID (₹${reg.amount.toInt()})'
                            : (reg.amount > 0 ? 'PENDING' : 'FREE EVENT'),
                        valueColor: reg.isPaid
                            ? AppColors.sageDark
                            : (reg.amount > 0 ? AppColors.peachDark : null),
                      ),
                      if (result.attendedAt != null) ...[
                        const Divider(height: 16, color: AppColors.border),
                        _buildDetailRow(
                          'Check-in Time',
                          DateFormatter.formatFullDateTime(result.attendedAt!),
                          valueColor: AppColors.sageDark,
                          isBold: true,
                        ),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primarySage,
                        foregroundColor: AppColors.sageDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      label: const Text(
                        'Done / Scan Next Ticket',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppColors.textMain,
            ),
          ),
        ),
      ],
    );
  }

  void _showManualTokenDialog() {
    _manualInputController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lavenderLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.keyboard_alt_outlined, color: AppColors.lavenderDark, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Manual Ticket Entry',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the ticket token or Registration ID printed on the student pass:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _manualInputController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'e.g. tkt_6a2b... or REG ID',
                  prefixIcon: Icon(Icons.pin, size: 20, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarySage,
                foregroundColor: AppColors.sageDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () {
                final token = _manualInputController.text.trim();
                if (token.isEmpty) return;
                Navigator.pop(dialogContext);
                _processTicketVerification(token);
              },
              child: const Text('Verify & Check In', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan Attendance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (widget.event != null)
              Text(
                widget.event!.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          // Flashlight Toggle
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.yellow : Colors.white,
            ),
            tooltip: 'Toggle Flash',
            onPressed: () async {
              try {
                await _scannerController.toggleTorch();
                setState(() {
                  _isTorchOn = !_isTorchOn;
                });
              } catch (_) {}
            },
          ),
          // Camera Switch Toggle
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            tooltip: 'Switch Camera',
            onPressed: () async {
              try {
                await _scannerController.switchCamera();
                setState(() {
                  _currentFacing = _currentFacing == CameraFacing.back
                      ? CameraFacing.front
                      : CameraFacing.back;
                });
              } catch (_) {}
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. MOBILE SCANNER CAMERA
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcodeDetected,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.pinkDark.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.videocam_off_outlined,
                          size: 48,
                          color: AppColors.pastelPink,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera Unavailable',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.errorCode ==
                                MobileScannerErrorCode.permissionDenied
                            ? 'Camera permission was denied. Please grant camera permission in your settings or use manual ticket token entry below.'
                            : 'Unable to start camera preview (${error.errorCode.name}). Please use manual entry to verify tickets.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primarySage,
                          foregroundColor: AppColors.sageDark,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _showManualTokenDialog,
                        icon: const Icon(Icons.keyboard_alt_outlined),
                        label: const Text('Enter Ticket Code Manually', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. SCAN VIEWFINDER OVERLAY
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primarySage, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Corner accents
                  Positioned(
                    top: -2,
                    left: -2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.white, width: 4),
                          left: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.white, width: 4),
                          right: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    left: -2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white, width: 4),
                          left: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white, width: 4),
                          right: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. TARGET INSTRUCTIONS BANNER
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code, color: AppColors.primarySage, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.event != null
                          ? 'Point camera at student QR pass for "${widget.event!.title}"'
                          : 'Point camera at student QR admission ticket',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. REAL-TIME EVENT ATTENDANCE STATS (IF EVENT SCOPED)
          if (widget.event != null)
            Positioned(
              bottom: 80,
              left: 20,
              right: 20,
              child: StreamBuilder<List<RegistrationModel>>(
                stream: _registrationService.streamEventRegistrations(
                  widget.event!.id,
                ),
                builder: (context, snapshot) {
                  final list = snapshot.data ?? [];
                  final active = list.where((r) => r.isRegistered).length;
                  final attended = list
                      .where((r) => r.isRegistered && r.isAttended)
                      .length;
                  final percentage = active > 0
                      ? ((attended / active) * 100).toInt()
                      : 0;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primarySage.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatPill(
                          'Active Regs',
                          '$active',
                          Colors.white70,
                        ),
                        _buildStatPill(
                          'Attended',
                          '$attended',
                          AppColors.primarySage,
                        ),
                        _buildStatPill(
                          'Pending',
                          '${active - attended}',
                          AppColors.pastelPeach,
                        ),
                        _buildStatPill(
                          'Turnout',
                          '$percentage%',
                          AppColors.pastelLavender,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // 5. MANUAL ENTRY BOTTOM BUTTON
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardWhite,
                  foregroundColor: AppColors.textMain,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                onPressed: _showManualTokenDialog,
                icon: const Icon(
                  Icons.keyboard_alt_outlined,
                  color: AppColors.sageDark,
                ),
                label: const Text(
                  'Enter Ticket ID / Token Manually',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String title, String val, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          val,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          title,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }
}
