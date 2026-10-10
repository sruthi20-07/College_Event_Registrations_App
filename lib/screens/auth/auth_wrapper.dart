import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
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
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            ),
          );
        }

        final User? user = authSnapshot.data;

        // If not logged in -> Login Screen
        if (user == null) {
          return const LoginScreen();
        }

        // Fast-path: Check for fixed admin email
        if (user.email?.toLowerCase() == 'admin@collegeevent.com') {
          return const AdminDashboardScreen();
        }

        // If logged in -> stream user role from Firestore
        return StreamBuilder<UserModel?>(
          stream: authService.streamUserProfile(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                ),
              );
            }

            final UserModel? userModel = profileSnapshot.data;

            if (userModel != null &&
                (userModel.isStaff || userModel.role == 'admin')) {
              return const AdminDashboardScreen();
            }

            return const MainScreen();
          },
        );
      },
    );
  }
}
