import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/registration_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_formatter.dart';
import '../../utils/excel_export_helper.dart';
import '../../utils/web_url_launcher.dart';
import '../../services/whatsapp_service.dart';
import 'event_live_attendance_qr_screen.dart';
import 'event_registration_report_screen.dart';

class EventParticipantsScreen extends StatefulWidget {
  final EventModel event;

  const EventParticipantsScreen({super.key, required this.event});

  @override
  State<EventParticipantsScreen> createState() =>
      _EventParticipantsScreenState();
}


class _EventParticipantsScreenState extends State<EventParticipantsScreen> {
  final RegistrationService _registrationService = RegistrationService();
  final AuthService _authService = AuthService();
  WhatsAppService get _whatsAppService => WhatsAppService();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All'; // All, Active, Cancelled
  String _paymentFilter = 'All'; // All, Paid, Pending
  String _attendanceFilter = 'All'; // All, Attended, Not Attended

  final Map<String, UserModel?> _userProfileCache = {};
  final Set<String> _loadingUserIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetchUserProfileIfNeeded(String studentId) {
    if (studentId.isEmpty ||
        _userProfileCache.containsKey(studentId) ||
        _loadingUserIds.contains(studentId)) {
      return;
    }

    _loadingUserIds.add(studentId);
    _authService
        .getUserProfile(studentId)
        .then((profile) {
          if (mounted) {
            setState(() {
              _userProfileCache[studentId] = profile;
              _loadingUserIds.remove(studentId);
            });
          }
        })
        .catchError((_) {
          if (mounted) {
            setState(() {
              _userProfileCache[studentId] = null;
              _loadingUserIds.remove(studentId);
            });
          }
        });
  }

