import 'package:flutter/material.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/registration_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_formatter.dart';
import '../../utils/excel_export_helper.dart';

class EventRegistrationReportScreen extends StatefulWidget {
  final EventModel? initialEvent;

  const EventRegistrationReportScreen({super.key, this.initialEvent});

  @override
  State<EventRegistrationReportScreen> createState() =>
      _EventRegistrationReportScreenState();
}

class _EventRegistrationReportScreenState
    extends State<EventRegistrationReportScreen> {
  final AuthService _authService = AuthService();
  final EventService _eventService = EventService();
  final RegistrationService _registrationService = RegistrationService();

  EventModel? _selectedEvent;
  String? _selectedEventId;
  String _searchQuery = '';
  bool _isDownloading = false;
  Map<String, String> _eventsMap = {};

  @override
  void initState() {
    super.initState();
    _selectedEvent = widget.initialEvent;
    _selectedEventId = widget.initialEvent?.id;
  }

  Future<void> _handleDownloadExcel({
    required List<RegistrationModel> registrations,
    required Map<String, String> eventsMap,
  }) async {
    if (_isDownloading) return;

    setState(() => _isDownloading = true);

    final eventTitle = _selectedEvent?.title ?? 'All Events';
    final eventId = _selectedEvent?.id ?? 'all_events';

    try {
      final resultMessage = await ExcelExportHelper.downloadRegistrationsExcel(
        registrations: registrations,
        eventTitle: eventTitle,
        eventId: eventId,
        eventNamesById: eventsMap,
      );

      if (mounted) {
        final fileName = ExcelExportHelper.getSafeFileName(
          eventTitle: eventTitle,
          eventId: eventId,
        );
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Excel export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export failed: ${e.toString().replaceAll("Exception: ", "")}',
            ),
            backgroundColor: AppColors.pinkDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Event Registration Report',
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
      body: StreamBuilder<UserModel?>(
        stream: currentUser != null
            ? _authService.streamUserProfile(currentUser.uid)
            : Stream.value(null),
        builder: (context, userSnapshot) {
          // 1. DATA ACCESS & AUTHORIZATION ENFORCEMENT
          if (userSnapshot.connectionState == ConnectionState.waiting &&
              currentUser != null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.lavenderDark),
            );
          }

          final user = userSnapshot.data;
          final isAuthorized = _authService.isAuthorizedStaff(currentUser, user);

          if (!isAuthorized) {
            return _buildUnauthorizedView();
          }

          return _buildReportContent();
        },
      ),
    );
  }

  Widget _buildUnauthorizedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.pinkLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.gpp_bad_outlined,
                size: 54,
                color: AppColors.pinkDark,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Access Restricted',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only authorized college administrators, faculty, and coordinators have permission to view or export registration reports.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent() {
    return StreamBuilder<List<EventModel>>(
      stream: _eventService.streamAllEventsAdmin(),
      builder: (context, eventSnapshot) {
        if (eventSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.lavenderDark),
          );
        }

        if (eventSnapshot.hasError) {
          return Center(
            child: Text('Error loading events: ${eventSnapshot.error}'),
          );
        }

        final events = eventSnapshot.data ?? [];
        if (events.isEmpty) {
          return _buildNoEventsState();
        }

        // Cache events mapping { eventId: eventTitle }
        _eventsMap = { for (var e in events) e.id: e.title };

        // Sync selected event if ID is selected
        if (_selectedEventId != null) {
          final matched = events.where((e) => e.id == _selectedEventId).toList();
          if (matched.isNotEmpty) {
            _selectedEvent = matched.first;
          } else {
            _selectedEvent = null;
            _selectedEventId = null;
          }
        } else {
          _selectedEvent = null;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. EVENT SELECTOR HEADER
              _buildEventSelectorHeader(events),
              const SizedBox(height: 16),

              // 2. REGISTRATIONS TABLE CONTENT
              Expanded(
                child: _buildEventRegistrationsStream(_selectedEvent, _eventsMap),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventSelectorHeader(List<EventModel> events) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_note_rounded,
                color: AppColors.lavenderDark,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'Select Event for Reporting',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const Spacer(),
              if (_selectedEvent != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ID: ${_selectedEvent!.id}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.lavenderDark,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // EVENT DROPDOWN
          DropdownButtonFormField<String?>(
            key: ValueKey(_selectedEventId),
            initialValue: _selectedEventId,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  'All Events (All Registrations)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.coralDark,
                  ),
                ),
              ),
              ...events.map((event) {
                return DropdownMenuItem<String?>(
                  value: event.id,
                  child: Text(
                    '${event.title} (${event.dateFormatted})',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                );
              }),
            ],
            onChanged: (newId) {
              setState(() {
                _selectedEventId = newId;
                if (newId != null) {
                  _selectedEvent = events.firstWhere((e) => e.id == newId);
                } else {
                  _selectedEvent = null;
                }
                _searchQuery = '';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventRegistrationsStream(
    EventModel? event,
    Map<String, String> eventsMap,
  ) {
    final stream = event != null
        ? _registrationService.streamEventRegistrations(event.id)
        : _registrationService.streamEventRegistrations('');

    return StreamBuilder<List<RegistrationModel>>(
      stream: stream,
      builder: (context, snapshot) {
        // LOADING STATE
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.lavenderDark),
          );
        }

        // ERROR STATE
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.pinkDark),
                const SizedBox(height: 12),
                Text(
                  'Error loading registrations: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.pinkDark),
                ),
              ],
            ),
          );
        }

        final allRegistrations = snapshot.data ?? [];

        // EMPTY STATE
        if (allRegistrations.isEmpty) {
          return _buildEmptyRegistrationsState(event, eventsMap);
        }

        // FILTER BY SEARCH QUERY
        final filteredList = allRegistrations.where((reg) {
          if (_searchQuery.trim().isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return reg.studentName.toLowerCase().contains(q) ||
              reg.studentEmail.toLowerCase().contains(q) ||
              reg.rollNumber.toLowerCase().contains(q) ||
              reg.department.toLowerCase().contains(q) ||
              reg.eventTitle.toLowerCase().contains(q);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SEARCH BAR & DOWNLOAD EXCEL ACTION ROW
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search student, roll no, email, dept...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.cardWhite,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // DOWNLOAD EXCEL BUTTON
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sageDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isDownloading
                      ? null
                      : () => _handleDownloadExcel(
                            registrations: allRegistrations,
                            eventsMap: eventsMap,
                          ),
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.table_view_rounded, size: 19),
                  label: Text(
                    _isDownloading ? 'Generating...' : 'Download Excel',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // SUMMARY METRICS BAR
            _buildSummaryRow(allRegistrations, filteredList.length),
            const SizedBox(height: 10),

            // SCROLLABLE READABLE DATA TABLE
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          AppColors.lavenderLight.withValues(alpha: 0.5),
                        ),
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                          fontSize: 13,
                        ),
                        dataTextStyle: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMain,
                        ),
                        columns: [
                          const DataColumn(label: Text('#')),
                          const DataColumn(label: Text('Reg ID')),
                          const DataColumn(label: Text('Student Name')),
                          const DataColumn(label: Text('Roll No')),
                          const DataColumn(label: Text('Email')),
                          const DataColumn(label: Text('Phone')),
                          const DataColumn(label: Text('Dept / Year')),
                          if (event == null) const DataColumn(label: Text('Event Name')),
                          const DataColumn(label: Text('Registration Date')),
                          const DataColumn(label: Text('Status')),
                          const DataColumn(label: Text('Payment')),
                          const DataColumn(label: Text('Attendance')),
                        ],
                        rows: filteredList.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final reg = entry.value;
                          final roll = reg.rollNumber.isNotEmpty ? reg.rollNumber : 'N/A';
                          final phone = reg.phone.isNotEmpty
                              ? reg.phone
                              : (reg.whatsappNumber.isNotEmpty ? reg.whatsappNumber : 'N/A');

                          // Event name resolution
                          final String evName = reg.eventTitle.isNotEmpty
                              ? reg.eventTitle
                              : (eventsMap[reg.eventId] ??
                                  (event != null ? event.title : 'Event ID: ${reg.eventId}'));

                          return DataRow(
                            color: WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) {
                                if (entry.key.isEven) {
                                  return Colors.white;
                                }
                                return AppColors.background.withValues(alpha: 0.4);
                              },
                            ),
                            cells: [
                              DataCell(Text('$idx')),
                              DataCell(Text(
                                reg.id.length > 8 ? '${reg.id.substring(0, 8)}...' : reg.id,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                              )),
                              DataCell(Text(
                                reg.studentName.isNotEmpty ? reg.studentName : 'N/A',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              )),
                              DataCell(Text(roll)),
                              DataCell(Text(reg.studentEmail.isNotEmpty ? reg.studentEmail : 'N/A')),
                              DataCell(Text(phone)),
                              DataCell(Text('${reg.department} ${reg.year}')),
                              if (event == null)
                                DataCell(Text(
                                  evName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                )),
                              DataCell(Text(DateFormatter.formatDate(reg.registeredAt))),
                              DataCell(_statusPill(
                                reg.registrationStatus.toUpperCase(),
                                reg.isCancelled ? AppColors.pinkDark : AppColors.sageDark,
                                reg.isCancelled ? AppColors.pinkLight : AppColors.sageLight,
                              )),
                              DataCell(_statusPill(
                                reg.paymentStatus.toUpperCase(),
                                reg.isPaid ? AppColors.mintDark : AppColors.peachDark,
                                reg.isPaid ? AppColors.mintLight : AppColors.peachLight,
                              )),
                              DataCell(_statusPill(
                                reg.isAttended ? 'ATTENDED' : 'NOT ATTENDED',
                                reg.isAttended ? AppColors.sageDark : AppColors.textSecondary,
                                reg.isAttended ? AppColors.sageLight : AppColors.background,
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow(List<RegistrationModel> allRegs, int filteredCount) {
    final totalPaid = allRegs.where((r) => r.isPaid).length;
    final totalAttended = allRegs.where((r) => r.isAttended).length;

    return Row(
      children: [
        Text(
          'Showing $filteredCount of ${allRegs.length} registrations',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        _miniMetric('Paid', '$totalPaid', AppColors.mintDark),
        const SizedBox(width: 8),
        _miniMetric('Attended', '$totalAttended', AppColors.sageDark),
      ],
    );
  }

  Widget _miniMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 10.5,
        ),
      ),
    );
  }

  Widget _buildEmptyRegistrationsState(
    EventModel? event,
    Map<String, String> eventsMap,
  ) {
    final title = event != null ? 'No Registrations for "${event.title}"' : 'No Registrations Found';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.lavenderLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 48,
                color: AppColors.lavenderDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No students have registered yet. As students sign up, their details will appear in this report.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            // Allows downloading empty workbook template with headers
            OutlinedButton.icon(
              onPressed: () => _handleDownloadExcel(
                registrations: [],
                eventsMap: eventsMap,
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download Empty Excel Template'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoEventsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.lavenderLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_busy_outlined,
                size: 48,
                color: AppColors.lavenderDark,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Events Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create and manage events to generate event-specific registration Excel reports.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
