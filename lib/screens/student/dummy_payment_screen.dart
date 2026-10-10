import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/event_data.dart';
import '../../models/event_model.dart';
import '../../models/registration_model.dart';
import '../../services/registration_service.dart';
import '../../utils/constants.dart';
import 'registration_confirmation_screen.dart';

class DummyPaymentScreen extends StatefulWidget {
  final EventModel event;
  final RegistrationModel registration;

  const DummyPaymentScreen({
    super.key,
    required this.event,
    required this.registration,
  });

  @override
  State<DummyPaymentScreen> createState() => _DummyPaymentScreenState();
}

class _DummyPaymentScreenState extends State<DummyPaymentScreen> {
  final RegistrationService _registrationService = RegistrationService();

  String _paymentMethod = 'UPI / GPay / PhonePe';
  bool _isProcessing = false;

  String _generateDemoPaymentId() {
    final random = Random();
    const chars = '0123456789ABCDEF';
    final code = List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
    return 'DEMO-PAY-$code';
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
    });

    // Simulate short payment network processing delay (1.5s)
    await Future.delayed(const Duration(milliseconds: 1500));

    final paymentId = _generateDemoPaymentId();

    final completedRegistration = widget.registration.copyWith(
      amount: widget.event.registrationFee,
      paymentStatus: 'paid',
      paymentReference: paymentId,
      registrationStatus: RegistrationStatuses.registered,
      registeredAt: DateTime.now(),
      paidAt: DateTime.now(),
    );

    // Update local in-memory event seat availability
    updateLocalEventSeats(widget.event.id);

    // Try saving to Firestore if database exists; if Firestore fails, log via debugPrint and DO NOT block dummy payment success
    String docId = '${widget.event.id}_${widget.registration.studentId}';
    try {
      docId = await _registrationService.registerForEvent(
        completedRegistration,
      );
    } catch (e) {
      debugPrint('Firestore registration save failed: $e');
    }

    final finalReg = completedRegistration.copyWith(id: docId);

    // Compute updated event model for UI consistency
    final updatedEvent = widget.event.copyWith(
      availableSeats: (widget.event.availableSeats - 1).clamp(
        0,
        widget.event.maxSeats,
      ),
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    // Show Payment Successful snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.cardWhite),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '✓ Payment Successful\nPayment of ₹${widget.event.registrationFee.toInt()} completed successfully. Registration confirmed!',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.sageDark,
        duration: const Duration(seconds: 4),
      ),
    );

    // Navigate to confirmation page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrationConfirmationScreen(
          event: updatedEvent,
          registration: finalReg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fee = widget.event.registrationFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Gateway')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // DEMO BANNER
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.peachLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.pastelPeach),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.peachDark, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'DEMO MODE: No real money will be charged. This simulates a payment gateway for project evaluation.',
                        style: TextStyle(fontSize: 12, color: AppColors.peachDark, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // SUMMARY CARD
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(18),
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
                    Text(
                      'Payment Summary',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _summaryRow('Event Name', widget.event.title),
                    _summaryRow(
                      'Student Name',
                      widget.registration.studentName,
                    ),
                    _summaryRow('Student ID', widget.registration.rollNumber),
                    Divider(height: 24, color: AppColors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Registration Fee',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textMain,
                          ),
                        ),
                        Text(
                          '₹${fee.toInt()}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.sageDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // PAYMENT METHOD SELECTOR
              Text(
                'Select Payment Method',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),

              const SizedBox(height: 12),

              _methodTile(
                'UPI / GPay / PhonePe',
                Icons.account_balance_wallet_outlined,
              ),
              _methodTile('Credit / Debit Card', Icons.credit_card),
              _methodTile('Net Banking', Icons.account_balance),

              const SizedBox(height: 26),

              // ACTION BUTTONS
              ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                child: _isProcessing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.sageDark,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Processing Payment...'),
                        ],
                      )
                    : Text(
                        'PAY ₹${fee.toInt()}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              const SizedBox(height: 10),

              OutlinedButton(
                onPressed: _isProcessing
                    ? null
                    : () {
                        Navigator.pop(context);
                      },
                child: const Text('CANCEL PAYMENT'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodTile(String method, IconData icon) {
    final isSelected = _paymentMethod == method;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.sageLight : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.primarySage : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.pastelSage : AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isSelected ? AppColors.sageDark : AppColors.textSecondary,
            size: 20,
          ),
        ),
        title: Text(
          method,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isSelected ? AppColors.sageDark : AppColors.textMain,
          ),
        ),
        trailing: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSelected ? AppColors.sageDark : AppColors.textSecondary,
        ),
        onTap: () {
          setState(() => _paymentMethod = method);
        },
      ),
    );
  }
}
