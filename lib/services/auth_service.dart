import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  String? get currentUid => currentUser?.uid;

  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return Stream.value(null);
    }
  }

  /// Converts Firebase exceptions into user-friendly error messages
  static String getReadableErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email address.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-credential':
          return 'Invalid email or password. Please verify your details.';
        case 'email-already-in-use':
          return 'An account already exists for this email address.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'Password is too weak. Please use at least 6 characters.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'too-many-requests':
          return 'Too many failed login attempts. Please try again later.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'operation-not-allowed':
          return 'Email/Password sign-in is not enabled in Firebase Console.';
        default:
          return error.message ?? 'Authentication failed. Please try again.';
      }
    }
    return error.toString().replaceAll('Exception: ', '');
  }

  /// Fetches User profile document from Firestore 'users' collection with timeout
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));

      if (doc.exists && doc.data() != null) {
        return UserModel.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      debugPrint('AuthService.getUserProfile error for $uid: $e');
      rethrow;
    }
  }

  /// Checks whether an authenticated user or UserModel profile has administrative / staff access
  bool isAuthorizedStaff(User? authUser, UserModel? userProfile) {
    if (authUser == null) return false;
    final email = (authUser.email ?? '').trim().toLowerCase();
    if (email == 'admin@collegeevent.com' || email == 'admin@college.edu') {
      return true;
    }
    if (userProfile != null && userProfile.isStaff) {
      return true;
    }
    return false;
  }

  /// Streams User profile document from Firestore
  Stream<UserModel?> streamUserProfile(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            return UserModel.fromSnapshot(doc);
          }
          final current = currentUser;
          if (current != null && current.uid == uid) {
            final email = (current.email ?? '').trim().toLowerCase();
            if (email == 'admin@collegeevent.com' || email == 'admin@college.edu') {
              _ensureAdminProfileDoc(uid, current.email ?? 'admin@collegeevent.com');
              return UserModel(
                uid: uid,
                name: 'College Administrator',
                email: current.email ?? 'admin@collegeevent.com',
                rollNumber: 'ADMIN',
                department: 'Administration',
                year: 'Staff',
                role: UserRoles.admin,
              );
            }
          }
          return null;
        });
  }

  Future<void> _ensureAdminProfileDoc(String uid, String email) async {
    try {
      final docRef = _db.collection('users').doc(uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'uid': uid,
          'name': 'College Administrator',
          'email': email,
          'rollNumber': 'ADMIN',
          'department': 'Administration',
          'year': 'Staff',
          'role': UserRoles.admin,
          'isAdmin': true,
          'createdAt': Timestamp.now(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Note: unable to auto-write admin doc: $e');
    }
  }

  /// Creates user account in Firebase Auth and Firestore users collection
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
    required String rollNumber,
    required String department,
    required String year,
    String role = UserRoles.student,
  }) async {
    try {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );

      final String uid = credential.user!.uid;

      final userModel = UserModel(
        uid: uid,
        name: name.trim(),
        email: email.trim(),
        rollNumber: rollNumber.trim(),
        department: department,
        year: year,
        role: role,
        createdAt: DateTime.now(),
      );

      await _db
          .collection('users')
          .doc(uid)
          .set(userModel.toMap())
          .timeout(const Duration(seconds: 10));

      return userModel;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to save user profile: ${e.toString()}');
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
      return credential;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  /// Updates student WhatsApp notification preferences
  Future<void> updateWhatsAppPreferences({
    required String uid,
    required String whatsappNumber,
    required bool whatsappConsent,
  }) async {
    try {
      await _db.collection('users').doc(uid).set({
        'whatsappNumber': whatsappNumber.trim(),
        'whatsappConsent': whatsappConsent,
        'whatsappConsentAt': whatsappConsent ? Timestamp.now() : null,
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error updating WhatsApp preferences: $e');
      rethrow;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('AuthService.signOut error: $e');
      rethrow;
    }
  }
}
