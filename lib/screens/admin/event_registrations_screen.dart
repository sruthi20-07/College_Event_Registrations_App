import 'package:flutter/material.dart';

import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../services/event_service.dart';
import '../../services/registration_service.dart';
import '../../utils/constants.dart';
import '../../utils/csv_export_helper.dart';
import '../../utils/date_formatter.dart';

class EventRegistrationsScreen extends StatefulWidget {
  const EventRegistrationsScreen({super.key});

  @override
  State<EventRegistrationsScreen> createState() =>
      _EventRegistrationsScreenState();
}

class _EventRegistrationsScreenState extends State<EventRegistrationsScreen> {
  final EventService _eventService = EventService();
  final RegistrationService _registrationService = RegistrationService();

  String? _selectedEventId;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Registrations Management'),
        backgroundColor: AppColors.cardWhite,
        foregroundColor: AppColors.textMain,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              children: [
                // EVENT FILTER DROPDOWN & EXPORT CSV BUTTON
                StreamBuilder<List<EventModel>>(
                  stream: _eventService.streamAllEventsAdmin(),
                  builder: (context, eventSnapshot) {
                    final events = eventSnapshot.data ?? [];
                    EventModel? selectedEvent;
                    if (_selectedEventId != null) {
                      selectedEvent = events.firstWhere(
                        (e) => e.id == _selectedEventId,
                        orElse: () => events.first,
                      );
                    }

                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedEventId,
                            decoration: const InputDecoration(
                              labelText: 'Filter by Event',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              prefixIcon: Icon(Icons.filter_alt_outlined, color: AppColors.sageDark),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Events (All Registrations)', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              ...events.map(
                                (e) => DropdownMenuItem<String?>(
                                  value: e.id,
                                  child: Text(
                                    e.title,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedEventId = val;
                              });
                            },
                          ),
                        ),

                        if (selectedEvent != null) ...[
                          const SizedBox(height: 12),
                          // EVENT SEAT STATISTICS SUMMARY HEADER
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.skyBlueLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.pastelSkyBlue),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _statHeader(
                                  'Capacity',
                                  '${selectedEvent.maxSeats}',
                                  AppColors.textMain,
                                ),
                                Container(width: 1, height: 28, color: AppColors.border),
                                _statHeader(
                                  'Registered',
                                  '${selectedEvent.registeredCount}',
                                  AppColors.sageDark,
                                ),
                                Container(width: 1, height: 28, color: AppColors.border),
                                _statHeader(
                                  'Available',
                                  '${selectedEvent.availableSeats}',
                                  selectedEvent.isFull
                                      ? AppColors.pinkDark
                                      : AppColors.skyBlueDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),

                const SizedBox(height: 12),

                // SEARCH PARTICIPANTS
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase().trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search student name, roll number, or email...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 14),

                // REGISTRATION LIST STREAM
                Expanded(
                  child: StreamBuilder<List<RegistrationModel>>(
                    stream: _registrationService.streamEventRegistrations(
                      _selectedEventId ?? '',
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.sageDark,
                          ),
                        );
                      }

                      List<RegistrationModel> registrations = snapshot.data ?? [];

                      if (_searchQuery.isNotEmpty) {
                        registrations = registrations.where((r) {
                          return r.studentName.toLowerCase().contains(
                                _searchQuery,
                              ) ||
                              r.studentEmail.toLowerCase().contains(_searchQuery) ||
                              r.rollNumber.toLowerCase().contains(_searchQuery);
                        }).toList();
                      }

