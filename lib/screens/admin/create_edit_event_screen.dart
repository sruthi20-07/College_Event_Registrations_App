import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/storage_service.dart';
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
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _venueController;
  late TextEditingController _organizerController;
  late TextEditingController _capacityController;
  late TextEditingController _feeController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _posterUrlController;

  String _selectedCategory = EventCategories.technical;
  String _selectedStatus = EventStatuses.upcoming;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  DateTime _selectedDeadline = DateTime.now().add(const Duration(days: 6));

  Uint8List? _selectedImageBytes;
  bool _isLoading = false;
  bool _isUploadingPoster = false;

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

    if (e != null) {
      _selectedCategory = e.category;
      _selectedStatus = e.status;
      _selectedDate = e.date;
      _selectedDeadline = e.registrationDeadline;
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
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          _showSnackBar('Image file size must be less than 5MB', isError: true);
          return;
        }

        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: ${e.toString()}', isError: true);
    }
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

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final int capacity = int.tryParse(_capacityController.text.trim()) ?? 0;
    final double fee = double.tryParse(_feeController.text.trim()) ?? 0.0;

    if (capacity <= 0) {
      _showSnackBar('Capacity must be greater than 0', isError: true);
      return;
    }

    if (fee < 0) {
      _showSnackBar('Registration fee cannot be negative', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String finalPosterUrl = _posterUrlController.text.trim();

      // UPLOAD IMAGE TO FIREBASE STORAGE IF SELECTED
      if (_selectedImageBytes != null) {
        setState(() => _isUploadingPoster = true);
        final tempId = isEditing
            ? widget.event!.id
            : 'evt_${DateTime.now().millisecondsSinceEpoch}';

        finalPosterUrl = await _storageService.uploadEventPosterBytes(
          _selectedImageBytes!,
          tempId,
        );
        setState(() => _isUploadingPoster = false);
      }

      if (finalPosterUrl.isEmpty) {
        finalPosterUrl = 'assets/images/default_event.jpg';
      }

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
      _showSnackBar('Failed to save event: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploadingPoster = false;
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

  @override
  Widget build(BuildContext context) {
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
                      border: Border.all(color: AppColors.primarySage.withValues(alpha: 0.5)),
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
                            isEditing ? Icons.edit_calendar_outlined : Icons.add_circle_outline,
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
                                isEditing ? 'Update Event Details' : 'Fill in Event Details',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.sageDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Provide complete details for students to discover and register',
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

                  // POSTER UPLOAD SECTION
                  _buildSectionHeader(Icons.image_outlined, 'Event Poster', 'Upload a cover image or provide a link'),
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
                          height: 180,
                          decoration: BoxDecoration(
                            color: AppColors.skyBlueLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.pastelSkyBlue,
                            ),
                          ),
                          child: _selectedImageBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.memory(
                                    _selectedImageBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : (_posterUrlController.text.startsWith('http')
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.network(
                                          _posterUrlController.text,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              _buildPosterPlaceholder(),
                                        ),
                                      )
                                    : _buildPosterPlaceholder()),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.sageDark),
                                foregroundColor: AppColors.sageDark,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.photo_library_outlined, size: 18),
                              label: const Text('From Gallery'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.camera),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.lavenderDark),
                                foregroundColor: AppColors.lavenderDark,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.camera_alt_outlined, size: 18),
                              label: const Text('Camera'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _posterUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Or paste Poster Image URL (Optional)',
                            hintText: 'https://...',
                            prefixIcon: Icon(Icons.link_outlined, color: AppColors.textSecondary),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // BASIC DETAILS
                  _buildSectionHeader(Icons.info_outline, 'Basic Information', 'Core event details and classification'),
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
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Event title is required'
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Event Name / Title',
                            prefixIcon: Icon(Icons.event_outlined, color: AppColors.sageDark),
                          ),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Event Category',
                            prefixIcon: Icon(Icons.category_outlined, color: AppColors.lavenderDark),
                          ),
                          items: EventCategories.categories
                              .map(
                                (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Description is required'
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Event Description',
                            alignLabelWithHint: true,
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(bottom: 40),
                              child: Icon(Icons.description_outlined, color: AppColors.skyBlueDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // LOGISTICS & CAPACITY
                  _buildSectionHeader(Icons.place_outlined, 'Location & Capacity', 'Venue, organizers, and ticketing setup'),
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
                                validator: (val) => val == null || val.trim().isEmpty
                                    ? 'Venue is required'
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'Venue / Hall',
                                  prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.peachDark),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _organizerController,
                                validator: (val) => val == null || val.trim().isEmpty
                                    ? 'Organizer is required'
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'Organizer Club / Dept',
                                  prefixIcon: Icon(Icons.groups_outlined, color: AppColors.pinkDark),
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
                                  prefixIcon: Icon(Icons.chair_outlined, color: AppColors.sageDark),
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
                                  prefixIcon: Icon(Icons.payments_outlined, color: AppColors.skyBlueDark),
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
                  _buildSectionHeader(Icons.schedule_outlined, 'Schedule & Status', 'Dates, times, and publication status'),
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
                                  prefixIcon: Icon(Icons.access_time, color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _endTimeController,
                                decoration: const InputDecoration(
                                  labelText: 'End Time',
                                  prefixIcon: Icon(Icons.access_time_filled, color: AppColors.textSecondary),
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
                                    prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.sageDark),
                                  ),
                                  child: Text(
                                    DateFormatter.formatDate(_selectedDate),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
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
                                    prefixIcon: Icon(Icons.event_available_outlined, color: AppColors.pinkDark),
                                  ),
                                  child: Text(
                                    DateFormatter.formatDate(_selectedDeadline),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
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
                            prefixIcon: Icon(Icons.toggle_on_outlined, color: AppColors.lavenderDark),
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
                            if (val != null) setState(() => _selectedStatus = val);
                          },
                        ),
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
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _isUploadingPoster
                                      ? 'Uploading Poster...'
                                      : 'Saving Event...',
                                  style: const TextStyle(
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

  Widget _buildPosterPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.pastelSkyBlue),
          ),
          child: const Icon(
            Icons.add_photo_alternate_outlined,
            size: 36,
            color: AppColors.skyBlueDark,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Select or paste event poster image',
          style: TextStyle(
            color: AppColors.skyBlueDark,
            fontWeight: FontWeight.w600,
            fontSize: 13,
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
