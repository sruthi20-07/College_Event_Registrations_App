import 'package:flutter/material.dart';

import '../../data/event_data.dart';
import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../services/auth_service.dart';
import '../../services/registration_service.dart';
import '../../utils/constants.dart';
import 'dummy_payment_screen.dart';
import 'registration_confirmation_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final EventModel event;

  const RegistrationScreen({super.key, required this.event});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final formKey = GlobalKey<FormState>();
  final RegistrationService _registrationService = RegistrationService();
  final AuthService _authService = AuthService();

  late TextEditingController nameController;
  late TextEditingController rollController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController sectionController;

  String department = 'Information Technology';
  String year = '3rd Year';

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = _authService.currentUser;
    nameController = TextEditingController(text: user?.displayName ?? '');
    rollController = TextEditingController();
    emailController = TextEditingController(text: user?.email ?? '');
    phoneController = TextEditingController();
    sectionController = TextEditingController(text: 'A');

    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final uid = _authService.currentUid;
    if (uid != null) {
      final profile = await _authService.getUserProfile(uid);
      if (profile != null && mounted) {
        setState(() {
          if (profile.name.isNotEmpty) {
            nameController.text = profile.name;
          }
          if (profile.rollNumber.isNotEmpty) {
            rollController.text = profile.rollNumber;
          }
          if (profile.email.isNotEmpty) {
            emailController.text = profile.email;
          }
          if (profile.department.isNotEmpty) {
            department = profile.department;
          }
          if (profile.year.isNotEmpty) {
            year = profile.year;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    rollController.dispose();
    emailController.dispose();
    phoneController.dispose();
    sectionController.dispose();
    super.dispose();
  }

  Future<void> _handleRegistrationProceed() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    final currentUid =
        _authService.currentUid ??
        'demo_user_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // PRE-REGISTRATION VALIDATION CHECKS
      if (widget.event.availableSeats <= 0 || widget.event.isFull) {
        _showErrorDialog('No more registrations available for this event.');
        return;
      }

      if (!widget.event.isPublished) {
        _showErrorDialog('Registration for this event is closed.');
        return;
      }

      if (widget.event.isDeadlinePassed) {
        _showErrorDialog('Registration for this event is closed.');
        return;
      }

      // Check if duplicate registration exists
      bool isAlreadyRegistered = false;
      try {
        final existingRegs = await _registrationService
            .streamStudentRegistrations(currentUid)
            .first;
        isAlreadyRegistered = existingRegs.any(
          (r) => r.eventId == widget.event.id && r.isRegistered,
        );
      } catch (e) {
        debugPrint('Firestore registration check failed: $e');
      }

      if (isAlreadyRegistered) {
        _showErrorDialog('You are already registered for this event.');
        return;
      }

      final registrationDraft = RegistrationModel(
        id: '',
        eventId: widget.event.id,
        studentId: currentUid,
        studentName: nameController.text.trim(),
        studentEmail: emailController.text.trim(),
        rollNumber: rollController.text.trim(),
        phone: phoneController.text.trim(),
        department: department,
        year: year,
        section: sectionController.text.trim(),
        amount: widget.event.registrationFee,
        paymentStatus: widget.event.isPaid
            ? PaymentStatuses.pending
            : PaymentStatuses.free,
        paymentReference: widget.event.isPaid ? '' : 'FREE',
      );

      // BRANCHING: IF PAID -> DUMMY PAYMENT, IF FREE -> DIRECT REGISTRATION
      if (widget.event.isPaid) {
        if (!mounted) return;
        setState(() => isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DummyPaymentScreen(
              event: widget.event,
              registration: registrationDraft,
            ),
          ),
        );
      } else {
        // Free event -> update local seats and save to Firestore if available
        updateLocalEventSeats(widget.event.id);

        String docId = '${widget.event.id}_${registrationDraft.studentId}';
        try {
          docId = await _registrationService.registerForEvent(
            registrationDraft,
          );
        } catch (e) {
          debugPrint('Firestore registration save failed: $e');
        }

        final completedReg = registrationDraft.copyWith(id: docId);
        final updatedEvent = widget.event.copyWith(
          availableSeats: (widget.event.availableSeats - 1).clamp(
            0,
            widget.event.maxSeats,
          ),
        );

        if (!mounted) return;
        setState(() => isLoading = false);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrationConfirmationScreen(
              event: updatedEvent,
              registration: completedReg,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: AppColors.cardWhite,
          title: Text(
            'Registration Error',
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
          ),
          content: Text(
            message,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarySage,
                foregroundColor: AppColors.sageDark,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fee = widget.event.registrationFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Event Registration')),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.event.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Fill in your details to register (${widget.event.isPaid ? '₹${fee.toInt()} Registration Fee' : 'FREE Event'})',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 22),

              // FULL NAME
              buildField(
                controller: nameController,
                label: 'Full Name',
                icon: Icons.person_outline,
              ),

              const SizedBox(height: 14),

              // STUDENT ID
              buildField(
                controller: rollController,
                label: 'Student ID / Roll Number',
                icon: Icons.badge_outlined,
              ),

              const SizedBox(height: 14),

              // EMAIL
              buildField(
                controller: emailController,
                label: 'College Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!val.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // PHONE NUMBER
              buildField(
                controller: phoneController,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (val.trim().length < 10) {
                    return 'Enter a valid 10-digit phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // DEPARTMENT & YEAR
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: department,
                decoration: InputDecoration(
                  labelText: 'Branch / Department',
                  prefixIcon: Icon(Icons.school_outlined, color: AppColors.textSecondary),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Information Technology',
                    child: Text(
                      'Information Technology',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Computer Science',
                    child: Text(
                      'Computer Science',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Electronics',
                    child: Text('Electronics', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'Electrical',
                    child: Text('Electrical', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'Mechanical',
                    child: Text('Mechanical', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => department = value);
                },
              ),

              const SizedBox(height: 14),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: year,
                      decoration: InputDecoration(
                        labelText: 'Year',
                        prefixIcon: Icon(
                          Icons.calendar_month_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '1st Year',
                          child: Text(
                            '1st Year',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: '2nd Year',
                          child: Text(
                            '2nd Year',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: '3rd Year',
                          child: Text(
                            '3rd Year',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: '4th Year',
                          child: Text(
                            '4th Year',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => year = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: buildField(
                      controller: sectionController,
                      label: 'Section',
                      icon: Icons.class_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleRegistrationProceed,
                  child: isLoading
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.sageDark,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.event.isPaid
                              ? 'PROCEED TO PAYMENT (₹${fee.toInt()})'
                              : 'CONFIRM REGISTRATION',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator:
          validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter $label';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
      ),
    );
  }
}
