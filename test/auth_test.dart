import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:college_event_app/models/user_model.dart';
import 'package:college_event_app/services/auth_service.dart';
import 'package:college_event_app/utils/constants.dart';

void main() {
  group('AuthService Error Message Mapping', () {
    test('Translates common FirebaseAuthException codes into clear readable messages', () {
      final userNotFound = FirebaseAuthException(code: 'user-not-found');
      expect(
        AuthService.getReadableErrorMessage(userNotFound),
        'No account found with this email address.',
      );

      final wrongPassword = FirebaseAuthException(code: 'wrong-password');
      expect(
        AuthService.getReadableErrorMessage(wrongPassword),
        'Incorrect password. Please try again.',
      );

      final invalidCredential = FirebaseAuthException(code: 'invalid-credential');
      expect(
        AuthService.getReadableErrorMessage(invalidCredential),
        'Invalid email or password. Please verify your details.',
      );

      final networkFailed = FirebaseAuthException(code: 'network-request-failed');
      expect(
        AuthService.getReadableErrorMessage(networkFailed),
        'Network error. Please check your internet connection.',
      );

      final tooManyRequests = FirebaseAuthException(code: 'too-many-requests');
      expect(
        AuthService.getReadableErrorMessage(tooManyRequests),
        'Too many failed login attempts. Please try again later.',
      );

      final userDisabled = FirebaseAuthException(code: 'user-disabled');
      expect(
        AuthService.getReadableErrorMessage(userDisabled),
        'This user account has been disabled.',
      );

      final opNotAllowed = FirebaseAuthException(code: 'operation-not-allowed');
      expect(
        AuthService.getReadableErrorMessage(opNotAllowed),
        'Email/Password sign-in is not enabled in Firebase Console.',
      );
    });

    test('Handles generic exceptions without raw prefix strings', () {
      final genericException = Exception('Failed to connect to Firebase backend');
      expect(
        AuthService.getReadableErrorMessage(genericException),
        'Failed to connect to Firebase backend',
      );
    });
  });

  group('User Role Resolution and Permissions', () {
    test('Identifies admin, faculty, and coordinator as staff roles', () {
      expect(UserRoles.isAdminOrStaff(UserRoles.admin), isTrue);
      expect(UserRoles.isAdminOrStaff(UserRoles.faculty), isTrue);
      expect(UserRoles.isAdminOrStaff(UserRoles.coordinator), isTrue);
      expect(UserRoles.isAdminOrStaff(UserRoles.student), isFalse);
      expect(UserRoles.isAdminOrStaff('guest'), isFalse);
    });

    test('UserModel accurately resolves student and admin role properties', () {
      final student = UserModel(
        uid: 'user_student_101',
        name: 'Aarav Patel',
        email: 'aarav@college.edu',
        rollNumber: 'IT-2026-45',
        department: 'Information Technology',
        year: '3rd Year',
        role: UserRoles.student,
      );

      expect(student.isStudent, isTrue);
      expect(student.isAdmin, isFalse);
      expect(student.isStaff, isFalse);

      final admin = UserModel(
        uid: 'user_admin_999',
        name: 'College Admin',
        email: 'admin@collegeevent.com',
        rollNumber: 'ADMIN-01',
        department: 'Administration',
        year: 'Staff',
        role: UserRoles.admin,
      );

      expect(admin.isAdmin, isTrue);
      expect(admin.isStaff, isTrue);
      expect(admin.isStudent, isFalse);
    });

    test('UserModel maps from Firestore document and defaults missing role to student', () {
      final rawData = {
        'name': 'Priya Singh',
        'email': 'priya@college.edu',
        'rollNumber': 'CS-89',
        'department': 'Computer Science',
        'year': '2nd Year',
      };

      final parsed = UserModel.fromMap(rawData, 'user_doc_888');
      expect(parsed.uid, 'user_doc_888');
      expect(parsed.name, 'Priya Singh');
      expect(parsed.role, UserRoles.student);
      expect(parsed.isStudent, isTrue);
    });
  });
}
