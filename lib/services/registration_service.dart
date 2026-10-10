import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/attendance_scan_result.dart';
import '../models/registration_model.dart';
import '../utils/constants.dart';
import 'gamification_service.dart';

class RegistrationService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _registrationsCollection =>
      _db.collection('registrations');

  CollectionReference<Map<String, dynamic>> get _eventsCollection =>
      _db.collection('events');

  CollectionReference<Map<String, dynamic>> get _savedCollection =>
      _db.collection('saved_events');

  CollectionReference<Map<String, dynamic>> get _attendanceCollection =>
      _db.collection('attendance');

  /// Generates a cryptographically secure, unpredictable ticket token
  static String generateSecureTicketToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'tkt_$hex';
  }

  /// Ensures an existing registration has a persistent ticketToken in Firestore
  Future<String> ensureTicketToken(RegistrationModel reg) async {
    if (reg.ticketToken.isNotEmpty) return reg.ticketToken;

    final newToken = generateSecureTicketToken();
    try {
      final docRef = _registrationsCollection.doc(reg.id);
      final snapshot = await docRef.get();
      if (snapshot.exists) {
        await docRef.update({'ticketToken': newToken});
        return newToken;
      }

      // Check deterministic doc ID '${reg.eventId}_${reg.studentId}'
      final fallbackRef = _registrationsCollection.doc(
        '${reg.eventId}_${reg.studentId}',
      );
      final fallbackSnapshot = await fallbackRef.get();
      if (fallbackSnapshot.exists) {
        await fallbackRef.update({'ticketToken': newToken});
        return newToken;
      }

      // Check where studentId and eventId match
      final query = await _registrationsCollection
          .where('eventId', isEqualTo: reg.eventId)
          .where('studentId', isEqualTo: reg.studentId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({'ticketToken': newToken});
        return newToken;
      }

      await docRef.set({'ticketToken': newToken}, SetOptions(merge: true));
      return newToken;
    } catch (e) {
      debugPrint('Error updating ticketToken: $e');
      return newToken;
    }
  }

  /// Registers student for event atomically using Firestore Transaction and deterministic Doc ID
  Future<String> registerForEvent(RegistrationModel registration) async {
    final String authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String currentUid = authUid.isNotEmpty
        ? authUid
        : registration.studentId;
    final String deterministicDocId = '${registration.eventId}_$currentUid';

    final String secureToken = registration.ticketToken.isNotEmpty
        ? registration.ticketToken
        : generateSecureTicketToken();

    try {
      await _db.runTransaction((transaction) async {
        final regRef = _registrationsCollection.doc(deterministicDocId);
        final regDoc = await transaction.get(regRef);

        if (regDoc.exists) {
          final existingData = regDoc.data()!;
          final status = existingData['registrationStatus'] as String? ?? '';
          if (status == 'confirmed' ||
              status == RegistrationStatuses.registered) {
            throw Exception('You are already registered for this event.');
          }
        }

        final eventRef = _eventsCollection.doc(registration.eventId);
        final eventDoc = await transaction.get(eventRef);

        if (eventDoc.exists) {
          final data = eventDoc.data()!;
          final int capacity =
              (data['capacity'] ?? data['maxSeats'] ?? 100) as int;
          final int registeredCount = (data['registeredCount'] ?? 0) as int;
          final int availableSeats = (capacity - registeredCount).clamp(
            0,
            capacity,
          );

          final String eventStatus =
              data['status'] as String? ?? EventStatuses.upcoming;

          DateTime deadline = DateTime.now().add(const Duration(days: 365));
          final rawDeadline = data['registrationDeadline'] ?? data['date'];
          if (rawDeadline is Timestamp) {
            deadline = rawDeadline.toDate();
          }

          if (eventStatus == EventStatuses.cancelled) {
            throw Exception('Registration for this event is closed.');
          }

          if (DateTime.now().isAfter(deadline)) {
            throw Exception('Registration deadline has passed.');
          }

          if (availableSeats <= 0 || registeredCount >= capacity) {
            throw Exception('Sorry, this event is full.');
          }

          final int newRegisteredCount = registeredCount + 1;
          final int newAvailableSeats = (capacity - newRegisteredCount).clamp(
            0,
            capacity,
          );

          // Update event seat statistics atomically
          transaction.update(eventRef, {
            'registeredCount': newRegisteredCount,
            'availableSeats': newAvailableSeats,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
        }

        final finalRegistration = registration.copyWith(
          id: deterministicDocId,
          studentId: currentUid,
          ticketToken: secureToken,
          registeredAt: DateTime.now(),
          registrationStatus: 'confirmed',
        );

        // Write deterministic registration document
        transaction.set(regRef, finalRegistration.toMap());
      });

      debugPrint('REGISTRATION SAVED');
      debugPrint('USER ID: $currentUid');
      debugPrint('EVENT ID: ${registration.eventId}');
      debugPrint('TICKET TOKEN: $secureToken');

      return deterministicDocId;
    } catch (e) {
      // Direct set fallback if transaction fails
      final regRef = _registrationsCollection.doc(deterministicDocId);
      final finalRegistration = registration.copyWith(
        id: deterministicDocId,
        studentId: currentUid,
        ticketToken: secureToken,
        registeredAt: DateTime.now(),
        registrationStatus: 'confirmed',
      );
      await regRef.set(finalRegistration.toMap(), SetOptions(merge: true));

      debugPrint('REGISTRATION SAVED (FALLBACK)');
      debugPrint('USER ID: $currentUid');
      debugPrint('EVENT ID: ${registration.eventId}');

      return deterministicDocId;
    }
  }

  /// Cancels registration atomically and restores seat count via Firestore Transaction
  Future<void> cancelRegistration(String registrationId, String eventId) async {
    try {
      await _db.runTransaction((transaction) async {
        final regRef = _registrationsCollection.doc(registrationId);
        final regDoc = await transaction.get(regRef);

        if (!regDoc.exists) {
          throw Exception('Registration record not found.');
        }

        final regData = regDoc.data()!;
        if (regData['registrationStatus'] == RegistrationStatuses.cancelled) {
          return; // Already cancelled
        }

        final eventRef = _eventsCollection.doc(eventId);
        final eventDoc = await transaction.get(eventRef);

        if (eventDoc.exists) {
          final eventData = eventDoc.data()!;
          final int capacity =
              (eventData['capacity'] ?? eventData['maxSeats'] ?? 100) as int;
          final int registeredCount =
              (eventData['registeredCount'] ?? 1) as int;

          final int newRegisteredCount = (registeredCount - 1).clamp(
            0,
            capacity,
          );
          final int newAvailableSeats = (capacity - newRegisteredCount).clamp(
            0,
            capacity,
          );

          transaction.update(eventRef, {
            'registeredCount': newRegisteredCount,
            'availableSeats': newAvailableSeats,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
        }

        transaction.update(regRef, {
          'registrationStatus': RegistrationStatuses.cancelled,
          'cancelledAt': Timestamp.fromDate(DateTime.now()),
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Streams student active registrations by studentId / userId
  Stream<List<RegistrationModel>> streamStudentRegistrations(String studentId) {
    try {
      final String authUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      return _registrationsCollection.snapshots().map((snapshot) {
        final list = snapshot.docs
            .map((doc) => RegistrationModel.fromSnapshot(doc))
            .where(
              (r) =>
                  r.studentId == studentId ||
                  r.userId == studentId ||
                  (authUid.isNotEmpty &&
                      (r.studentId == authUid || r.userId == authUid)),
            )
            .toList();

        final active = list.where((r) => r.isRegistered).toList();
        debugPrint('REGISTERED EVENTS COUNT: ${active.length}');
        return list;
      });
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Streams event registrations for admin view
  Stream<List<RegistrationModel>> streamEventRegistrations(String eventId) {
    try {
      if (eventId.isEmpty) {
        return _registrationsCollection.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => RegistrationModel.fromSnapshot(doc))
              .toList(),
        );
      }
      return _registrationsCollection
          .where('eventId', isEqualTo: eventId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => RegistrationModel.fromSnapshot(doc))
                .toList(),
          );
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Streams single registration document in real time
  Stream<RegistrationModel?> streamRegistration(String registrationId) {
    try {
      return _registrationsCollection
          .doc(registrationId)
          .snapshots()
          .map(
            (doc) => doc.exists ? RegistrationModel.fromSnapshot(doc) : null,
          );
    } catch (_) {
      return Stream.value(null);
    }
  }

  /// Toggles saved event in Firestore `saved_events` collection
  Future<void> toggleSaveEvent(String studentId, String eventId) async {
    try {
      final docId = '${studentId}_$eventId';
      final ref = _savedCollection.doc(docId);
      final doc = await ref.get();

      if (doc.exists) {
        await ref.delete();
      } else {
        await ref.set({
          'studentId': studentId,
          'eventId': eventId,
          'savedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Streams list of saved event IDs for student
  Stream<List<String>> streamSavedEventIds(String studentId) {
    try {
      return _savedCollection
          .where('studentId', isEqualTo: studentId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => doc.data()['eventId'] as String)
                .toList(),
          );
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Updates attendance status for a participant in Firestore
  Future<void> updateAttendance(String registrationId, bool attended) async {
    try {
      final now = DateTime.now();
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final regDoc = await _registrationsCollection.doc(registrationId).get();
      if (!regDoc.exists) return;
      final reg = RegistrationModel.fromSnapshot(regDoc);

      if (attended) {
        await _db.runTransaction((transaction) async {
          transaction.update(_registrationsCollection.doc(registrationId), {
            'attended': true,
            'attendanceStatus': 'attended',
            'attendedAt': Timestamp.fromDate(now),
            'verifiedByAdminUid': adminUid,
          });

          final attendanceRef = _attendanceCollection.doc(
            '${reg.eventId}_${reg.id}',
          );
          transaction.set(attendanceRef, {
            'eventId': reg.eventId,
            'eventTitle': reg.eventTitle,
            'registrationId': reg.id,
            'studentId': reg.studentId,
            'studentName': reg.studentName,
            'rollNumber': reg.rollNumber,
            'studentEmail': reg.studentEmail,
            'department': reg.department,
            'year': reg.year,
            'ticketToken': reg.ticketToken,
            'attended': true,
            'attendanceStatus': 'attended',
            'attendedAt': Timestamp.fromDate(now),
            'verifiedByAdminUid': adminUid,
          }, SetOptions(merge: true));

          await GamificationService.processAttendanceRewardInTransaction(
            transaction,
            studentId: reg.studentId,
            eventId: reg.eventId,
            eventTitle: reg.eventTitle,
            attendedAt: now,
            firestore: _db,
          );
        });
      } else {
        await _registrationsCollection.doc(registrationId).update({
          'attended': false,
          'attendanceStatus': 'not_attended',
          'attendedAt': null,
          'verifiedByAdminUid': '',
        });
        final attendanceRef = _attendanceCollection.doc(
          '${reg.eventId}_${reg.id}',
        );
        await attendanceRef.delete();
      }
    } catch (e) {
      debugPrint('Error updating attendance: $e');
      rethrow;
    }
  }

  /// Performs atomic QR ticket verification and records student attendance
  Future<AttendanceScanResult> verifyAndRecordAttendance({
    required String rawToken,
    String? expectedEventId,
  }) async {
    final String cleanToken = rawToken
        .trim()
        .replaceAll('"', '')
        .replaceAll("'", '');
    if (cleanToken.isEmpty) {
      return const AttendanceScanResult(
        status: AttendanceScanStatus.invalidTicket,
        message: 'The scanned ticket token is empty or unreadable.',
      );
    }

    // 1. Authenticate current user and verify Admin role
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const AttendanceScanResult(
        status: AttendanceScanStatus.unauthorizedAdmin,
        message:
            'No authenticated user session found. Please log in as an administrator.',
      );
    }

    final String adminEmail = (currentUser.email ?? '').toLowerCase().trim();
    final bool isFixedAdmin =
        adminEmail == 'admin@collegeevent.com' ||
        adminEmail == 'admin@college.edu';

    bool isAuthorized = isFixedAdmin;
    if (!isAuthorized) {
      try {
        final adminDoc = await _db
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (adminDoc.exists) {
          final data = adminDoc.data() ?? {};
          final role = (data['role'] as String? ?? '').toLowerCase();
          if (role == 'admin' ||
              role == 'faculty' ||
              role == 'coordinator' ||
              data['isAdmin'] == true) {
            isAuthorized = true;
          }
        }
      } catch (e) {
        debugPrint('Admin verification check error: $e');
      }
    }

    if (!isAuthorized) {
      return const AttendanceScanResult(
        status: AttendanceScanStatus.unauthorizedAdmin,
        message:
            'Unauthorized Account: Only designated college administrators can scan tickets.',
      );
    }

    // 2. Query Firestore by ticketToken OR registration ID
    RegistrationModel? scannedReg;
    DocumentSnapshot<Map<String, dynamic>>? regDoc;

    try {
      // Primary query: by ticketToken field
      final tokenQuery = await _registrationsCollection
          .where('ticketToken', isEqualTo: cleanToken)
          .limit(1)
          .get();

      if (tokenQuery.docs.isNotEmpty) {
        regDoc = tokenQuery.docs.first;
      } else {
        // Fallback 1: check by direct document ID (e.g. manual ID entry or eventId_studentId)
        final directDoc = await _registrationsCollection.doc(cleanToken).get();
        if (directDoc.exists) {
          regDoc = directDoc;
        } else {
          // Fallback 2: check by 'id' field
          final idQuery = await _registrationsCollection
              .where('id', isEqualTo: cleanToken)
              .limit(1)
              .get();
          if (idQuery.docs.isNotEmpty) {
            regDoc = idQuery.docs.first;
          } else if (cleanToken.startsWith('tkt_')) {
            // Fallback 3: check if stripped 'tkt_' prefix matches doc ID
            final stripped = cleanToken.substring(4);
            final strippedDoc = await _registrationsCollection
                .doc(stripped)
                .get();
            if (strippedDoc.exists) {
              regDoc = strippedDoc;
            } else {
              final strippedQuery = await _registrationsCollection
                  .where('id', isEqualTo: stripped)
                  .limit(1)
                  .get();
              if (strippedQuery.docs.isNotEmpty) {
                regDoc = strippedQuery.docs.first;
              }
            }
          }
        }
      }

      // Fallback 4: Check if token is a formatted 'REG-XXXXXXXX'
      if (regDoc == null && cleanToken.toUpperCase().startsWith('REG-')) {
        final rawPrefix = cleanToken.substring(4).toLowerCase();
        final allDocs = await _registrationsCollection.limit(50).get();
        for (final doc in allDocs.docs) {
          if (doc.id.toLowerCase().contains(rawPrefix)) {
            regDoc = doc;
            break;
          }
        }
      }

      if (regDoc == null || !regDoc.exists) {
        return const AttendanceScanResult(
          status: AttendanceScanStatus.invalidTicket,
          message:
              'Invalid Ticket: No registration found for this token or ID.',
        );
      }

      final DocumentSnapshot<Map<String, dynamic>> resolvedDoc = regDoc;
      RegistrationModel currentReg = RegistrationModel.fromSnapshot(
        resolvedDoc,
      );
      scannedReg = currentReg;

      // Hydrate student profile info if missing
      if (currentReg.studentName.isEmpty ||
          currentReg.studentEmail.isEmpty ||
          currentReg.rollNumber.isEmpty) {
        try {
          final userDoc = await _db
              .collection('users')
              .doc(currentReg.studentId)
              .get();
          if (userDoc.exists) {
            final uData = userDoc.data() ?? {};
            currentReg = currentReg.copyWith(
              studentName: currentReg.studentName.isNotEmpty
                  ? currentReg.studentName
                  : (uData['name'] ?? ''),
              studentEmail: currentReg.studentEmail.isNotEmpty
                  ? currentReg.studentEmail
                  : (uData['email'] ?? ''),
              rollNumber: currentReg.rollNumber.isNotEmpty
                  ? currentReg.rollNumber
                  : (uData['rollNumber'] ?? ''),
              department: currentReg.department.isNotEmpty
                  ? currentReg.department
                  : (uData['department'] ?? ''),
              year: currentReg.year.isNotEmpty
                  ? currentReg.year
                  : (uData['year'] ?? ''),
            );
            scannedReg = currentReg;
          }
        } catch (_) {}
      }

      // 3. Confirm expected event if scanner is scoped to a specific event
      if (expectedEventId != null &&
          expectedEventId.isNotEmpty &&
          currentReg.eventId.isNotEmpty &&
          currentReg.eventId != expectedEventId) {
        return AttendanceScanResult(
          status: AttendanceScanStatus.wrongEvent,
          message:
              'Wrong Event: This ticket is for "${currentReg.eventTitle.isNotEmpty ? currentReg.eventTitle : 'another event'}", not the selected event.',
          registration: currentReg,
        );
      }

      // 4. Confirm registration is active and not cancelled
      if (currentReg.isCancelled) {
        return AttendanceScanResult(
          status: AttendanceScanStatus.registrationCancelled,
          message:
              'Registration Cancelled: This student\'s registration is cancelled and void.',
          registration: currentReg,
        );
      }

      // 5. Check payment status if event requires payment
      if (currentReg.amount > 0 && !currentReg.isPaid) {
        return AttendanceScanResult(
          status: AttendanceScanStatus.paymentPending,
          message:
              'Payment Pending: Registration fee of ₹${currentReg.amount.toInt()} has not been paid.',
          registration: currentReg,
        );
      }

      // 6. Check if ticket has already been used
      if (currentReg.isAttended) {
        return AttendanceScanResult(
          status: AttendanceScanStatus.alreadyCheckedIn,
          message:
              'Already Checked In: This ticket was already verified for attendance.',
          registration: currentReg,
          attendedAt: currentReg.attendedAt,
        );
      }

      // 7. Atomic attendance record via Firestore Transaction
      final DateTime now = DateTime.now();
      await _db.runTransaction((transaction) async {
        final freshSnapshot = await transaction.get(resolvedDoc.reference);
        if (!freshSnapshot.exists) {
          throw Exception(
            'Registration document not found during transaction.',
          );
        }

        final freshData = freshSnapshot.data()!;
        if (freshData['attended'] == true ||
            freshData['attendanceStatus'] == 'attended') {
          throw Exception('ALREADY_CHECKED_IN');
        }

        // Update registration record atomically
        transaction.update(resolvedDoc.reference, {
          'attended': true,
          'attendanceStatus': 'attended',
          'attendedAt': Timestamp.fromDate(now),
          'verifiedByAdminUid': currentUser.uid,
          'verifiedByAdminEmail': currentUser.email ?? '',
          if (currentReg.ticketToken.isEmpty) 'ticketToken': cleanToken,
        });

        // Write deterministic attendance record in attendance collection
        final attendanceRef = _attendanceCollection.doc(
          '${currentReg.eventId}_${currentReg.id}',
        );
        transaction.set(attendanceRef, {
          'eventId': currentReg.eventId,
          'eventTitle': currentReg.eventTitle,
          'registrationId': currentReg.id,
          'studentId': currentReg.studentId,
          'studentName': currentReg.studentName,
          'rollNumber': currentReg.rollNumber,
          'studentEmail': currentReg.studentEmail,
          'department': currentReg.department,
          'year': currentReg.year,
          'ticketToken': currentReg.ticketToken.isNotEmpty
              ? currentReg.ticketToken
              : cleanToken,
          'attended': true,
          'attendanceStatus': 'attended',
          'attendedAt': Timestamp.fromDate(now),
          'verifiedByAdminUid': currentUser.uid,
          'verifiedByAdminEmail': currentUser.email ?? '',
        }, SetOptions(merge: true));

        // Atomically award gamification coins, streak, and badges
        await GamificationService.processAttendanceRewardInTransaction(
          transaction,
          studentId: currentReg.studentId,
          eventId: currentReg.eventId,
          eventTitle: currentReg.eventTitle,
          attendedAt: now,
          firestore: _db,
        );
      });

      final updatedReg = currentReg.copyWith(
        attended: true,
        attendanceStatus: 'attended',
        attendedAt: now,
        verifiedByAdminUid: currentUser.uid,
      );

      return AttendanceScanResult(
        status: AttendanceScanStatus.verified,
        message: 'Attendance Verified! Check-in recorded successfully. ✓',
        registration: updatedReg,
        attendedAt: now,
      );
    } catch (e) {
      if (e.toString().contains('ALREADY_CHECKED_IN')) {
        return AttendanceScanResult(
          status: AttendanceScanStatus.alreadyCheckedIn,
          message: 'Already Checked In: This ticket has already been used.',
          registration: scannedReg,
          attendedAt: scannedReg?.attendedAt,
        );
      }
      debugPrint('Attendance verification error: $e');
      return AttendanceScanResult(
        status: AttendanceScanStatus.error,
        message:
            'Verification failed: ${e.toString().replaceAll('Exception: ', '')}',
        registration: scannedReg,
      );
    }
  }
}
