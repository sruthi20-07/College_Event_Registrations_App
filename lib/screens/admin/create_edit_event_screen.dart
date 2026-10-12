import 'package:flutter/material.dart';

import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_formatter.dart';

class CreateEditEventScreen extends StatefulWidget {
  final EventModel? event;

  const CreateEditEventScreen({super.key, this.event});

  @override
  State<CreateEditEventScreen> createState() => _CreateEditEventScreenState();
}

class _CreateEditEventScreenState extends State<CreateEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final EventService _eventService = EventService();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _venueController;
  late TextEditingController _organizerController;
  late TextEditingController _capacityController;
  late TextEditingController _feeController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _posterUrlController;
  late TextEditingController _minCgpaController;
  late TextEditingController _requirementsController;

  String _selectedCategory = EventCategories.technical;
  String _selectedStatus = EventStatuses.upcoming;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  DateTime _selectedDeadline = DateTime.now().add(const Duration(days: 6));

  // Eligibility state
  bool _allYears = true;
  Set<String> _selectedYears = {};
  bool _allDepartments = true;
  Set<String> _selectedDepartments = {};

  // Coordinator state
  List<EventCoordinator> _coordinators = [];

  bool _isLoading = false;

  bool get isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;

    _titleController = TextEditingController(text: e?.title ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _venueController = TextEditingController(text: e?.venue ?? '');
    _organizerController = TextEditingController(text: e?.organizer ?? '');
    _capacityController = TextEditingController(
      text: (e?.maxSeats ?? 100).toString(),
    );
    _feeController = TextEditingController(
      text: (e?.registrationFee ?? 0.0).toStringAsFixed(0),
    );
    _startTimeController = TextEditingController(
      text: e?.startTime ?? '10:00 AM',
    );
    _endTimeController = TextEditingController(text: e?.endTime ?? '4:00 PM');
    _posterUrlController = TextEditingController(text: e?.posterUrl ?? '');
    _minCgpaController = TextEditingController(
      text: (e != null && e.minCgpa > 0) ? e.minCgpa.toString() : '',
    );
    _requirementsController = TextEditingController(
      text: e?.requirements ?? '',
    );

    if (e != null) {
      _selectedCategory = e.category;
      _selectedStatus = e.status;
      _selectedDate = e.date;
      _selectedDeadline = e.registrationDeadline;
      _coordinators = List<EventCoordinator>.from(e.coordinators);

      if (e.allowedYears.isNotEmpty && !e.isAllYears) {
        _allYears = false;
        _selectedYears = e.allowedYears.toSet();
      } else {
        _allYears = true;
        _selectedYears = {};
      }

      if (e.allowedDepartments.isNotEmpty && !e.isAllDepartments) {
        _allDepartments = false;
        _selectedDepartments = e.allowedDepartments.toSet();
      } else {
        _allDepartments = true;
        _selectedDepartments = {};
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _organizerController.dispose();
    _capacityController.dispose();
    _feeController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _posterUrlController.dispose();
    _minCgpaController.dispose();
    _requirementsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isDeadline) async {
    final initialDate = isDeadline ? _selectedDeadline : _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.sageDark,
              onPrimary: Colors.white,
              surface: AppColors.cardWhite,
              onSurface: AppColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isDeadline) {
          _selectedDeadline = picked;
        } else {
          _selectedDate = picked;
          if (_selectedDeadline.isAfter(_selectedDate)) {
            _selectedDeadline = _selectedDate.subtract(const Duration(days: 1));
          }
        }
      });
    }
  }

  void _showCoordinatorDialog({EventCoordinator? initialCoordinator, int? editIndex}) {
    final nameCtrl = TextEditingController(text: initialCoordinator?.name ?? '');
    final roleCtrl = TextEditingController(text: initialCoordinator?.role ?? '');
    final phoneCtrl = TextEditingController(text: initialCoordinator?.phone ?? '');
    final emailCtrl = TextEditingController(text: initialCoordinator?.email ?? '');
    final whatsappCtrl = TextEditingController(text: initialCoordinator?.whatsapp ?? '');
    final coordFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.cardWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lavenderLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_pin_outlined,
                  color: AppColors.lavenderDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                editIndex != null ? 'Edit Coordinator' : 'Add Coordinator',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Form(
                key: coordFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Coordinator Name *',
                        prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: roleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Role / Responsibility *',
                        hintText: 'e.g. Student Lead, Faculty In-charge',
                        prefixIcon: Icon(Icons.badge_outlined, color: AppColors.textSecondary),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Role is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        hintText: '10-digit mobile number',
                        prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textSecondary),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Phone number is required';
                        if (v.trim().replaceAll(RegExp(r'\D'), '').length < 10) {
                          return 'Enter a valid 10-digit phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        hintText: 'coordinator@college.edu',
                        prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: whatsappCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp Contact (Optional)',
                        hintText: '+91 9876543210',
                        prefixIcon: Icon(Icons.chat_outlined, color: AppColors.mintDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (!coordFormKey.currentState!.validate()) return;
                final newCoordinator = EventCoordinator(
                  name: nameCtrl.text.trim(),
                  role: roleCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  whatsapp: whatsappCtrl.text.trim(),
                );
                setState(() {
                  if (editIndex != null) {
                    _coordinators[editIndex] = newCoordinator;
                  } else {
                    _coordinators.add(newCoordinator);
                  }
                });
                Navigator.pop(dialogCtx);
              },
              child: Text(editIndex != null ? 'Save Changes' : 'Add Coordinator'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveEvent() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final int capacity = int.tryParse(_capacityController.text.trim()) ?? 0;
    final double fee = double.tryParse(_feeController.text.trim()) ?? 0.0;
    final double minCgpa = double.tryParse(_minCgpaController.text.trim()) ?? 0.0;

    if (capacity <= 0) {
      _showSnackBar('Capacity must be greater than 0', isError: true);
      return;
    }

    if (fee < 0) {
      _showSnackBar('Registration fee cannot be negative', isError: true);
      return;
    }

    if (minCgpa < 0 || minCgpa > 10) {
      _showSnackBar('CGPA must be between 0.0 and 10.0', isError: true);
      return;
    }

    // Prepare configured eligibility lists
    final List<String> finalAllowedYears = _allYears
        ? []
        : _selectedYears.toList();
    final List<String> finalAllowedDepts = _allDepartments
        ? []
        : _selectedDepartments.toList();

    setState(() {
      _isLoading = true;
    });

    try {
      final String finalPosterUrl = _posterUrlController.text.trim();

      if (isEditing) {
        final existing = widget.event!;
        final updatedEvent = existing.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          venue: _venueController.text.trim(),
          organizer: _organizerController.text.trim(),
          maxSeats: capacity,
          availableSeats: (capacity - existing.registeredCount).clamp(
            0,
            capacity,
          ),
          registrationFee: fee,
          date: _selectedDate,
          startTime: _startTimeController.text.trim(),
          endTime: _endTimeController.text.trim(),
          registrationDeadline: _selectedDeadline,
          status: _selectedStatus,
          posterUrl: finalPosterUrl,
          coordinators: _coordinators,
          allowedYears: finalAllowedYears,
          allowedDepartments: finalAllowedDepts,
          minCgpa: minCgpa,
          requirements: _requirementsController.text.trim(),
          updatedAt: DateTime.now(),
        );

        await _eventService.updateEvent(updatedEvent);
        _showSnackBar('Event updated successfully!');
      } else {
        final newEvent = EventModel(
          id: '',
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          posterUrl: finalPosterUrl,
          date: _selectedDate,
          startTime: _startTimeController.text.trim(),
          endTime: _endTimeController.text.trim(),
          venue: _venueController.text.trim(),
          organizer: _organizerController.text.trim(),
          maxSeats: capacity,
          availableSeats: capacity,
          registrationFee: fee,
          registrationDeadline: _selectedDeadline,
          status: _selectedStatus,
          coordinators: _coordinators,
          allowedYears: finalAllowedYears,
          allowedDepartments: finalAllowedDepts,
          minCgpa: minCgpa,
          requirements: _requirementsController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _eventService.createEvent(newEvent);
        _showSnackBar('Event created successfully!');
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving event: $e');
      final cleanMsg = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('FirebaseException: ', '');
      _showSnackBar(cleanMsg, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? AppColors.pinkDark : AppColors.sageDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final catColor = _getCategoryColor(_selectedCategory);
    final catDarkColor = _getCategoryDarkColor(_selectedCategory);
    final catIcon = _getCategoryIcon(_selectedCategory);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Event' : 'Create New Event'),
        backgroundColor: AppColors.cardWhite,
        foregroundColor: AppColors.textMain,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER TITLE
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.sageLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primarySage.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primarySage,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEditing
                                ? Icons.edit_calendar_outlined
                                : Icons.add_circle_outline,
                            color: AppColors.sageDark,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing
                                    ? 'Update Event Details'
                                    : 'Fill in Event Details',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.sageDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Provide complete details, eligibility criteria & coordinator contacts',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // CATEGORY COVER THEME CARD
                  _buildSectionHeader(
                    Icons.palette_outlined,
                    'Cover Theme & Visuals',
                    'Auto-styled pastel banner based on event category',
                  ),
                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 160,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                catColor.withValues(alpha: 0.6),
                                AppColors.lavenderLight,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: catColor),
                          ),
                          child: _posterUrlController.text.startsWith('http')
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    _posterUrlController.text,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildCategoryThemePlaceholder(
                                          catColor,
                                          catDarkColor,
                                          catIcon,
                                        ),
                                  ),
                                )
                              : _buildCategoryThemePlaceholder(
                                  catColor,
                                  catDarkColor,
                                  catIcon,
                                ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _posterUrlController,
                          decoration: const InputDecoration(
                            labelText: 'External Image URL (Optional)',
                            hintText: 'https://... (Leave blank for category pastel theme)',
                            prefixIcon: Icon(
                              Icons.link_outlined,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // BASIC DETAILS
                  _buildSectionHeader(
                    Icons.info_outline,
                    'Basic Information',
                    'Core event details and classification',
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleController,
                          validator: (val) =>
                              val == null || val.trim().isEmpty
                                  ? 'Event title is required'
                                  : null,
                          decoration: const InputDecoration(
                            labelText: 'Event Name / Title',
                            prefixIcon: Icon(
                              Icons.event_outlined,
                              color: AppColors.sageDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Event Category',
                            prefixIcon: Icon(
                              Icons.category_outlined,
                              color: AppColors.lavenderDark,
                            ),
                          ),
                          items: EventCategories.categories
                              .map(
                                (cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCategory = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          validator: (val) =>
                              val == null || val.trim().isEmpty
                                  ? 'Description is required'
                                  : null,
                          decoration: const InputDecoration(
                            labelText: 'Event Description',
                            alignLabelWithHint: true,
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(bottom: 40),
                              child: Icon(
                                Icons.description_outlined,
                                color: AppColors.skyBlueDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // LOGISTICS & CAPACITY
                  _buildSectionHeader(
                    Icons.place_outlined,
                    'Location & Capacity',
                    'Venue, organizers, and ticketing setup',
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _venueController,
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                        ? 'Venue is required'
                                        : null,
                                decoration: const InputDecoration(
                                  labelText: 'Venue / Hall',
                                  prefixIcon: Icon(
                                    Icons.location_on_outlined,
                                    color: AppColors.peachDark,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _organizerController,
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                        ? 'Organizer is required'
                                        : null,
                                decoration: const InputDecoration(
                                  labelText: 'Organizer Club / Dept',
                                  prefixIcon: Icon(
                                    Icons.groups_outlined,
                                    color: AppColors.pinkDark,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _capacityController,
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  final num = int.tryParse(val.trim());
                                  if (num == null || num <= 0) {
                                    return 'Must be > 0';
                                  }
                                  return null;
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Capacity (Seats)',
                                  prefixIcon: Icon(
                                    Icons.chair_outlined,
                                    color: AppColors.sageDark,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _feeController,
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  final num = double.tryParse(val.trim());
                                  if (num == null || num < 0) {
                                    return 'Must be >= 0';
                                  }
                                  return null;
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Fee (₹ 0 = Free)',
                                  prefixIcon: Icon(
                                    Icons.payments_outlined,
                                    color: AppColors.skyBlueDark,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SCHEDULE & STATUS
                  _buildSectionHeader(
                    Icons.schedule_outlined,
                    'Schedule & Status',
                    'Dates, times, and publication status',
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _startTimeController,
                                decoration: const InputDecoration(
                                  labelText: 'Start Time',
                                  prefixIcon: Icon(
                                    Icons.access_time,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _endTimeController,
                                decoration: const InputDecoration(
                                  labelText: 'End Time',
                                  prefixIcon: Icon(
                                    Icons.access_time_filled,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context, false),
                                borderRadius: BorderRadius.circular(12),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Event Date',
                                    prefixIcon: Icon(
                                      Icons.calendar_today_outlined,
                                      color: AppColors.sageDark,
                                    ),
                                  ),
                                  child: Text(
                                    DateFormatter.formatDate(_selectedDate),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context, true),
                                borderRadius: BorderRadius.circular(12),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Deadline Date',
                                    prefixIcon: Icon(
                                      Icons.event_available_outlined,
                                      color: AppColors.pinkDark,
                                    ),
                                  ),
                                  child: Text(
                                    DateFormatter.formatDate(
                                      _selectedDeadline,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          initialValue: _selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Event Status',
                            prefixIcon: Icon(
                              Icons.toggle_on_outlined,
                              color: AppColors.lavenderDark,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: EventStatuses.upcoming,
                              child: Text('Upcoming (Published)'),
                            ),
                            DropdownMenuItem(
                              value: EventStatuses.ongoing,
                              child: Text('Ongoing (In Progress)'),
                            ),
                            DropdownMenuItem(
                              value: EventStatuses.completed,
                              child: Text('Completed'),
                            ),
                            DropdownMenuItem(
                              value: EventStatuses.cancelled,
                              child: Text('Cancelled (Unpublished)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedStatus = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ELIGIBILITY CONFIGURATION
                  _buildSectionHeader(
                    Icons.how_to_reg_outlined,
                    'Eligibility Criteria',
                    'Specify target academic years, departments, and prerequisites',
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Target Academic Years
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Target Academic Years',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textMain,
                              ),
                            ),
                            Row(
                              children: [
                                FilterChip(
                                  selected: _allYears,
                                  label: const Text('All Years'),
                                  selectedColor: AppColors.sageLight,
                                  checkmarkColor: AppColors.sageDark,
                                  labelStyle: TextStyle(
                                    color: _allYears ? AppColors.sageDark : AppColors.textSecondary,
                                    fontWeight: _allYears ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      _allYears = selected;
                                      if (selected) _selectedYears.clear();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: AcademicYears.years.map((year) {
                            final isSelected = !_allYears && _selectedYears.contains(year);
                            return FilterChip(
                              label: Text(year),
                              selected: isSelected,
                              selectedColor: AppColors.lavenderLight,
                              checkmarkColor: AppColors.lavenderDark,
                              labelStyle: TextStyle(
                                color: isSelected ? AppColors.lavenderDark : AppColors.textMain,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _allYears = false;
                                    _selectedYears.add(year);
                                  } else {
                                    _selectedYears.remove(year);
                                    if (_selectedYears.isEmpty) {
                                      _allYears = true;
                                    }
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 18),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 12),

                        // Target Departments
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Target Departments / Branches',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textMain,
                              ),
                            ),
                            FilterChip(
                              selected: _allDepartments,
                              label: const Text('All Branches'),
                              selectedColor: AppColors.sageLight,
                              checkmarkColor: AppColors.sageDark,
                              labelStyle: TextStyle(
                                color: _allDepartments ? AppColors.sageDark : AppColors.textSecondary,
                                fontWeight: _allDepartments ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  _allDepartments = selected;
                                  if (selected) _selectedDepartments.clear();
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: AcademicDepartments.departments.map((dept) {
                            final isSelected = !_allDepartments && _selectedDepartments.contains(dept);
                            return FilterChip(
                              label: Text(dept),
                              selected: isSelected,
                              selectedColor: AppColors.skyBlueLight,
                              checkmarkColor: AppColors.skyBlueDark,
                              labelStyle: TextStyle(
                                color: isSelected ? AppColors.skyBlueDark : AppColors.textMain,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _allDepartments = false;
                                    _selectedDepartments.add(dept);
                                  } else {
                                    _selectedDepartments.remove(dept);
                                    if (_selectedDepartments.isEmpty) {
                                      _allDepartments = true;
                                    }
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 18),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 12),

                        // Additional Requirements / Min CGPA
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _minCgpaController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Min CGPA (Optional)',
                                  hintText: 'e.g. 7.5 (0 = None)',
                                  prefixIcon: Icon(Icons.star_outline, color: AppColors.sunnyYellow),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _requirementsController,
                                decoration: const InputDecoration(
                                  labelText: 'Special Requirements / Notes',
                                  hintText: 'e.g. Laptop required, ID card',
                                  prefixIcon: Icon(Icons.rule_outlined, color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // COORDINATOR MANAGEMENT
                  _buildSectionHeader(
                    Icons.contact_phone_outlined,
                    'Event Coordinators',
                    'Add contact persons for student inquiries and support',
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_coordinators.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.lavenderLight.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.lavender.withValues(alpha: 0.3),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.person_add_alt_1_outlined,
                                  size: 36,
                                  color: AppColors.lavenderDark,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'No coordinators added yet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Add faculty or student coordinators for event inquiries',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _showCoordinatorDialog(),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Coordinator'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.lavender,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _coordinators.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final coord = _coordinators[index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
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
                                        Icons.person,
                                        color: AppColors.lavenderDark,
                                        size: 20,
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
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.lavenderDark,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.phone,
                                                size: 13,
                                                color: AppColors.textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                coord.phone,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              const Icon(
                                                Icons.email_outlined,
                                                size: 13,
                                                color: AppColors.textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  coord.email,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (coord.whatsapp.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.chat,
                                                  size: 12,
                                                  color: AppColors.mintDark,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'WhatsApp: ${coord.whatsapp}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.mintDark,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                      tooltip: 'Edit Coordinator',
                                      onPressed: () => _showCoordinatorDialog(
                                        initialCoordinator: coord,
                                        editIndex: index,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.pinkDark),
                                      tooltip: 'Remove Coordinator',
                                      onPressed: () {
                                        setState(() {
                                          _coordinators.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _showCoordinatorDialog(),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Another Coordinator'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.lavenderDark,
                              side: const BorderSide(color: AppColors.lavender),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Saving Event...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              isEditing ? 'UPDATE EVENT' : 'CREATE EVENT',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryThemePlaceholder(
    Color catColor,
    Color catDarkColor,
    IconData catIcon,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: catColor),
          ),
          child: Icon(catIcon, size: 36, color: catDarkColor),
        ),
        const SizedBox(height: 10),
        Text(
          '$_selectedCategory Event Theme',
          style: TextStyle(
            color: catDarkColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Auto-styled with pastel accents',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textMain),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