                      if (registrations.isEmpty) {
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
                                  Icons.people_outline,
                                  size: 48,
                                  color: AppColors.lavenderDark,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No registrations found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMain,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Try clearing the search or filter',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: [
                          // EXPORT CSV BUTTON FOR FILTERED LIST
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Records: ${registrations.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.sageLight,
                                    foregroundColor: AppColors.sageDark,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(color: AppColors.primarySage),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  onPressed: () =>
                                      _exportCsv(context, registrations),
                                  icon: const Icon(Icons.download_outlined, size: 18),
                                  label: const Text(
                                    'Export CSV',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: registrations.length,
                              itemBuilder: (context, index) {
                                final reg = registrations[index];
                                return _buildRegistrationTile(context, reg);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statHeader(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationTile(BuildContext context, RegistrationModel reg) {
    final bool isCancelled = reg.isCancelled;
    final formattedRegId = reg.id.length > 8
        ? 'REG-${reg.id.substring(0, 8).toUpperCase()}'
        : 'REG-${reg.id.toUpperCase()}';

    Color badgeBg;
    Color badgeTextColor;
    String badgeLabel;

    if (isCancelled) {
      badgeBg = AppColors.pinkLight;
      badgeTextColor = AppColors.pinkDark;
      badgeLabel = 'CANCELLED';
    } else if (reg.isPaid) {
      badgeBg = AppColors.sageLight;
      badgeTextColor = AppColors.sageDark;
      badgeLabel = 'PAID ✓';
    } else {
      badgeBg = AppColors.lavenderLight;
      badgeTextColor = AppColors.lavenderDark;
      badgeLabel = 'REGISTERED';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          onTap: () => _showRegistrationDetailModal(context, reg, formattedRegId),
          leading: CircleAvatar(
            backgroundColor: isCancelled
                ? AppColors.pinkLight
                : AppColors.lavenderLight,
            child: Icon(
              isCancelled ? Icons.cancel_outlined : Icons.person_outline,
              color: isCancelled ? AppColors.pinkDark : AppColors.lavenderDark,
            ),
          ),
          title: Text(
            reg.studentName.isNotEmpty ? reg.studentName : 'Student',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3),
              Text(
                '${reg.rollNumber} • ${reg.department} (${reg.year})',
                style: const TextStyle(fontSize: 13, color: AppColors.textMain),
              ),
              const SizedBox(height: 2),
              Text(
                reg.studentEmail,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                'ID: $formattedRegId • ${DateFormatter.formatDate(reg.registeredAt)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: badgeTextColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRegistrationDetailModal(
    BuildContext context,
    RegistrationModel reg,
    String formattedRegId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                          Icons.badge_outlined,
                          color: AppColors.lavenderDark,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Registration Details',
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
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: AppColors.border),
              const SizedBox(height: 10),
              _detailRow('Registration ID', formattedRegId),
              _detailRow('Full Name', reg.studentName),
              _detailRow('Student ID / Roll', reg.rollNumber),
              _detailRow('Email', reg.studentEmail),
              _detailRow('Phone', reg.phone.isNotEmpty ? reg.phone : 'N/A'),
              _detailRow('Branch / Dept', reg.department),
              _detailRow('Year & Section', '${reg.year} (${reg.section})'),
              _detailRow('Event ID', reg.eventId),
              _detailRow('Payment Status', reg.paymentStatus.toUpperCase()),
              _detailRow(
                'Payment ID',
                reg.paymentId.isNotEmpty ? reg.paymentId : 'N/A',
              ),
              _detailRow('Amount', '₹${reg.amount.toInt()}'),
              _detailRow(
                'Registered Date',
                DateFormatter.formatDate(reg.registeredAt),
              ),
              const Divider(color: AppColors.border),
              const SizedBox(height: 6),
              _detailRow(
                'WhatsApp Consent',
                reg.whatsappConsent ? 'Consented ✓' : 'No Consent',
              ),
              if (reg.whatsappNumber.isNotEmpty)
                _detailRow('WhatsApp No', reg.whatsappNumber),
              if (reg.whatsappStatus.isNotEmpty)
                _detailRow('WhatsApp Status', reg.whatsappStatus.toUpperCase()),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textMain,
              ),
            ),
          ),
        ],
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
        content: const Text(
          'CSV registration report copied to clipboard! ✓',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.sageDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