  String _resolveField(String directValue, String? profileValue) {
    if (directValue.trim().isNotEmpty && directValue.trim() != 'N/A') {
      return directValue.trim();
    }
    if (profileValue != null &&
        profileValue.trim().isNotEmpty &&
        profileValue.trim() != 'N/A') {
      return profileValue.trim();
    }
    return 'Not provided';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Participants — ${widget.event.title}',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.cardWhite,
        foregroundColor: AppColors.textMain,
        elevation: 0,
      ),
      body: StreamBuilder<List<RegistrationModel>>(
        stream: _registrationService.streamEventRegistrations(widget.event.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.sageDark),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load participants: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.pinkDark),
                ),
              ),
            );
          }

          final allRegistrations = snapshot.data ?? [];

          // Trigger profile prefetch for any registration with missing fields
          for (final reg in allRegistrations) {
            if (reg.studentName.isEmpty ||
                reg.rollNumber.isEmpty ||
                reg.department.isEmpty) {
              _fetchUserProfileIfNeeded(reg.studentId);
            }
          }

          // Compute dynamic statistics from actual Firestore event registrations
          final int totalRegistrations = allRegistrations.length;
          final int activeRegistrations = allRegistrations
              .where((r) => r.isRegistered)
              .length;
          final int paidRegistrations = allRegistrations
              .where((r) => r.isRegistered && r.isPaid)
              .length;
          final int pendingPayments = allRegistrations.where((r) {
            if (!r.isRegistered) return false;
            if (r.isPaid) return false;
            return widget.event.isPaid ||
                r.paymentStatus == PaymentStatuses.pending;
          }).length;
          final int cancelledRegistrations = allRegistrations
              .where((r) => r.isCancelled)
              .length;
          final int verifiedAttendees = allRegistrations
              .where((r) => r.isRegistered && r.isAttended)
              .length;
          final int availableSeats =
              (widget.event.maxSeats - activeRegistrations).clamp(
                0,
                widget.event.maxSeats,
              );

          // Apply search & filters
          final filteredList = allRegistrations.where((reg) {
            final profile = _userProfileCache[reg.studentId];
            final name = _resolveField(
              reg.studentName,
              profile?.name,
            ).toLowerCase();
            final roll = _resolveField(
              reg.rollNumber,
              profile?.rollNumber,
            ).toLowerCase();
            final email = _resolveField(
              reg.studentEmail,
              profile?.email,
            ).toLowerCase();
            final regId = reg.id.toLowerCase();

            // Search filter
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final matchesSearch =
                  name.contains(query) ||
                  roll.contains(query) ||
                  email.contains(query) ||
                  regId.contains(query);
              if (!matchesSearch) return false;
            }

            // Status filter (Active / Cancelled)
            if (_statusFilter == 'Active' && !reg.isRegistered) {
              return false;
            }
            if (_statusFilter == 'Cancelled' && !reg.isCancelled) {
              return false;
            }

            // Payment filter (Paid / Pending)
            if (_paymentFilter == 'Paid' && !reg.isPaid) {
              return false;
            }
            if (_paymentFilter == 'Pending' && reg.isPaid) {
              return false;
            }

            // Attendance filter (Attended / Not Attended)
            if (_attendanceFilter == 'Attended' && !reg.isAttended) {
              return false;
            }
            if (_attendanceFilter == 'Not Attended' && reg.isAttended) {
              return false;
            }

            return true;
          }).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: CustomScrollView(
                slivers: [
                  // 1. EVENT INFO & DYNAMIC METRICS HEADER
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEventSummaryBanner(),
                          const SizedBox(height: 16),
                          _buildMetricsGrid(
                            totalRegistrations: totalRegistrations,
                            activeRegistrations: activeRegistrations,
                            paidRegistrations: paidRegistrations,
                            pendingPayments: pendingPayments,
                            cancelledRegistrations: cancelledRegistrations,
                            verifiedAttendees: verifiedAttendees,
                            availableSeats: availableSeats,
                          ),
                          const SizedBox(height: 18),
                          _buildSearchAndFilters(allRegistrations, filteredList),
                        ],
                      ),
                    ),
                  ),

                  // 2. PARTICIPANTS LIST / EMPTY STATE
                  if (allRegistrations.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyEventState(),
                    )
                  else if (filteredList.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildNoMatchesState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final reg = filteredList[index];
                          return _buildParticipantCard(reg);
                        }, childCount: filteredList.length),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildEventSummaryBanner() {
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.lavenderLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.event.category.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.lavenderDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.event.isPublished
                      ? AppColors.sageLight
                      : AppColors.pinkLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.event.status.toUpperCase(),
                  style: TextStyle(
                    color: widget.event.isPublished
                        ? AppColors.sageDark
                        : AppColors.pinkDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: AppColors.sageDark,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.event.dateFormatted,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: AppColors.peachDark,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.event.venue,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    size: 13,
                    color: AppColors.skyBlueDark,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.event.isPaid
                        ? 'Fee: ₹${widget.event.registrationFee.toInt()}'
                        : 'FREE Event',
                    style: TextStyle(
                      color: widget.event.isPaid
                          ? AppColors.skyBlueDark
                          : AppColors.sageDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Preserved single Display Event QR button inside event summary card
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lavenderLight,
                foregroundColor: AppColors.lavenderDark,
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventLiveAttendanceQrScreen(event: widget.event),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text(
                'Display Event QR',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid({
    required int totalRegistrations,
    required int activeRegistrations,
    required int paidRegistrations,
    required int pendingPayments,
    required int cancelledRegistrations,
    required int verifiedAttendees,
    required int availableSeats,
  }) {
    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width >= 800 ? 4 : (width >= 550 ? 3 : 2);

    final items = [
      _MetricData(
        title: 'Total Registrations',
        value: '$totalRegistrations',
        icon: Icons.groups_outlined,
        color: AppColors.lavenderDark,
        bgColor: AppColors.lavenderLight,
      ),
      _MetricData(
        title: 'Active Registrations',
        value: '$activeRegistrations',
        icon: Icons.check_circle_outline,
        color: AppColors.sageDark,
        bgColor: AppColors.sageLight,
      ),
      _MetricData(
        title: 'Verified Attendees',
        value: '$verifiedAttendees',
        icon: Icons.how_to_reg_outlined,
        color: AppColors.skyBlueDark,
        bgColor: AppColors.skyBlueLight,
      ),
      _MetricData(
        title: 'Paid Registrations',
        value: '$paidRegistrations',
        icon: Icons.paid_outlined,
        color: AppColors.mintDark,
        bgColor: AppColors.mintLight,
      ),
      _MetricData(
        title: 'Pending Payments',
        value: '$pendingPayments',
        icon: Icons.pending_actions_outlined,
        color: AppColors.peachDark,
        bgColor: AppColors.peachLight,
      ),
      _MetricData(
        title: 'Cancelled Registrations',
        value: '$cancelledRegistrations',
        icon: Icons.cancel_outlined,
        color: AppColors.pinkDark,
        bgColor: AppColors.pinkLight,
      ),
      _MetricData(
        title: 'Available Seats',
        value: '$availableSeats / ${widget.event.maxSeats}',
        icon: Icons.event_seat_outlined,
        color: availableSeats <= 0 ? AppColors.pinkDark : AppColors.textMain,
        bgColor: AppColors.background,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 64,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: item.bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 16, color: item.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: item.color,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters(
    List<RegistrationModel> allRegistrations,
    List<RegistrationModel> filteredList,
  ) {
    final bool hasActiveFilters =
        _searchQuery.isNotEmpty ||
        _statusFilter != 'All' ||
        _paymentFilter != 'All' ||
        _attendanceFilter != 'All';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // COMPACT SEARCH FIELD
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              hintText: 'Search student name, roll, email, or reg ID...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: AppColors.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 10),

          // FILTER CHIPS ROW
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildFilterPopup(
                label: 'Status: $_statusFilter',
                currentValue: _statusFilter,
                options: const ['All', 'Active', 'Cancelled'],
                onSelected: (val) => setState(() => _statusFilter = val),
              ),
              _buildFilterPopup(
                label: 'Payment: $_paymentFilter',
                currentValue: _paymentFilter,
                options: const ['All', 'Paid', 'Pending'],
                onSelected: (val) => setState(() => _paymentFilter = val),
              ),
              _buildFilterPopup(
                label: 'Attendance: $_attendanceFilter',
                currentValue: _attendanceFilter,
                options: const ['All', 'Attended', 'Not Attended'],
                onSelected: (val) => setState(() => _attendanceFilter = val),
              ),
              if (hasActiveFilters)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 28),
                  ),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _statusFilter = 'All';
                      _paymentFilter = 'All';
                      _attendanceFilter = 'All';
                    });
                  },
                  icon: const Icon(
                    Icons.filter_alt_off,
                    size: 14,
                    color: AppColors.pinkDark,
                  ),
                  label: const Text(
                    'Reset',
                    style: TextStyle(color: AppColors.pinkDark, fontSize: 11),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 6),

          // RESULT COUNT & EXPORT ACTIONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${filteredList.length} of ${allRegistrations.length} participants',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              if (filteredList.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        minimumSize: const Size(0, 28),
                      ),
                      onPressed: () => _exportExcel(context, filteredList),
                      icon: const Icon(
                        Icons.table_view_rounded,
                        size: 14,
                        color: AppColors.sageDark,
                      ),
                      label: const Text(
                        'Download Excel',
                        style: TextStyle(
                          color: AppColors.sageDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        size: 15,
                        color: AppColors.lavenderDark,
                      ),
                      tooltip: 'View Full Report Table',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventRegistrationReportScreen(
                              initialEvent: widget.event,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPopup({
    required String label,
    required String currentValue,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    final bool isFiltered = currentValue != 'All';
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => options
          .map(
            (opt) => PopupMenuItem<String>(
              value: opt,
              height: 38,
              child: Row(
                children: [
                  Icon(
                    opt == currentValue
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 15,
                    color: opt == currentValue
                        ? AppColors.sageDark
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(opt, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isFiltered ? AppColors.sageLight : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFiltered ? AppColors.primarySage : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isFiltered ? AppColors.sageDark : AppColors.textMain,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.arrow_drop_down,
              size: 15,
              color: isFiltered ? AppColors.sageDark : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantCard(RegistrationModel reg) {
    final profile = _userProfileCache[reg.studentId];

    final studentName = _resolveField(reg.studentName, profile?.name);
    final rollNumber = _resolveField(reg.rollNumber, profile?.rollNumber);
    final collegeEmail = _resolveField(reg.studentEmail, profile?.email);
    final department = _resolveField(reg.department, profile?.department);
    final year = _resolveField(reg.year, profile?.year);
    final regDate = DateFormatter.formatDate(reg.registeredAt);

    final formattedRegId = reg.id.length > 8
        ? 'REG-${reg.id.substring(0, 8).toUpperCase()}'
        : 'REG-${reg.id.toUpperCase()}';

    final isCancelled = reg.isCancelled;
    final isPaid = reg.isPaid;
    final isAttended = reg.isAttended;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showStudentDetailsModal(context, reg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TOP HEADER: NAME + ROLL + EMAIL
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: isCancelled
                          ? AppColors.pinkLight
                          : (isAttended
                              ? AppColors.mintLight
                              : AppColors.lavenderLight),
                      child: Icon(
                        isCancelled
                            ? Icons.cancel_outlined
                            : (isAttended
                                ? Icons.how_to_reg_rounded
                                : Icons.person_outline_rounded),
                        color: isCancelled
                            ? AppColors.pinkDark
                            : (isAttended
                                ? AppColors.mintDark
                                : AppColors.lavenderDark),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  studentName,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textMain,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                rollNumber,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '$department • $year • $collegeEmail',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Quick Attendance Toggle Action
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Icon(
                        isAttended
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isAttended
                            ? AppColors.mintDark
                            : AppColors.textSecondary.withValues(alpha: 0.5),
                        size: 22,
                      ),
                      tooltip: isAttended
                          ? 'Mark as Not Attended'
                          : 'Verify & Mark as Attended',
                      onPressed: () => _toggleAttendance(reg),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 7),

                // 1. STATUS BADGES & WHATSAPP STATUS ROW (Bounded Wrap, wraps without overflow)
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    _buildStatusBadge(
                      label: isCancelled ? 'CANCELLED' : 'ACTIVE',
                      color: isCancelled
                          ? AppColors.pinkDark
                          : AppColors.lavenderDark,
                      bgColor: isCancelled
                          ? AppColors.pinkLight
                          : AppColors.lavenderLight,
                    ),
                    _buildStatusBadge(
                      label: isPaid
                          ? 'PAID ✓'
                          : (widget.event.isPaid ? 'PENDING' : 'FREE'),
                      color: isPaid
                          ? AppColors.mintDark
                          : (widget.event.isPaid
                              ? AppColors.peachDark
                              : AppColors.skyBlueDark),
                      bgColor: isPaid
                          ? AppColors.mintLight
                          : (widget.event.isPaid
                              ? AppColors.peachLight
                              : AppColors.skyBlueLight),
                    ),
                    _buildStatusBadge(
                      label: isAttended ? 'ATTENDED ✓' : 'NOT ATTENDED',
                      color: isAttended
                          ? AppColors.mintDark
                          : AppColors.yellowDark,
                      bgColor: isAttended
                          ? AppColors.mintLight
                          : AppColors.yellowLight,
                    ),
                    // WhatsApp Registration Status Badge
                    _buildWhatsAppStatusBadge(reg.whatsappStatus),
                  ],
                ),

                const SizedBox(height: 8),

                // 2. FOOTER ROW: REG ID + COMPACT SEND WHATSAPP ACTION BUTTON + CHEVRON
                Row(
                  children: [
                    // REG ID & DATE (Flexibly truncates with ellipsis on small screens)
                    Expanded(
                      child: Text(
                        '$formattedRegId • $regDate',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // COMPACT SEND WHATSAPP ACTION BUTTON
                    _buildSendWhatsAppCompactButton(reg),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  /// Compact status badge displaying: Not Sent / WhatsApp Opened / Awaiting Admin Confirmation / Admin Confirmed Sent
  Widget _buildWhatsAppStatusBadge(String status) {
    final normalized = status.toLowerCase().trim();
    String label;
    Color color;
    Color bgColor;

    if (normalized == 'admin_confirmed_sent') {
      label = 'WA: Confirmed Sent ✓';
      color = AppColors.mintDark;
      bgColor = AppColors.mintLight;
    } else if (normalized == 'awaiting_confirmation' ||
        normalized == 'ready_to_share') {
      label = 'WA: Awaiting Confirm ⏳';
      color = AppColors.peachDark;
      bgColor = AppColors.peachLight;
    } else {
      label = 'WA: Not Sent';
      color = AppColors.textSecondary;
      bgColor = AppColors.background;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 9.5,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Compact WhatsApp action button next to student registration details
  Widget _buildSendWhatsAppCompactButton(RegistrationModel reg) {
    final isConfirmed = reg.whatsappStatus == 'admin_confirmed_sent';
    final isAwaiting = reg.whatsappStatus == 'awaiting_confirmation' ||
        reg.whatsappStatus == 'ready_to_share';

    final Color primaryColor = isConfirmed
        ? AppColors.mintDark
        : (isAwaiting ? AppColors.peachDark : const Color(0xFF1EBE5D));
    final Color bgColor = isConfirmed
        ? AppColors.mintLight
        : (isAwaiting ? AppColors.peachLight : const Color(0xFFE8F5E9));

    return InkWell(
      onTap: () => _handleSendRegistrationWhatsApp(reg),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_rounded,
              size: 11.5,
              color: primaryColor,
            ),
            const SizedBox(width: 4),
            Text(
              isConfirmed
                  ? 'Resend WA'
                  : (isAwaiting ? 'Confirm WA' : 'Send WA'),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STUDENT DETAILS MODAL BOTTOM SHEET ---

  void _showStudentDetailsModal(BuildContext context, RegistrationModel reg) {
    final profile = _userProfileCache[reg.studentId];

    final studentName = _resolveField(reg.studentName, profile?.name);
    final rollNumber = _resolveField(reg.rollNumber, profile?.rollNumber);
    final collegeEmail = _resolveField(reg.studentEmail, profile?.email);
    final phone = _resolveField(reg.phone, null);
    final department = _resolveField(reg.department, profile?.department);
    final year = _resolveField(reg.year, profile?.year);
    final section = reg.section.isNotEmpty ? reg.section : 'A';
    final regDate = DateFormatter.formatDate(reg.registeredAt);

    final formattedRegId = reg.id.length > 8
        ? 'REG-${reg.id.substring(0, 8).toUpperCase()}'
        : 'REG-${reg.id.toUpperCase()}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // MODAL HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.lavenderLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                color: AppColors.lavenderDark,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Participant Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMain,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),

                    const Divider(color: AppColors.border),
                    const SizedBox(height: 10),

                    // REGISTRATION ID & COPY BUTTON
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lavenderLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'REGISTRATION ID',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.lavenderDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formattedRegId,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMain,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primarySage,
                              foregroundColor: AppColors.sageDark,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              minimumSize: const Size(0, 36),
                              elevation: 0,
                            ),
                            onPressed: () =>
                                _copyRegistrationId(context, reg.id),
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text(
                              'Copy ID',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // SECTION 1: STUDENT PROFILE INFORMATION
                    const Text(
                      'Student Profile',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sageDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _modalRow('Full Name', studentName),
                    _modalRow('Student ID / Roll No', rollNumber),
                    _modalRow('College Email', collegeEmail),
                    _modalRow('Phone Number', phone),
                    _modalRow('Department / Branch', department),
                    _modalRow('Academic Year', year),
                    _modalRow('Section', section),

                    const SizedBox(height: 14),

                    // SECTION 2: REGISTRATION & EVENT DETAILS
                    const Text(
                      'Registration & Event',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sageDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _modalRow('Event Name', widget.event.title),
                    _modalRow('Event Date', widget.event.dateFormatted),
                    _modalRow('Registration Date', regDate),
                    _modalRow(
                      'Registration Status',
                      reg.isCancelled ? 'CANCELLED' : 'ACTIVE / CONFIRMED',
                      valueColor: reg.isCancelled ? AppColors.pinkDark : AppColors.sageDark,
                    ),

                    const SizedBox(height: 14),

                    // SECTION 3: PAYMENT DETAILS
                    const Text(
                      'Payment Information',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sageDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _modalRow(
                      'Payment Status',
                      reg.paymentStatus.toUpperCase(),
                      valueColor: reg.isPaid ? AppColors.sageDark : AppColors.peachDark,
                    ),
                    _modalRow(
                      'Amount',
                      widget.event.isPaid
                          ? '₹${reg.amount.toInt()}'
                          : 'FREE (₹0)',
                    ),
                    _modalRow(
                      'Payment Reference / ID',
                      reg.paymentId.isNotEmpty ? reg.paymentId : 'Not provided',
                    ),

                    const SizedBox(height: 14),

                    // SECTION 4: ATTENDANCE STATUS & VERIFICATION
                    const Text(
                      'Attendance Verification',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sageDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: reg.isAttended
                            ? AppColors.sageLight
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: reg.isAttended
                              ? AppColors.primarySage
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                reg.isAttended
                                    ? Icons.verified
                                    : Icons.pending_actions,
                                color: reg.isAttended
                                    ? AppColors.sageDark
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                reg.isAttended
                                    ? 'ATTENDED (Verified)'
                                    : 'NOT YET ATTENDED',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: reg.isAttended
                                      ? AppColors.sageDark
                                      : AppColors.textMain,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: reg.isAttended
                                  ? AppColors.pinkDark
                                  : AppColors.primarySage,
                              foregroundColor: reg.isAttended
                                  ? Colors.white
                                  : AppColors.sageDark,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: const Size(0, 34),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              await _toggleAttendance(reg);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                            },
                            child: Text(
                              reg.isAttended ? 'Revoke' : 'Mark Attended',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // SECTION 5: WHATSAPP REGISTRATION CONFIRMATION (ADMIN FLOW)
                    const Text(
                      'WhatsApp Registration Confirmation',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sageDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('registrations')
                          .doc(reg.id)
                          .snapshots(),
                      builder: (context, regSnap) {
                        final data = regSnap.data?.data() ?? {};
                        final currentStatus = (data['whatsappStatus'] as String? ?? reg.whatsappStatus).trim();
                        final isConfirmed = currentStatus == 'admin_confirmed_sent';
                        final isAwaiting = currentStatus == 'awaiting_confirmation' || currentStatus == 'ready_to_share';
                        final confirmedAdminUid = (data['whatsappConfirmedByAdminUid'] as String? ?? reg.whatsappConfirmedByAdminUid).trim();
                        final confirmedTimestamp = data['whatsappConfirmedAt'] != null
                            ? DateFormatter.parseDateTime(data['whatsappConfirmedAt'])
                            : reg.whatsappConfirmedAt;
                        final currentPhone = (data['whatsappNumber'] as String? ?? reg.whatsappNumber).isNotEmpty
                            ? (data['whatsappNumber'] as String? ?? reg.whatsappNumber)
                            : (reg.phone.isNotEmpty ? reg.phone : phone);

                        String statusLabel;
                        Color statusColor;
                        if (isConfirmed) {
                          statusLabel = 'ADMIN CONFIRMED SENT ✓';
                          statusColor = AppColors.mintDark;
                        } else if (isAwaiting) {
                          statusLabel = 'WHATSAPP OPENED / AWAITING CONFIRMATION ⏳';
                          statusColor = AppColors.peachDark;
                        } else {
                          statusLabel = 'NOT SENT';
                          statusColor = AppColors.textSecondary;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _modalRow(
                              'Recipient Mobile',
                              currentPhone.isNotEmpty ? currentPhone : 'Not provided',
                            ),
                            _modalRow(
                              'Confirmation Status',
                              statusLabel,
                              valueColor: statusColor,
                            ),
                            if (isConfirmed && confirmedAdminUid.isNotEmpty)
                              _modalRow(
                                'Confirmed By Admin UID',
                                confirmedAdminUid,
                              ),
                            if (isConfirmed && confirmedTimestamp != null)
                              _modalRow(
                                'Confirmed At',
                                DateFormatter.formatDate(confirmedTimestamp),
                              ),

                            const SizedBox(height: 12),

                            // MAIN ACTION: SEND / RESEND REGISTRATION WHATSAPP
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await _handleSendRegistrationWhatsApp(reg);
                                },
                                icon: const Icon(Icons.chat_rounded, size: 18),
                                label: Text(
                                  isConfirmed
                                      ? 'Resend Registration WhatsApp'
                                      : 'Send Registration WhatsApp',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isConfirmed ? AppColors.mintDark : const Color(0xFF1EBE5D),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),

                            // QUICK ACTION ROW IF AWAITING CONFIRMATION
                            if (isAwaiting) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final adminUid = _authService.currentUid ?? 'admin';
                                        await _whatsAppService.recordAdminConfirmation(
                                          registrationId: reg.id,
                                          eventId: widget.event.id,
                                          studentId: reg.studentId,
                                          studentName: studentName,
                                          eventTitle: widget.event.title,
                                          phone: currentPhone,
                                          adminUid: adminUid,
                                          wasSent: true,
                                        );
                                        if (ctx.mounted) Navigator.pop(ctx);
                                      },
                                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                                      label: const Text('Confirm Sent'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.mintDark,
                                        side: const BorderSide(color: AppColors.mintDark),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final adminUid = _authService.currentUid ?? 'admin';
                                        await _whatsAppService.recordAdminConfirmation(
                                          registrationId: reg.id,
                                          eventId: widget.event.id,
                                          studentId: reg.studentId,
                                          studentName: studentName,
                                          eventTitle: widget.event.title,
                                          phone: currentPhone,
                                          adminUid: adminUid,
                                          wasSent: false,
                                        );
                                        if (ctx.mounted) Navigator.pop(ctx);
                                      },
                                      icon: const Icon(Icons.cancel_outlined, size: 16),
                                      label: const Text('Mark Not Sent'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.pinkDark,
                                        side: const BorderSide(color: AppColors.pinkDark),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _modalRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- ACTIONS & HELPERS ---

  /// Primary demonstration flow: manual WhatsApp handoff + explicit admin verification
  Future<void> _handleSendRegistrationWhatsApp(RegistrationModel reg) async {
    final profile = _userProfileCache[reg.studentId];
    final studentName = _resolveField(reg.studentName, profile?.name).trim().isNotEmpty
        ? _resolveField(reg.studentName, profile?.name).trim()
        : 'Student';
    final eventTitle = widget.event.title.trim().isNotEmpty
        ? widget.event.title.trim()
        : (reg.eventTitle.trim().isNotEmpty ? reg.eventTitle.trim() : 'Event');

    String rawPhone = reg.whatsappNumber.trim().isNotEmpty
        ? reg.whatsappNumber.trim()
        : (reg.phone.trim().isNotEmpty
            ? reg.phone.trim()
            : (profile?.whatsappNumber ?? '').trim());

    String cleanPhone = WhatsAppService.normalizeForWaMe(rawPhone);

    // If phone number is missing or invalid, prompt admin for valid phone
    if (cleanPhone.isEmpty || !WhatsAppService.isValidPhoneNumber(cleanPhone)) {
      final inputPhone = await _showPhoneInputDialog(
        context: context,
        studentName: studentName,
        initialPhone: rawPhone,
      );
      if (inputPhone == null || inputPhone.trim().isEmpty) {
        return; // Admin cancelled
      }
      cleanPhone = WhatsAppService.normalizeForWaMe(inputPhone);
      if (!WhatsAppService.isValidPhoneNumber(cleanPhone)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid phone number format. Please include country code and digits.'),
              backgroundColor: AppColors.pinkDark,
            ),
          );
        }
        return;
      }
    }

    final formattedRegId = reg.id.length > 8
        ? 'REG-${reg.id.substring(0, 8).toUpperCase()}'
        : 'REG-${reg.id.toUpperCase()}';

    // 3. Prepare personalized registration confirmation message with attendance instructions:
    final messageText = WhatsAppService.buildTicketMessage(
      registration: reg,
      event: widget.event,
    );

    final encodedMessage = Uri.encodeComponent(messageText);
    final waUrl = 'https://wa.me/$cleanPhone?text=$encodedMessage';

    // 4. Mark status as WhatsApp Opened / Awaiting Admin Confirmation in Firestore
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('registrations').doc(reg.id).update({
      'whatsappStatus': 'awaiting_confirmation',
      'whatsappDeliveryMode': 'manual_admin',
      'whatsappSentAt': Timestamp.fromDate(now),
      'whatsappNumber': '+$cleanPhone',
    }).catchError((_) {});

    // Open WhatsApp with prefilled message
    try {
      await PlatformUrlLauncher.open(waUrl);
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }

    if (!mounted) return;

    // 6. Explicit confirmation dialog:
    // "Did you send the WhatsApp confirmation to this student for this event?"
    // Buttons: Yes, Message Sent and Not Sent
    final bool? wasSent = await _showAdminSentConfirmationDialog(
      context: context,
      studentName: studentName,
      eventTitle: eventTitle,
      regId: formattedRegId,
      cleanPhone: cleanPhone,
    );

    if (!mounted) return;

    final adminUid = _authService.currentUid ?? 'admin';

    // 7. Only if Yes, Message Sent selected, record admin confirmation
    if (wasSent == true) {
      await _whatsAppService.recordAdminConfirmation(
        registrationId: reg.id,
        eventId: widget.event.id,
        studentId: reg.studentId,
        studentName: studentName,
        eventTitle: eventTitle,
        phone: cleanPhone,
        adminUid: adminUid,
        wasSent: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WhatsApp confirmation recorded for $studentName.'),
            backgroundColor: AppColors.mintDark,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // 8. If Not Sent, closed, or cancelled, do not mark as sent
      await _whatsAppService.recordAdminConfirmation(
        registrationId: reg.id,
        eventId: widget.event.id,
        studentId: reg.studentId,
        studentName: studentName,
        eventTitle: eventTitle,
        phone: cleanPhone,
        adminUid: adminUid,
        wasSent: false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp status marked as Not Sent.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<bool?> _showAdminSentConfirmationDialog({
    required BuildContext context,
    required String studentName,
    required String eventTitle,
    required String regId,
    required String cleanPhone,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.cardWhite,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF1EBE5D),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'WhatsApp Confirmation',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Did you send the WhatsApp confirmation to this student for this event?',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lavenderLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Student: ',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Expanded(
                          child: Text(
                            studentName,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'Event: ',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Expanded(
                          child: Text(
                            eventTitle,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMain,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'Phone: ',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Text(
                          '+$cleanPhone',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'Ref ID: ',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Text(
                          regId,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lavenderDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your confirmation will be recorded with timestamp and admin UID in registration audit records.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text(
                'Not Sent',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1EBE5D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text(
                'Yes, Message Sent',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showPhoneInputDialog({
    required BuildContext context,
    required String studentName,
    required String initialPhone,
  }) {
    final phoneController = TextEditingController(text: initialPhone);
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.cardWhite,
          title: const Text(
            'Enter Contact Number',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please enter $studentName\'s WhatsApp mobile number (with country code):',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '+919876543210 or 9876543210',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18, color: AppColors.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mintDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx, phoneController.text.trim()),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleAttendance(RegistrationModel reg) async {
    final newStatus = !reg.isAttended;
    try {
      await _registrationService.updateAttendance(reg.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Attendance verified for ${reg.studentName.isNotEmpty ? reg.studentName : 'Student'} ✓'
                  : 'Attendance revoked for ${reg.studentName.isNotEmpty ? reg.studentName : 'Student'}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            backgroundColor: newStatus
                ? AppColors.sageDark
                : AppColors.peachDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update attendance: $e'),
            backgroundColor: AppColors.pinkDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _copyRegistrationId(BuildContext context, String rawId) {
    Clipboard.setData(ClipboardData(text: rawId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Registration ID copied to clipboard! ✓'),
        backgroundColor: AppColors.sageDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _exportExcel(
    BuildContext context,
    List<RegistrationModel> registrations,
  ) async {
    try {
      final fileName = ExcelExportHelper.getSafeFileName(
        eventTitle: widget.event.title,
        eventId: widget.event.id,
      );
      final resultMessage = await ExcelExportHelper.downloadRegistrationsExcel(
        registrations: registrations,
        eventTitle: widget.event.title,
        eventId: widget.event.id,
        eventNamesById: {widget.event.id: widget.event.title},
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  resultMessage.isNotEmpty
                      ? '$resultMessage ✓'
                      : 'Downloaded $fileName successfully! ✓',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.sageDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download Excel: $e'),
          backgroundColor: AppColors.pinkDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  Widget _buildEmptyEventState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.lavenderLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_alt_outlined,
              size: 48,
              color: AppColors.lavenderDark,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No students have registered yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Registrations for this event will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatchesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.peachLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_outlined,
                size: 48,
                color: AppColors.peachDark,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No matching participants found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try adjusting your search query or active filter selections.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarySage,
                foregroundColor: AppColors.sageDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _statusFilter = 'All';
                  _paymentFilter = 'All';
                  _attendanceFilter = 'All';
                });
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Clear Filters', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _MetricData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}
