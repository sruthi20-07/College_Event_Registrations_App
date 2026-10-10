import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  /// Fetches User profile document from Firestore 'users' collection
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Streams User profile document from Firestore
  Stream<UserModel?> streamUserProfile(String uid) {
    try {
      return _db
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((doc) => doc.exists ? UserModel.fromSnapshot(doc) : null);
    } catch (_) {
      return Stream.value(null);
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

      await _db.collection('users').doc(uid).set(userModel.toMap());

      return userModel;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to save user profile: ${e.toString()}');
    }
  }

  /// Sign in with email and password
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final String uid = credential.user!.uid;
      final profile = await getUserProfile(uid);

      if (profile == null) {
        // Fallback user model if Firestore profile missing
        return UserModel(
          uid: uid,
          name: email.split('@').first,
          email: email.trim(),
          rollNumber: 'N/A',
          department: 'General',
          year: '1st Year',
          role: UserRoles.student,
        );
      }

      return profile;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }
}
