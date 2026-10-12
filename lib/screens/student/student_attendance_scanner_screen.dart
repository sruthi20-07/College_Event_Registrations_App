import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/attendance_scan_result.dart';
import '../../services/registration_service.dart';
import '../../utils/constants.dart';

class StudentAttendanceScannerScreen extends StatefulWidget {
  const StudentAttendanceScannerScreen({super.key});

  @override
  State<StudentAttendanceScannerScreen> createState() =>
      _StudentAttendanceScannerScreenState();
}

class _StudentAttendanceScannerScreenState
    extends State<StudentAttendanceScannerScreen> {
  final RegistrationService _registrationService = RegistrationService();
  late final MobileScannerController _scannerController;

  bool _isProcessing = false;
  bool _hasPermissionError = false;
  String _permissionErrorMessage = '';
  bool _isTorchOn = false;

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
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    await _processQrData(rawValue.trim());
  }

  Future<void> _processQrData(String qrContent) async {
    try {
      final result = await _registrationService.recordStudentAttendanceViaQr(
        rawPayload: qrContent,
      );

      if (!mounted) return;
      _showResultDialog(result);
    } catch (e) {
      if (!mounted) return;
      _showResultDialog(
        AttendanceScanResult(
          status: AttendanceScanStatus.error,
          message: 'An unexpected error occurred: $e',
        ),
      );
    }
  }

  void _showResultDialog(AttendanceScanResult result) {
    Color headerColor;
    IconData headerIcon;

    switch (result.status) {
      case AttendanceScanStatus.verified:
        headerColor = AppColors.sageDark;
        headerIcon = Icons.check_circle_rounded;
        break;
      case AttendanceScanStatus.alreadyCheckedIn:
        headerColor = AppColors.lavenderDark;
        headerIcon = Icons.verified_user_rounded;
        break;
      case AttendanceScanStatus.sessionExpired:
        headerColor = AppColors.coral;
        headerIcon = Icons.timer_off_outlined;
        break;
      case AttendanceScanStatus.notRegistered:
        headerColor = AppColors.peachDark;
        headerIcon = Icons.app_registration_rounded;
        break;
      case AttendanceScanStatus.ineligible:
        headerColor = AppColors.pinkDark;
        headerIcon = Icons.block_rounded;
        break;
      case AttendanceScanStatus.sessionInactive:
        headerColor = AppColors.textSecondary;
        headerIcon = Icons.lock_clock_rounded;
        break;
      default:
        headerColor = AppColors.pinkDark;
        headerIcon = Icons.error_outline_rounded;
        break;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: headerColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(headerIcon, size: 48, color: headerColor),
            ),
            const SizedBox(height: 16),
            Text(
              result.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: headerColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              result.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (result.coinsEarned != null && result.coinsEarned! > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.coralLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.coral),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: AppColors.coral,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+${result.coinsEarned} Coins Earned! 🎉',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.coralDark,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                if (!result.isSuccess && !result.isAlreadyCheckedIn) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _isProcessing = false);
                      },
                      child: const Text('Scan Again'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: headerColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (result.isSuccess || result.isAlreadyCheckedIn) {
                        Navigator.pop(context, true); // Return to home
                      } else {
                        setState(() => _isProcessing = false);
                      }
                    },
                    child: Text(
                      result.isSuccess || result.isAlreadyCheckedIn
                          ? 'Done'
                          : 'Close',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showManualEntryDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter Token Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If your camera cannot scan the screen, paste the QR token payload below:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Paste attendance QR token JSON...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sageDark,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final text = textController.text.trim();
              Navigator.pop(ctx);
              if (text.isNotEmpty) {
                setState(() => _isProcessing = true);
                _processQrData(text);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // SCANNER CAMERA VIEW
          if (!_hasPermissionError)
            MobileScanner(
              controller: _scannerController,
              onDetect: _handleBarcode,
              errorBuilder: (context, error) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_hasPermissionError) {
                    setState(() {
                      _hasPermissionError = true;
                      _permissionErrorMessage = error.errorCode.name;
                    });
                  }
                });
                return _buildPermissionDeniedView();
              },
            )
          else
            _buildPermissionDeniedView(),

          // SCANNER OVERLAY FRAME & GUIDES
          if (!_hasPermissionError) _buildScannerOverlay(),

          // TOP APP BAR ACTIONS
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // BACK BUTTON
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // TITLE
                  const Text(
                    'Scan Event Attendance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // ACTIONS
                  Row(
                    children: [
                      // TORCH BUTTON
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isTorchOn ? Icons.flash_on : Icons.flash_off,
                            color: _isTorchOn
                                ? Colors.amberAccent
                                : Colors.white,
                          ),
                          onPressed: () async {
                            await _scannerController.toggleTorch();
                            setState(() => _isTorchOn = !_isTorchOn);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // MANUAL INPUT
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.keyboard, color: Colors.white),
                          tooltip: 'Manual Code Input',
                          onPressed: _showManualEntryDialog,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // PROCESSING INDICATOR
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.sageDark),
                      SizedBox(height: 16),
                      Text(
                        'Verifying Attendance...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.sageDark, width: 3),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.sageDark.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                // CORNER HIGHLIGHTS
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white, width: 4),
                        left: BorderSide(color: Colors.white, width: 4),
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white, width: 4),
                        right: BorderSide(color: Colors.white, width: 4),
                      ),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white, width: 4),
                        left: BorderSide(color: Colors.white, width: 4),
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white, width: 4),
                        right: BorderSide(color: Colors.white, width: 4),
                      ),
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Align the rotating event QR within the frame',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 54,
              color: AppColors.coral,
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera Permission Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _permissionErrorMessage.isNotEmpty
                  ? 'Unable to access camera ($_permissionErrorMessage). Please ensure camera permissions are enabled in browser/system settings.'
                  : 'Camera access is required to scan the live event attendance QR code. Please allow camera permissions or enter the code manually.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasPermissionError = false;
                      _permissionErrorMessage = '';
                    });
                    _scannerController.start();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sageDark,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _showManualEntryDialog,
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Enter Code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
