import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/gamification_service.dart';
import '../../utils/constants.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final GamificationService _gamificationService = GamificationService();

  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralCodeController = TextEditingController();

  String _department = 'Information Technology';
  String _year = '3rd Year';

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Referral validation state
  bool _isValidatingReferral = false;
  bool _isReferralValid = false;
  String? _validatedReferralCode;
  String? _referralFeedbackMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _validateReferral() async {
    final rawCode = _referralCodeController.text.trim();
    if (rawCode.isEmpty) {
      setState(() {
        _isReferralValid = false;
        _validatedReferralCode = null;
        _referralFeedbackMessage = null;
      });
      return;
    }

    setState(() {
      _isValidatingReferral = true;
      _referralFeedbackMessage = null;
    });

    try {
      final res = await _gamificationService.validateReferralCode(rawCode);
      if (!mounted) return;
      setState(() {
        _isValidatingReferral = false;
        _isReferralValid = res.isValid;
        _validatedReferralCode = res.isValid ? res.normalizedCode : null;
        _referralFeedbackMessage = res.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidatingReferral = false;
        _isReferralValid = false;
        _referralFeedbackMessage = 'Unable to validate code. Please try again.';
      });
    }
  }

  void _clearReferral() {
    _referralCodeController.clear();
    setState(() {
      _isReferralValid = false;
      _validatedReferralCode = null;
      _referralFeedbackMessage = null;
    });
  }

  Future<void> _handleSignup() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    // If student typed a referral code but didn't click Validate, validate it now
    String? referralCodeToApply;
    final enteredRef = _referralCodeController.text.trim();
    if (enteredRef.isNotEmpty) {
      if (!_isReferralValid || _validatedReferralCode == null) {
        setState(() => _isLoading = true);
        final check = await _gamificationService.validateReferralCode(
          enteredRef,
        );
        if (!check.isValid) {
          setState(() {
            _isLoading = false;
            _isReferralValid = false;
            _referralFeedbackMessage = check.message;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(check.message),
                backgroundColor: AppColors.pinkDark,
              ),
            );
          }
          return;
        }
        referralCodeToApply = check.normalizedCode;
      } else {
        referralCodeToApply = _validatedReferralCode;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rollNumber: _studentIdController.text.trim(),
        department: _department,
        year: _year,
        role: UserRoles.student,
        referralCode: referralCodeToApply,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.primaryDark),
              SizedBox(width: 10),
              Text(
                'Account created successfully!',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryLight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      final errorMessage = AuthService.getReadableErrorMessage(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.errorDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  errorMessage,
                  style: const TextStyle(
                    color: AppColors.errorDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.pink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.errorDark),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Join College Events',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Fill in your student details to create your account',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // CARD FORM CONTAINER
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // FULL NAME
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              hintText: 'John Doe',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // STUDENT ID
                          TextFormField(
                            controller: _studentIdController,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your Student ID / Roll Number';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Student ID / Roll Number',
                              hintText: '21IT045',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // COLLEGE EMAIL
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your college email';
                              }
                              final emailRegex = RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              );
                              if (!emailRegex.hasMatch(value.trim())) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'College Email',
                              hintText: 'student@college.edu',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // DEPARTMENT DROPDOWN
                          DropdownButtonFormField<String>(
                            initialValue: _department,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Information Technology',
                                child: Text('Information Technology'),
                              ),
                              DropdownMenuItem(
                                value: 'Computer Science',
                                child: Text('Computer Science'),
                              ),
                              DropdownMenuItem(
                                value: 'Electronics',
                                child: Text('Electronics'),
                              ),
                              DropdownMenuItem(
                                value: 'Electrical',
                                child: Text('Electrical'),
                              ),
                              DropdownMenuItem(
                                value: 'Mechanical',
                                child: Text('Mechanical'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _department = value;
                                });
                              }
                            },
                          ),

                          const SizedBox(height: 16),

                          // YEAR DROPDOWN
                          DropdownButtonFormField<String>(
                            initialValue: _year,
                            decoration: const InputDecoration(
                              labelText: 'Year',
                              prefixIcon: Icon(Icons.calendar_month_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: '1st Year',
                                child: Text('1st Year'),
                              ),
                              DropdownMenuItem(
                                value: '2nd Year',
                                child: Text('2nd Year'),
                              ),
                              DropdownMenuItem(
                                value: '3rd Year',
                                child: Text('3rd Year'),
                              ),
                              DropdownMenuItem(
                                value: '4th Year',
                                child: Text('4th Year'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _year = value;
                                });
                              }
                            },
                          ),

                          const SizedBox(height: 16),

                          // PASSWORD
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters long';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Minimum 6 characters',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // CONFIRM PASSWORD
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleSignup(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // REFERRAL CODE INPUT (OPTIONAL)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _isReferralValid
                                    ? AppColors.mintDark
                                    : AppColors.border,
                                width: _isReferralValid ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.card_giftcard_rounded,
                                      size: 18,
                                      color: AppColors.coralDark,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Have a referral code? (Optional)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_referralCodeController.text.isNotEmpty)
                                      GestureDetector(
                                        onTap: _clearReferral,
                                        child: const Text(
                                          'Remove',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.pinkDark,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Enter a classmate\'s referral code. Both of you earn 50 bonus coins when you verify attendance at your first event!',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _referralCodeController,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        textInputAction: TextInputAction.done,
                                        enabled: !_isLoading,
                                        onChanged: (_) {
                                          if (_isReferralValid ||
                                              _referralFeedbackMessage !=
                                                  null) {
                                            setState(() {
                                              _isReferralValid = false;
                                              _validatedReferralCode = null;
                                              _referralFeedbackMessage = null;
                                            });
                                          }
                                        },
                                        decoration: InputDecoration(
                                          hintText: 'e.g. CAMPUS-ABC123',
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                          prefixIcon: const Icon(
                                            Icons.tag_rounded,
                                            size: 18,
                                            color: AppColors.textSecondary,
                                          ),
                                          suffixIcon: _isReferralValid
                                              ? const Icon(
                                                  Icons.check_circle_rounded,
                                                  color: AppColors.mintDark,
                                                  size: 20,
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      height: 44,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          foregroundColor: AppColors.coralDark,
                                          side: const BorderSide(
                                            color: AppColors.coral,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        onPressed:
                                            (_isLoading ||
                                                _isValidatingReferral)
                                            ? null
                                            : _validateReferral,
                                        child: _isValidatingReferral
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color:
                                                          AppColors.coralDark,
                                                    ),
                                              )
                                            : Text(
                                                _isReferralValid
                                                    ? 'Applied'
                                                    : 'Apply',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_referralFeedbackMessage != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        _isReferralValid
                                            ? Icons.check_circle_outline_rounded
                                            : Icons.error_outline_rounded,
                                        size: 14,
                                        color: _isReferralValid
                                            ? AppColors.mintDark
                                            : AppColors.pinkDark,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _referralFeedbackMessage!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: _isReferralValid
                                                ? AppColors.mintDark
                                                : AppColors.pinkDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // SIGNUP BUTTON
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignup,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'CREATE ACCOUNT',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
