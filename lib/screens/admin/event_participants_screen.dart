import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/registration_service.dart';
import '../../utils/constants.dart';
import '../../utils/csv_export_helper.dart';
import '../../utils/date_formatter.dart';
import 'qr_scanner_screen.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.sageDark),
            tooltip: 'Scan Attendance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QrScannerScreen(event: widget.event),
                ),
              );
            },
          ),
        ],
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primarySage,
        foregroundColor: AppColors.sageDark,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QrScannerScreen(event: widget.event),
            ),
          );
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildEventSummaryBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lavenderLight,
                  borderRadius: BorderRadius.circular(12),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: widget.event.isPublished
                      ? AppColors.sageLight
                      : AppColors.pinkLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.event.status.toUpperCase(),
                  style: TextStyle(
                    color: widget.event.isPublished
                        ? AppColors.sageDark
                        : AppColors.pinkDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.event.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.sageDark,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.event.dateFormatted,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.peachDark,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.event.venue,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    size: 14,
                    color: AppColors.skyBlueDark,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.event.isPaid
                        ? 'Fee: ₹${widget.event.registrationFee.toInt()}'
                        : 'FREE Event',
                    style: TextStyle(
                      color: widget.event.isPaid
                          ? AppColors.skyBlueDark
                          : AppColors.sageDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarySage,
                foregroundColor: AppColors.sageDark,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QrScannerScreen(event: widget.event),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: const Text(
                'Scan Attendance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final isTablet = MediaQuery.of(context).size.width >= 600;

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
        color: AppColors.sageDark,
        bgColor: AppColors.sageLight,
      ),
      _MetricData(
        title: 'Pending Payments',
        value: '$pendingPayments',
        icon: Icons.pending_actions_outlined,
        color: AppColors.peachDark,
        bgColor: AppColors.peachLight,
      ),
      _MetricData(
        title: 'Cancelled',
        value: '$cancelledRegistrations',
        icon: Icons.cancel_outlined,
        color: AppColors.pinkDark,
        bgColor: AppColors.pinkLight,
      ),
      _MetricData(
        title: 'Available Seats',
        value: '$availableSeats / ${widget.event.maxSeats}',
        icon: Icons.event_seat_outlined,
        color: availableSeats <= 0 ? AppColors.pinkDark : AppColors.textSecondary,
        bgColor: AppColors.background,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: isDesktop ? 2.3 : (isTablet ? 2.0 : 1.7),
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: item.bgColor,
                        child: Icon(item.icon, size: 16, color: item.color),
                      ),
                      Text(
                        item.value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: item.color,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SEARCH FIELD
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search student name, roll number, email, or reg ID...',
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
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

          const SizedBox(height: 14),

          // FILTER CHIPS ROW
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Status Filter
              _buildFilterPopup(
                label: 'Status: $_statusFilter',
                currentValue: _statusFilter,
                options: const ['All', 'Active', 'Cancelled'],
                onSelected: (val) => setState(() => _statusFilter = val),
              ),

              // Payment Filter
              _buildFilterPopup(
                label: 'Payment: $_paymentFilter',
                currentValue: _paymentFilter,
                options: const ['All', 'Paid', 'Pending'],
                onSelected: (val) => setState(() => _paymentFilter = val),
              ),

              // Attendance Filter
              _buildFilterPopup(
                label: 'Attendance: $_attendanceFilter',
                currentValue: _attendanceFilter,
                options: const ['All', 'Attended', 'Not Attended'],
                onSelected: (val) => setState(() => _attendanceFilter = val),
              ),

              if (hasActiveFilters)
                TextButton.icon(
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
                    size: 16,
                    color: AppColors.pinkDark,
                  ),
                  label: const Text(
                    'Reset',
                    style: TextStyle(color: AppColors.pinkDark, fontSize: 12),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),

          // RESULT COUNT & EXPORT CSV BUTTON
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${filteredList.length} of ${allRegistrations.length} participants',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (filteredList.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _exportCsv(context, filteredList),
                  icon: const Icon(
                    Icons.download_outlined,
                    size: 16,
                    color: AppColors.sageDark,
                  ),
                  label: const Text(
                    'Export CSV',
                    style: TextStyle(
                      color: AppColors.sageDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
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
              child: Row(
                children: [
                  Icon(
                    opt == currentValue
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 16,
                    color: opt == currentValue
                        ? AppColors.sageDark
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(opt),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isFiltered ? AppColors.sageLight : AppColors.background,
          borderRadius: BorderRadius.circular(10),
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isFiltered ? AppColors.sageDark : AppColors.textMain,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showStudentDetailsModal(context, reg),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TOP HEADER: NAME + ATTENDANCE TOGGLE / STATUS
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isCancelled
                          ? AppColors.pinkLight
                          : (isAttended
                                ? AppColors.sageLight
                                : AppColors.lavenderLight),
                      child: Icon(
                        isCancelled
                            ? Icons.cancel_outlined
                            : (isAttended
                                  ? Icons.how_to_reg
                                  : Icons.person_outline),
                        color: isCancelled
                            ? AppColors.pinkDark
                            : (isAttended
                                  ? AppColors.sageDark
                                  : AppColors.lavenderDark),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Roll: $rollNumber • $department ($year)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMain,
                            ),
                          ),
                          Text(
                            collegeEmail,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // REG ID & DATE ROW
                Row(
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formattedRegId,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      regDate,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),

                // BADGES & ACTIONS ROW
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // BADGES WRAP
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Registration Status Badge
                        _buildStatusBadge(
                          label: isCancelled ? 'CANCELLED' : 'ACTIVE',
                          color: isCancelled
                              ? AppColors.pinkDark
                              : AppColors.lavenderDark,
                          bgColor: isCancelled
                              ? AppColors.pinkLight
                              : AppColors.lavenderLight,
                        ),

                        // Payment Status Badge
                        _buildStatusBadge(
                          label: isPaid
                              ? 'PAID ✓'
                              : (widget.event.isPaid ? 'PENDING' : 'FREE'),
                          color: isPaid
                              ? AppColors.sageDark
                              : (widget.event.isPaid
                                    ? AppColors.peachDark
                                    : AppColors.skyBlueDark),
                          bgColor: isPaid
                              ? AppColors.sageLight
                              : (widget.event.isPaid
                                    ? AppColors.peachLight
                                    : AppColors.skyBlueLight),
                        ),

                        // Attendance Status Badge
                        _buildStatusBadge(
                          label: isAttended ? 'ATTENDED ✓' : 'NOT ATTENDED',
                          color: isAttended
                              ? AppColors.skyBlueDark
                              : AppColors.textSecondary,
                          bgColor: isAttended
                              ? AppColors.skyBlueLight
                              : AppColors.background,
                        ),
                      ],
                    ),

                    // Quick Toggle Attendance Action
                    IconButton(
                      icon: Icon(
                        isAttended
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: isAttended ? AppColors.sageDark : AppColors.textSecondary,
                      ),
                      tooltip: isAttended
                          ? 'Mark as Not Attended'
                          : 'Verify & Mark as Attended',
                      onPressed: () => _toggleAttendance(reg),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
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

                    // SECTION 5: WHATSAPP CONFIRMATION & TICKET NOTIFICATION
                    const Text(
                      'WhatsApp Confirmation & Ticket',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sageDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _modalRow(
                      'Consent Status',
                      reg.whatsappConsent
                          ? 'AGREED / CONSENTED ✓'
                          : 'NOT CONSENTED',
                      valueColor: reg.whatsappConsent
                          ? AppColors.sageDark
                          : AppColors.peachDark,
                    ),
                    _modalRow(
                      'WhatsApp Number',
                      reg.whatsappNumber.isNotEmpty
                          ? reg.whatsappNumber
                          : (reg.phone.isNotEmpty
                              ? reg.phone
                              : 'Not provided'),
                    ),
                    _modalRow(
                      'Delivery Mode',
                      reg.whatsappDeliveryMode.isNotEmpty
                          ? (reg.whatsappDeliveryMode == 'manual'
                              ? 'Mode A: Quick Share'
                              : 'Mode B: Cloud API')
                          : 'Not initiated',
                    ),
                    _modalRow(
                      'Notification Status',
                      reg.whatsappStatus.isNotEmpty
                          ? reg.whatsappStatus
                              .replaceAll('_', ' ')
                              .toUpperCase()
                          : 'NONE',
                      valueColor: reg.whatsappStatus == 'delivered' ||
                              reg.whatsappStatus == 'accepted' ||
                              reg.whatsappStatus == 'ready_to_share'
                          ? AppColors.sageDark
                          : (reg.whatsappStatus == 'failed'
                              ? AppColors.pinkDark
                              : AppColors.lavenderDark),
                    ),
                    if (reg.whatsappSentAt != null)
                      _modalRow(
                        'Last Attempt At',
                        DateFormatter.formatDate(reg.whatsappSentAt!),
                      ),
                    if (reg.whatsappError.isNotEmpty)
                      _modalRow(
                        'Last Diagnostic Note',
                        reg.whatsappError,
                        valueColor: AppColors.pinkDark,
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

  Future<void> _exportCsv(
    BuildContext context,
    List<RegistrationModel> registrations,
  ) async {
    await CsvExportHelper.copyCsvToClipboard(registrations);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Participant CSV copied to clipboard! ✓'),
        backgroundColor: AppColors.sageDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
