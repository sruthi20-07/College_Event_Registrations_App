import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/attendance_session_model.dart';
import '../../models/event_model.dart';
import '../../services/registration_service.dart';
import '../../utils/constants.dart';

class EventLiveAttendanceQrScreen extends StatefulWidget {
  final EventModel event;
  final AttendanceSessionModel? initialSession;

  const EventLiveAttendanceQrScreen({
    super.key,
    required this.event,
    this.initialSession,
  });

  @override
  State<EventLiveAttendanceQrScreen> createState() =>
      _EventLiveAttendanceQrScreenState();
}

class _EventLiveAttendanceQrScreenState
    extends State<EventLiveAttendanceQrScreen>
    with SingleTickerProviderStateMixin {
  final RegistrationService _registrationService = RegistrationService();

  AttendanceSessionModel? _currentSession;
  AttendanceQrPayload? _currentPayload;
  bool _isLoading = true;
  bool _isRotating = false;
  bool _isSessionEndedManually = false;
  int _refreshIntervalSeconds = 15;
  Timer? _rotationTimer;
  Timer? _countdownTimer;
  int _secondsRemaining = 15;
  bool _isFullscreen = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.initialSession != null) {
      _currentSession = widget.initialSession;
      _refreshIntervalSeconds = widget.initialSession!.refreshIntervalSeconds;
      _currentPayload = AttendanceQrPayload(
        eventId: widget.event.id,
        sessionId: widget.initialSession!.id,
        nonce: widget.initialSession!.currentNonce.isNotEmpty
            ? widget.initialSession!.currentNonce
            : 'test_nonce_abc',
        hash: widget.initialSession!.currentHash.isNotEmpty
            ? widget.initialSession!.currentHash
            : 'test_hash_123',
      );
      _isLoading = false;
      _startAutoRotation();
    } else {
      _loadOrInitSession();
    }
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadOrInitSession() async {
    setState(() => _isLoading = true);
    try {
      // 1. Check if there is an existing active session in Firestore for this event
      final activeQuery = await _registrationService
          .streamActiveAttendanceSessionForEvent(widget.event.id)
          .first;

      if (activeQuery != null && activeQuery.isActive) {
        _currentSession = activeQuery;
        _refreshIntervalSeconds = activeQuery.refreshIntervalSeconds;
        await _generatePayloadForSession();
        _startAutoRotation();
      } else if (!_isSessionEndedManually) {
        // Automatically start an active session for this event so admin immediately sees live QR
        final session = await _registrationService.startAttendanceSession(
          eventId: widget.event.id,
          eventTitle: widget.event.title,
          refreshIntervalSeconds: _refreshIntervalSeconds,
        );
        _currentSession = session;
        await _generatePayloadForSession();
        _startAutoRotation();
      }
    } catch (e) {
      debugPrint('Error loading or initializing attendance session: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startNewSession() async {
    setState(() {
      _isLoading = true;
      _isSessionEndedManually = false;
    });
    try {
      final session = await _registrationService.startAttendanceSession(
        eventId: widget.event.id,
        eventTitle: widget.event.title,
        refreshIntervalSeconds: _refreshIntervalSeconds,
      );
      _currentSession = session;
      await _generatePayloadForSession();
      _startAutoRotation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Live Attendance Session Started!'),
              ],
            ),
            backgroundColor: AppColors.sageDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start session: $e'),
            backgroundColor: AppColors.pinkDark,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePayloadForSession() async {
    if (_currentSession == null || !_currentSession!.isActive) return;
    try {
      final payload = await _registrationService.rotateSessionToken(
        sessionId: _currentSession!.id,
        eventId: widget.event.id,
        refreshIntervalSeconds: _refreshIntervalSeconds,
      );
      if (mounted) {
        setState(() {
          _currentPayload = payload;
          _secondsRemaining = _refreshIntervalSeconds;
        });
      }
    } catch (e) {
      debugPrint('Error rotating token: $e');
    }
  }

  void _startAutoRotation() {
    _rotationTimer?.cancel();
    _countdownTimer?.cancel();

    _secondsRemaining = _refreshIntervalSeconds;

    // Countdown tick timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      }
    });

    // Auto-rotation timer
    _rotationTimer = Timer.periodic(
      Duration(seconds: _refreshIntervalSeconds),
      (_) async {
        if (!mounted || _currentSession == null || !_currentSession!.isActive) {
          return;
        }
        setState(() => _isRotating = true);
        await _generatePayloadForSession();
        if (mounted) {
          setState(() => _isRotating = false);
        }
      },
    );
  }

  Future<void> _stopSession() async {
    if (_currentSession == null || !_currentSession!.isActive) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.coral),
            SizedBox(width: 8),
            Text('End Session?'),
          ],
        ),
        content: Text(
          'Are you sure you want to end attendance for "${widget.event.title}"? All live QR codes will be immediately invalidated and subsequent student check-in attempts will be rejected.',
          style: const TextStyle(height: 1.4, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _registrationService.stopAttendanceSession(_currentSession!.id);
      _rotationTimer?.cancel();
      _countdownTimer?.cancel();
      _isSessionEndedManually = true;
      if (mounted) {
        setState(() {
          _currentSession = _currentSession!.copyWith(
            isActive: false,
            closedAt: DateTime.now(),
          );
          _currentPayload = null;
          if (_isFullscreen) _isFullscreen = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Attendance session ended successfully.'),
              ],
            ),
            backgroundColor: AppColors.textSecondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error closing session: $e'),
            backgroundColor: AppColors.pinkDark,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rotateNow() async {
    if (_currentSession == null || !_currentSession!.isActive || _isRotating) {
      return;
    }
    setState(() => _isRotating = true);
    await _generatePayloadForSession();
    _startAutoRotation();
    if (mounted) {
      setState(() => _isRotating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return _buildFullscreenProjectorView();
    }

    final isSessionActive =
        _currentSession != null && _currentSession!.isActive;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Event List',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Live Event Attendance QR',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
          ),
        ),
        backgroundColor: AppColors.cardWhite,
        foregroundColor: AppColors.textMain,
        elevation: 0,
        actions: [
          if (isSessionActive) ...[
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.sageDark),
              tooltip: 'Rotate Now',
              onPressed: _rotateNow,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.lavenderDark),
            )
          : StreamBuilder<AttendanceSessionModel?>(
              stream: _currentSession != null && widget.initialSession == null
                  ? _registrationService.streamAttendanceSession(
                      _currentSession!.id,
                    )
                  : Stream.value(_currentSession),
              builder: (context, snapshot) {
                final session = snapshot.data ?? _currentSession;
                final bool isActive = session != null && session.isActive;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. PROMINENT EVENT HEADER CARD
                          _buildEventHeaderCard(),
                          const SizedBox(height: 18),

                          // 2. LIVE QR CARD OR INACTIVE STATE CARD
                          if (!isActive) ...[
                            _buildInactiveSessionCard(session),
                          ] else ...[
                            _buildActiveQrCard(session),
                            const SizedBox(height: 18),
                            // 3. ATTENDANCE STATISTICS
                            _buildSessionStats(session),
                            const SizedBox(height: 18),
                            // 4. ACTION BUTTONS (END SESSION & PROJECTOR MODE)
                            _buildBottomControls(),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEventHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CATEGORY & STATUS ROW
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lavenderLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.pastelLavender),
                ),
                child: Text(
                  widget.event.category.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.lavenderDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              if (widget.event.organizer.isNotEmpty)
                Text(
                  widget.event.organizer,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // PROMINENT EVENT TITLE
          Text(
            widget.event.title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // DATE & VENUE
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                widget.event.dateFormatted,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (widget.event.venue.isNotEmpty) ...[
                const SizedBox(width: 14),
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    widget.event.venue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveQrCard(AttendanceSessionModel session) {
    final payloadString = _currentPayload?.toRawString() ?? '';
    final progress = _refreshIntervalSeconds > 0
        ? _secondsRemaining / _refreshIntervalSeconds
        : 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.sageDark.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.sageDark.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // STATUS & COUNTDOWN HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // GREEN LIVE ATTENDANCE BADGE
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.pastelSage.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.sageDark.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      size: 10,
                      color: AppColors.sageDark,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'LIVE ATTENDANCE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sageDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // COUNTDOWN INDICATOR
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: 2.5,
                      color: _secondsRemaining <= 3
                          ? AppColors.coral
                          : AppColors.sageDark,
                      backgroundColor: AppColors.border,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rotates in ${_secondsRemaining}s',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _secondsRemaining <= 3
                          ? AppColors.coral
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // LARGE ROTATING QR CODE DISPLAY
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: payloadString.isNotEmpty
                  ? QrImageView(
                      data: payloadString,
                      version: QrVersions.auto,
                      size: 240.0,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.textMain,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppColors.textMain,
                      ),
                    )
                  : const SizedBox(
                      width: 240,
                      height: 240,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.lavenderDark,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // CRYPTOGRAPHIC TOKEN SECURITY INDICATOR
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 14,
                color: AppColors.lavenderDark,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Cryptographic Token • Nonce: ${_currentPayload?.nonce.isNotEmpty == true && _currentPayload!.nonce.length >= 6 ? _currentPayload!.nonce.substring(0, 6) : '...'} • HMAC',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStats(AttendanceSessionModel session) {
    final maxSeatsDisplay = widget.event.maxSeats > 0
        ? '${widget.event.maxSeats}'
        : 'Unlimited';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. VERIFIED ATTENDEES
          _buildCompactStat(
            label: 'Verified Attendees',
            value: '${session.attendeeCount}',
            color: AppColors.sageDark,
            icon: Icons.check_circle_outline,
          ),
          Container(width: 1, height: 38, color: AppColors.border),

          // 2. ROTATION INTERVAL
          _buildCompactStat(
            label: 'Interval',
            value: '${session.refreshIntervalSeconds}s',
            color: AppColors.lavenderDark,
            icon: Icons.timer_outlined,
          ),
          Container(width: 1, height: 38, color: AppColors.border),

          // 3. MAX SEATS
          _buildCompactStat(
            label: 'Max Seats',
            value: maxSeatsDisplay,
            color: AppColors.textSecondary,
            icon: Icons.people_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Row(
      children: [
        // END SESSION BUTTON
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.coral,
              side: const BorderSide(color: AppColors.coral, width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _stopSession,
            icon: const Icon(Icons.stop_circle_outlined, size: 19),
            label: const Text(
              'End Session',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // PROJECTOR MODE BUTTON
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lavenderDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: () => setState(() => _isFullscreen = true),
            icon: const Icon(Icons.fullscreen, size: 20),
            label: const Text(
              'Projector Mode',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInactiveSessionCard(AttendanceSessionModel? session) {
    final attendeeCount = session?.attendeeCount ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_clock_rounded,
              size: 48,
              color: AppColors.coral,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Attendance Session Ended',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Attendance for "${widget.event.title}" is currently closed. Live QR codes have been deactivated and tokens from this session are rejected.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // FINAL VERIFIED ATTENDEES SUMMARY
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: AppColors.sageDark,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Final Verified Attendees: $attendeeCount',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textMain,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // START NEW SESSION BUTTON
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sageDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: _startNewSession,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text(
              'Start New Session',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenProjectorView() {
    final payloadString = _currentPayload?.toRawString() ?? '';
    final progress = _refreshIntervalSeconds > 0
        ? _secondsRemaining / _refreshIntervalSeconds
        : 1.0;
    final isSessionActive =
        _currentSession != null && _currentSession!.isActive;

    return Scaffold(
      backgroundColor: const Color(0xFF13131A),
      body: SafeArea(
        child: Stack(
          children: [
            // EXIT PROJECTOR MODE BUTTON (TOP RIGHT)
            Positioned(
              top: 16,
              right: 18,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                onPressed: () => setState(() => _isFullscreen = false),
                icon: const Icon(Icons.fullscreen_exit, size: 18),
                label: const Text(
                  'Exit Projector',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            // MAIN PRESENTATION CONTENT
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // EVENT TITLE
                    Text(
                      widget.event.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // EVENT DETAILS
                    Text(
                      '${widget.event.category} • ${widget.event.dateFormatted}${widget.event.venue.isNotEmpty ? ' • ${widget.event.venue}' : ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (isSessionActive) ...[
                      // HIGH CONTRAST QR CONTAINER
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.12),
                              blurRadius: 36,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: payloadString.isNotEmpty
                            ? QrImageView(
                                data: payloadString,
                                version: QrVersions.auto,
                                size: 300.0,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Colors.black,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Colors.black,
                                ),
                              )
                            : const SizedBox(
                                width: 300,
                                height: 300,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 24),

                      // LIVE BADGE & COUNTDOWN
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.sageDark.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.sageDark,
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fiber_manual_record,
                                  size: 10,
                                  color: Colors.lightGreenAccent,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              strokeWidth: 2.5,
                              color: Colors.amberAccent,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Rotating in ${_secondsRemaining}s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // INSTRUCTION
                      const Text(
                        'Open Student App and scan this QR code to mark attendance',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ] else ...[
                      // SESSION INACTIVE IN PROJECTOR
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.lock_clock_rounded,
                              size: 48,
                              color: AppColors.coral,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Attendance Session Ended',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'This session has been closed. Live QR codes are deactivated.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
