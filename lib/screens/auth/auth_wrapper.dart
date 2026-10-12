import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../admin/admin_dashboard_screen.dart';
import '../main_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.coral),
            ),
          );
        }

        final User? user = authSnapshot.data;

        // If not logged in -> Show LoginScreen
        if (user == null) {
          return const LoginScreen();
        }

        // Fast-path: Check for fixed admin email
        final cleanEmail = user.email?.toLowerCase().trim();
        if (cleanEmail == 'admin@collegeevent.com' || cleanEmail == 'admin@college.edu') {
          return const AdminDashboardScreen(key: ValueKey('admin_direct'));
        }

        // Keyed by user.uid so account switching immediately clears stale profile state
        return _UserProfileResolver(
          key: ValueKey(user.uid),
          user: user,
        );
      },
    );
  }
}

class _UserProfileResolver extends StatefulWidget {
  final User user;

  const _UserProfileResolver({
    super.key,
    required this.user,
  });

  @override
  State<_UserProfileResolver> createState() => _UserProfileResolverState();
}

class _UserProfileResolverState extends State<_UserProfileResolver> {
  final AuthService _authService = AuthService();

  UserModel? _userModel;
  bool _isLoading = true;
  bool _isProfileMissing = false;
  String? _errorMessage;
  StreamSubscription<UserModel?>? _profileSubscription;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _resolveProfile();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _resolveProfile() {
    _profileSubscription?.cancel();
    _timeoutTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isProfileMissing = false;
      _errorMessage = null;
    });

    // Safety timeout to prevent infinite spinner if Firestore stream stalls
    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Connection timed out while loading user profile. Please check your network and retry.';
        });
      }
    });

    try {
      _profileSubscription = _authService
          .streamUserProfile(widget.user.uid)
          .listen(
        (profile) {
          _timeoutTimer?.cancel();
          if (!mounted) return;

          if (profile != null) {
            setState(() {
              _userModel = profile;
              _isLoading = false;
              _isProfileMissing = false;
              _errorMessage = null;
            });
          } else {
            // Profile document does not exist in Firestore for this authenticated user
            setState(() {
              _userModel = null;
              _isLoading = false;
              _isProfileMissing = true;
              _errorMessage = null;
            });
          }
        },
        onError: (error) {
          _timeoutTimer?.cancel();
          if (!mounted) return;
          debugPrint('Profile stream error: $error');
          setState(() {
            _isLoading = false;
            _userModel = null;
            _isProfileMissing = false;
            _errorMessage =
                'Failed to load profile from Firestore: ${error.toString().replaceAll('Exception: ', '')}';
          });
        },
      );
    } catch (e) {
      _timeoutTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _userModel = null;
        _errorMessage = 'Unexpected error: ${e.toString()}';
      });
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      debugPrint('Error signing out from error screen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.coralLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)),
                ),
                child: const CircularProgressIndicator(
                  color: AppColors.coral,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Loading your profile...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Connecting to Cloud Firestore',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.pinkDark.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.pinkLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.pinkDark.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          size: 40,
                          color: AppColors.pinkDark,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Profile Loading Error',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _handleSignOut,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.logout_rounded, size: 18),
                              label: const Text('Sign Out'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _resolveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.coral,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_isProfileMissing || _userModel == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.yellowDark.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.yellowLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.yellowDark.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(
                          Icons.person_off_outlined,
                          size: 40,
                          color: AppColors.yellowDark,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'User Profile Not Found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No user profile document exists in Firestore for "${widget.user.email}". Please register a student profile or sign in with another account.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _handleSignOut,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.logout_rounded, size: 18),
                              label: const Text('Sign Out'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _resolveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.coral,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry Check'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Role resolution
    if (_userModel!.isStaff || _userModel!.role == UserRoles.admin) {
      return AdminDashboardScreen(
        key: ValueKey('admin_${widget.user.uid}'),
      );
    }

    return MainScreen(
      key: ValueKey('student_${widget.user.uid}'),
    );
  }
}
