import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/attendance_scan_result.dart';
import '../models/attendance_session_model.dart';
import '../models/gamification_model.dart';
import '../models/registration_model.dart';
import '../utils/constants.dart';
import 'gamification_service.dart';
import 'whatsapp_service.dart';

class RegistrationService {
  WhatsAppService get _whatsAppService => WhatsAppService();
  GamificationService get _gamificationService => GamificationService();
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _registrationsCollection =>
      _db.collection('registrations');

  CollectionReference<Map<String, dynamic>> get _eventsCollection =>
      _db.collection('events');

  CollectionReference<Map<String, dynamic>> get _savedCollection =>
      _db.collection('saved_events');

  CollectionReference<Map<String, dynamic>> get _attendanceCollection =>
      _db.collection('attendance');

  CollectionReference<Map<String, dynamic>> get _attendanceSessionsCollection =>
      _db.collection('attendance_sessions');

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
        // --- READ PHASE: ALL READS FIRST ---
        final regRef = _registrationsCollection.doc(deterministicDocId);
        final regDoc = await transaction.get(regRef);

        final eventRef = _eventsCollection.doc(registration.eventId);
        final eventDoc = await transaction.get(eventRef);

        final userRef = _db.collection('users').doc(currentUid);
        final userDoc = await transaction.get(userRef);

        // --- VALIDATION PHASE ---
        if (regDoc.exists) {
          final existingData = regDoc.data()!;
          final status = existingData['registrationStatus'] as String? ?? '';
          if (status == 'confirmed' ||
              status == RegistrationStatuses.registered) {
            throw Exception('You are already registered for this event.');
          }
        }

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

          // Check eligibility criteria
          final List<String> allowedYears =
              (data['allowedYears'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          final List<String> allowedDepts =
              (data['allowedDepartments'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          final userData = userDoc.exists ? (userDoc.data() ?? {}) : {};
          final userRole = (userData['role'] as String? ?? '').toLowerCase();
          final bool isStaff =
              userRole == 'admin' ||
              userRole == 'faculty' ||
              userRole == 'coordinator';

          if (!isStaff) {
            final String studentYear =
                (userData['year'] as String? ?? registration.year).trim();
            final String studentDept =
                (userData['department'] as String? ?? registration.department)
                    .trim();

            final bool checkYears =
                allowedYears.isNotEmpty &&
                !allowedYears.contains('All') &&
                !allowedYears.contains(AcademicYears.all);

            if (checkYears) {
              if (studentYear.isEmpty) {
                throw Exception(
                  'Profile Incomplete: Academic year is required to verify event eligibility. Please update your profile.',
                );
              }
              if (!AcademicYears.matches(allowedYears, studentYear)) {
                throw Exception(
                  'Ineligible: This event is open only to ${allowedYears.join(', ')}. Your profile indicates $studentYear.',
                );
              }
            }

            final bool checkDepts =
                allowedDepts.isNotEmpty &&
                !allowedDepts.contains('All') &&
                !allowedDepts.contains(AcademicDepartments.all);

            if (checkDepts) {
              if (studentDept.isEmpty) {
                throw Exception(
                  'Profile Incomplete: Department/Branch is required to verify event eligibility. Please update your profile.',
                );
              }
              if (!AcademicDepartments.matches(allowedDepts, studentDept)) {
                throw Exception(
                  'Ineligible: This event is open only to ${allowedDepts.join(', ')}. Your profile indicates $studentDept.',
                );
              }
            }
          }

          final int newRegisteredCount = registeredCount + 1;
          final int newAvailableSeats = (capacity - newRegisteredCount).clamp(
            0,
            capacity,
          );

          // --- WRITE PHASE: ALL WRITES AFTER ALL READS ---
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

      // Trigger official WhatsApp notification asynchronously if student consented
      if (registration.whatsappConsent) {
        try {
          final confirmedRegistration = registration.copyWith(
            id: deterministicDocId,
            studentId: currentUid,
            ticketToken: secureToken,
            registrationStatus: 'confirmed',
          );
          _whatsAppService
              .queueAutomatedNotification(registration: confirmedRegistration)
              .catchError((err) {
                debugPrint('Async WhatsApp notification queue warning: $err');
                return WhatsAppApiResult(
                  success: false,
                  status: 'failed',
                  message: err.toString(),
                );
              });
        } catch (e) {
          debugPrint('Safe catch on automated WhatsApp trigger: $e');
        }
      }

      return deterministicDocId;
    } catch (e) {
      debugPrint('Registration transaction error: $e');
      rethrow;
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

  /// Updates WhatsApp notification fields for a registration
  Future<void> updateWhatsAppStatus({
    required String registrationId,
    required String whatsappNumber,
    required bool whatsappConsent,
    required String whatsappStatus,
    String whatsappDeliveryMode = 'manual',
    String? whatsappMessageId,
    String? whatsappError,
  }) async {
    try {
      final docRef = _registrationsCollection.doc(registrationId);
      final Map<String, dynamic> updateData = {
        'whatsappNumber': whatsappNumber,
        'whatsappConsent': whatsappConsent,
        'whatsappConsentAt': whatsappConsent ? Timestamp.now() : null,
        'whatsappStatus': whatsappStatus,
        'whatsappDeliveryMode': whatsappDeliveryMode,
        'whatsappSentAt': Timestamp.now(),
      };
      if (whatsappMessageId != null) {
        updateData['whatsappMessageId'] = whatsappMessageId;
      }
      if (whatsappError != null) {
        updateData['whatsappError'] = whatsappError;
      }

      await docRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating WhatsApp registration status: $e');
    }
  }

  /// Updates attendance status for a participant in Firestore
  Future<void> updateAttendance(String registrationId, bool attended) async {
    try {
      final now = DateTime.now();
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final regRef = _registrationsCollection.doc(registrationId);

      if (attended) {
        String verifiedStudentId = '';
        String verifiedEventId = '';

        await _db.runTransaction((transaction) async {
          // --- READ PHASE: ALL READS FIRST ---
          final regDoc = await transaction.get(regRef);
          if (!regDoc.exists) {
            throw Exception('Registration record not found.');
          }
          final reg = RegistrationModel.fromSnapshot(regDoc);

          if (reg.isAttended) {
            return; // Already marked attended
          }

          verifiedStudentId = reg.studentId;
          verifiedEventId = reg.eventId;

          final String idempotencyRewardId = '${reg.studentId}_${reg.eventId}';
          final rewardRef = _db
              .collection('reward_history')
              .doc(idempotencyRewardId);
          final rewardDoc = await transaction.get(rewardRef);

          final gamificationRef = _db
              .collection('gamification')
              .doc(reg.studentId);
          final gamificationDoc = await transaction.get(gamificationRef);

          // --- VALIDATE & COMPUTE PHASE ---
          final bool shouldAwardReward =
              !rewardDoc.exists && reg.studentId.isNotEmpty;
          final currentGamification = gamificationDoc.exists
              ? GamificationModel.fromSnapshot(gamificationDoc)
              : GamificationModel(studentId: reg.studentId);

          final rewardCalculation = shouldAwardReward
              ? GamificationService.computeReward(
                  currentGamification: currentGamification,
                  studentId: reg.studentId,
                  eventId: reg.eventId,
                  eventTitle: reg.eventTitle,
                  attendedAt: now,
                )
              : null;

          final attendanceRef = _attendanceCollection.doc(
            '${reg.eventId}_${reg.id}',
          );

          // --- WRITE PHASE: ALL WRITES AFTER ALL READS ---
          transaction.update(regRef, {
            'attended': true,
            'attendanceStatus': 'attended',
            'attendedAt': Timestamp.fromDate(now),
            'verifiedByAdminUid': adminUid,
          });

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

          if (rewardCalculation != null) {
            transaction.set(
              gamificationRef,
              rewardCalculation.updatedGamification.toMap(),
              SetOptions(merge: true),
            );
            transaction.set(rewardRef, rewardCalculation.rewardRecord.toMap());
          }
        });

        if (verifiedStudentId.isNotEmpty) {
          _gamificationService
              .processReferralQualificationOnFirstAttendance(
                referredStudentId: verifiedStudentId,
                eventId: verifiedEventId,
              )
              .catchError((e) {
                debugPrint('Notice: referral qualification check: $e');
              });
        }
      } else {
        await _db.runTransaction((transaction) async {
          // --- READ PHASE ---
          final regDoc = await transaction.get(regRef);
          if (!regDoc.exists) return;
          final reg = RegistrationModel.fromSnapshot(regDoc);
          final attendanceRef = _attendanceCollection.doc(
            '${reg.eventId}_${reg.id}',
          );
          final attDoc = await transaction.get(attendanceRef);

          // --- WRITE PHASE ---
          transaction.update(regRef, {
            'attended': false,
            'attendanceStatus': 'not_attended',
            'attendedAt': null,
            'verifiedByAdminUid': '',
          });

          if (attDoc.exists) {
            transaction.delete(attendanceRef);
          }
        });
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
        // --- READ PHASE: ALL READS FIRST ---
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

        final String idempotencyRewardId =
            '${currentReg.studentId}_${currentReg.eventId}';
        final rewardRef = _db
            .collection('reward_history')
            .doc(idempotencyRewardId);
        final rewardDoc = await transaction.get(rewardRef);

        final gamificationRef = _db
            .collection('gamification')
            .doc(currentReg.studentId);
        final gamificationDoc = await transaction.get(gamificationRef);

        // --- COMPUTE & VALIDATE PHASE ---
        final bool shouldAwardReward =
            !rewardDoc.exists && currentReg.studentId.isNotEmpty;
        final currentGamification = gamificationDoc.exists
            ? GamificationModel.fromSnapshot(gamificationDoc)
            : GamificationModel(studentId: currentReg.studentId);

        final rewardCalculation = shouldAwardReward
            ? GamificationService.computeReward(
                currentGamification: currentGamification,
                studentId: currentReg.studentId,
                eventId: currentReg.eventId,
                eventTitle: currentReg.eventTitle,
                attendedAt: now,
              )
            : null;

        final attendanceRef = _attendanceCollection.doc(
          '${currentReg.eventId}_${currentReg.id}',
        );

        // --- WRITE PHASE: ONLY WRITES AFTER ALL READS ---
        transaction.update(resolvedDoc.reference, {
          'attended': true,
          'attendanceStatus': 'attended',
          'attendedAt': Timestamp.fromDate(now),
          'verifiedByAdminUid': currentUser.uid,
          'verifiedByAdminEmail': currentUser.email ?? '',
          if (currentReg.ticketToken.isEmpty) 'ticketToken': cleanToken,
        });

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

        if (rewardCalculation != null) {
          transaction.set(
            gamificationRef,
            rewardCalculation.updatedGamification.toMap(),
            SetOptions(merge: true),
          );
          transaction.set(rewardRef, rewardCalculation.rewardRecord.toMap());
        }
      });

      if (currentReg.studentId.isNotEmpty) {
        _gamificationService
            .processReferralQualificationOnFirstAttendance(
              referredStudentId: currentReg.studentId,
              eventId: currentReg.eventId,
            )
            .catchError((e) {
              debugPrint('Notice: referral qualification check: $e');
            });
      }

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

  // ==========================================
  // ROTATING EVENT QR ATTENDANCE METHODS
  // ==========================================

  /// Starts a new active live attendance session for an event (Admin Only)
  Future<AttendanceSessionModel> startAttendanceSession({
    required String eventId,
    required String eventTitle,
    int refreshIntervalSeconds = 15,
    int sessionDurationMinutes = 60,
  }) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('Admin authentication required.');
    }

    final String adminUid = currentUser.uid;
    final now = DateTime.now();
    final expiresAt = now.add(Duration(minutes: sessionDurationMinutes));

    final docRef = _attendanceSessionsCollection.doc();
    final initialPayload = AttendanceQrPayload.create(
      eventId: eventId,
      sessionId: docRef.id,
      adminUid: adminUid,
      validDurationSeconds: refreshIntervalSeconds + 5,
    );

    final session = AttendanceSessionModel(
      id: docRef.id,
      eventId: eventId,
      eventTitle: eventTitle,
      createdByAdminUid: adminUid,
      createdAt: now,
      expiresAt: expiresAt,
      isActive: true,
      refreshIntervalSeconds: refreshIntervalSeconds,
      currentNonce: initialPayload.nonce,
      currentHash: initialPayload.hash,
      attendeeCount: 0,
      lastRotatedAt: now,
    );

    await docRef.set(session.toMap());
    return session;
  }

  /// Rotates the QR token for an active attendance session (Admin Only)
  Future<AttendanceQrPayload> rotateSessionToken({
    required String sessionId,
    required String eventId,
    int refreshIntervalSeconds = 15,
  }) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String adminUid = currentUser?.uid ?? '';

    final payload = AttendanceQrPayload.create(
      eventId: eventId,
      sessionId: sessionId,
      adminUid: adminUid,
      validDurationSeconds: refreshIntervalSeconds + 5,
    );

    final docRef = _attendanceSessionsCollection.doc(sessionId);
    await docRef.update({
      'currentNonce': payload.nonce,
      'currentHash': payload.hash,
      'lastRotatedAt': Timestamp.fromDate(DateTime.now()),
    });

    return payload;
  }

  /// Closes and expires an attendance session (Admin Only)
  Future<void> stopAttendanceSession(String sessionId) async {
    try {
      final docRef = _attendanceSessionsCollection.doc(sessionId);
      await docRef.update({
        'isActive': false,
        'closedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Error stopping attendance session: $e');
      rethrow;
    }
  }

  /// Streams an attendance session document in real time
  Stream<AttendanceSessionModel?> streamAttendanceSession(String sessionId) {
    if (sessionId.isEmpty) return Stream.value(null);
    return _attendanceSessionsCollection.doc(sessionId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AttendanceSessionModel.fromSnapshot(doc);
    });
  }

  /// Streams the latest active attendance session for a specific event
  Stream<AttendanceSessionModel?> streamActiveAttendanceSessionForEvent(
    String eventId,
  ) {
    if (eventId.isEmpty) return Stream.value(null);
    return _attendanceSessionsCollection
        .where('eventId', isEqualTo: eventId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((query) {
          if (query.docs.isEmpty) return null;
          return AttendanceSessionModel.fromSnapshot(query.docs.first);
        });
  }

  /// Atomically validates event QR token and marks student attendance (Student Action)
  Future<AttendanceScanResult> recordStudentAttendanceViaQr({
    required String rawPayload,
    String? studentUid,
  }) async {
    // 1. Parse QR payload
    final payload = AttendanceQrPayload.tryParse(rawPayload);
    if (payload == null || payload.eventId.isEmpty) {
      return const AttendanceScanResult(
        status: AttendanceScanStatus.invalidTicket,
        message: 'Invalid or unreadable Event Attendance QR code format.',
      );
    }

    // 2. Identify currently authenticated student from Firebase Auth
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const AttendanceScanResult(
        status: AttendanceScanStatus.error,
        message: 'Authentication required. Please sign in to mark attendance.',
      );
    }

    final String verifiedStudentId = currentUser.uid;
    // Disallow spoofing if a studentUid was explicitly supplied that differs from Auth
    if (studentUid != null &&
        studentUid.isNotEmpty &&
        studentUid != verifiedStudentId) {
      return const AttendanceScanResult(
        status: AttendanceScanStatus.error,
        message: 'Security validation failed: User identity mismatch.',
      );
    }

    // 3. Client-side expiration check (for rotating timed sessions)
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (payload.expiresAt > 0 && nowMs > payload.expiresAt + 15000) {
      return const AttendanceScanResult(
        status: AttendanceScanStatus.sessionExpired,
        message:
            'This QR code has expired. Please scan the current QR code on the screen.',
      );
    }

    // 4. Resolve registration doc ID
    final deterministicDocId = '${payload.eventId}_$verifiedStudentId';
    DocumentReference<Map<String, dynamic>> regDocRef = _registrationsCollection
        .doc(deterministicDocId);

    // If deterministic doc does not exist, look up existing registration ID for this student and event
    final directCheck = await regDocRef.get();
    if (!directCheck.exists) {
      final lookupQuery = await _registrationsCollection
          .where('eventId', isEqualTo: payload.eventId)
          .where('studentId', isEqualTo: verifiedStudentId)
          .limit(1)
          .get();
      if (lookupQuery.docs.isNotEmpty) {
        regDocRef = lookupQuery.docs.first.reference;
      }
    }

    // 5. Execute Atomic Firestore Transaction
    final DateTime now = DateTime.now();
    int earnedCoins = 0;
    String eventTitle = '';
    RegistrationModel? finalReg;

    try {
      await _db.runTransaction((transaction) async {
        // --- READ PHASE: ALL READS MUST PRECEDE ALL WRITES ---
        DocumentSnapshot<Map<String, dynamic>>? sessionDoc;
        if (payload.sessionId.isNotEmpty) {
          final sessionRef = _attendanceSessionsCollection.doc(
            payload.sessionId,
          );
          sessionDoc = await transaction.get(sessionRef);
        }

        final eventRef = _eventsCollection.doc(payload.eventId);
        final eventDoc = await transaction.get(eventRef);

        final regDoc = await transaction.get(regDocRef);

        final userRef = _db.collection('users').doc(verifiedStudentId);
        final userDoc = await transaction.get(userRef);

        final String idempotencyRewardId =
            '${verifiedStudentId}_${payload.eventId}';
        final rewardRef = _db
            .collection('reward_history')
            .doc(idempotencyRewardId);
        final rewardDoc = await transaction.get(rewardRef);

        final gamificationRef = _db
            .collection('gamification')
            .doc(verifiedStudentId);
        final gamificationDoc = await transaction.get(gamificationRef);

        // --- VALIDATION PHASE ---
        if (payload.sessionId.isNotEmpty) {
          if (sessionDoc == null || !sessionDoc.exists) {
            throw Exception('SESSION_NOT_FOUND');
          }
          final sessionData = sessionDoc.data()!;
          final bool isSessionActive =
              sessionData['isActive'] as bool? ?? false;
          if (!isSessionActive) {
            throw Exception('SESSION_INACTIVE');
          }
          if (sessionData['eventId'] != payload.eventId) {
            throw Exception('WRONG_EVENT');
          }
        }

        if (!eventDoc.exists) {
          throw Exception('EVENT_NOT_FOUND');
        }
        final eventData = eventDoc.data()!;
        final String eventStatus =
            eventData['status'] as String? ?? EventStatuses.upcoming;
        if (eventStatus == EventStatuses.cancelled) {
          throw Exception('EVENT_CANCELLED');
        }

        // Validate event token if provided in payload
        final String expectedQrToken =
            (eventData['qrToken'] ?? eventData['attendanceToken'] ?? '')
                as String;
        if (payload.token.isNotEmpty &&
            expectedQrToken.isNotEmpty &&
            payload.token != expectedQrToken &&
            payload.sessionId.isEmpty) {
          throw Exception('INVALID_EVENT_TOKEN');
        }

        eventTitle = (eventData['title'] ?? 'Event') as String;

        if (!regDoc.exists) {
          throw Exception('NOT_REGISTERED');
        }
        final regData = regDoc.data()!;
        final currentReg = RegistrationModel.fromMap(regData, regDoc.id);

        if (currentReg.isCancelled) {
          throw Exception('REGISTRATION_CANCELLED');
        }

        if (currentReg.amount > 0 && !currentReg.isPaid) {
          throw Exception('PAYMENT_PENDING');
        }

        if (currentReg.isAttended ||
            regData['attended'] == true ||
            regData['attendanceStatus'] == 'attended') {
          throw Exception('ALREADY_CHECKED_IN');
        }

        // Eligibility validation
        final List<String> allowedYears =
            (eventData['allowedYears'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final List<String> allowedDepts =
            (eventData['allowedDepartments'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        final userData = userDoc.exists ? (userDoc.data() ?? {}) : {};
        final studentYear = (userData['year'] ?? currentReg.year).toString();
        final studentDept = (userData['department'] ?? currentReg.department)
            .toString();

        if (allowedYears.isNotEmpty &&
            studentYear.isNotEmpty &&
            !allowedYears.contains(studentYear)) {
          throw Exception('INELIGIBLE_YEAR');
        }
        if (allowedDepts.isNotEmpty &&
            studentDept.isNotEmpty &&
            !allowedDepts.contains(studentDept)) {
          throw Exception('INELIGIBLE_DEPT');
        }

        // --- COMPUTE PHASE ---
        final bool shouldAwardReward =
            !rewardDoc.exists && verifiedStudentId.isNotEmpty;
        final currentGamification = gamificationDoc.exists
            ? GamificationModel.fromSnapshot(gamificationDoc)
            : GamificationModel(studentId: verifiedStudentId);

        final rewardCalculation = shouldAwardReward
            ? GamificationService.computeReward(
                currentGamification: currentGamification,
                studentId: verifiedStudentId,
                eventId: payload.eventId,
                eventTitle: eventTitle,
                attendedAt: now,
              )
            : null;

        earnedCoins = rewardCalculation?.rewardRecord.coinsAwarded ?? 0;

        final attendanceAuditRef = _attendanceCollection.doc(
          '${payload.eventId}_${regDoc.id}',
        );

        // --- WRITE PHASE: ALL WRITES AFTER ALL READS ---
        transaction.update(regDocRef, {
          'attended': true,
          'attendanceStatus': 'attended',
          'attendedAt': Timestamp.fromDate(now),
          'checkInMethod': 'event_qr',
          if (payload.sessionId.isNotEmpty)
            'attendanceSessionId': payload.sessionId,
        });

        transaction.set(attendanceAuditRef, {
          'eventId': payload.eventId,
          'eventTitle': eventTitle,
          'registrationId': regDoc.id,
          'studentId': verifiedStudentId,
          'studentName': currentReg.studentName.isNotEmpty
              ? currentReg.studentName
              : (userData['name'] ?? ''),
          'rollNumber': currentReg.rollNumber.isNotEmpty
              ? currentReg.rollNumber
              : (userData['rollNumber'] ?? ''),
          'studentEmail': currentReg.studentEmail.isNotEmpty
              ? currentReg.studentEmail
              : (userData['email'] ?? ''),
          'department': currentReg.department.isNotEmpty
              ? currentReg.department
              : (userData['department'] ?? ''),
          'year': currentReg.year.isNotEmpty
              ? currentReg.year
              : (userData['year'] ?? ''),
          'ticketToken': currentReg.ticketToken,
          'attended': true,
          'attendanceStatus': 'attended',
          'attendedAt': Timestamp.fromDate(now),
          'checkInMethod': 'event_qr',
          if (payload.sessionId.isNotEmpty)
            'attendanceSessionId': payload.sessionId,
        }, SetOptions(merge: true));

        if (sessionDoc != null && sessionDoc.exists) {
          final int currentAttendeeCount =
              (sessionDoc.data()!['attendeeCount'] as num? ?? 0).toInt();
          transaction.update(sessionDoc.reference, {
            'attendeeCount': currentAttendeeCount + 1,
          });
        }

        if (rewardCalculation != null) {
          transaction.set(
            gamificationRef,
            rewardCalculation.updatedGamification.toMap(),
            SetOptions(merge: true),
          );
          transaction.set(rewardRef, rewardCalculation.rewardRecord.toMap());
        }

        finalReg = currentReg.copyWith(
          attended: true,
          attendanceStatus: 'attended',
          attendedAt: now,
        );
      });

      if (verifiedStudentId.isNotEmpty) {
        _gamificationService
            .processReferralQualificationOnFirstAttendance(
              referredStudentId: verifiedStudentId,
              eventId: payload.eventId,
            )
            .catchError((e) {
              debugPrint('Notice: referral qualification check: $e');
            });
      }

      return AttendanceScanResult(
        status: AttendanceScanStatus.verified,
        message: 'Attendance recorded successfully! You are verified.',
        registration: finalReg,
        attendedAt: now,
        eventTitle: eventTitle,
        coinsEarned: earnedCoins,
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('ALREADY_CHECKED_IN')) {
        return AttendanceScanResult(
          status: AttendanceScanStatus.alreadyCheckedIn,
          message: 'You have already checked in for this event.',
          eventTitle: eventTitle,
        );
      }
      if (msg.contains('NOT_REGISTERED')) {
        return AttendanceScanResult(
          status: AttendanceScanStatus.notRegistered,
          message:
              'You are not registered for this event. Please register first to attend.',
          eventTitle: eventTitle,
        );
      }
      if (msg.contains('EVENT_CANCELLED')) {
        return const AttendanceScanResult(
          status: AttendanceScanStatus.sessionInactive,
          message:
              'This event has been cancelled or unpublished. Attendance is not open.',
        );
      }
      if (msg.contains('INVALID_EVENT_TOKEN') || msg.contains('WRONG_EVENT')) {
        return const AttendanceScanResult(
          status: AttendanceScanStatus.wrongEvent,
          message: 'This attendance QR does not match the expected event.',
        );
      }
      if (msg.contains('SESSION_INACTIVE') ||
          msg.contains('SESSION_NOT_FOUND')) {
        return const AttendanceScanResult(
          status: AttendanceScanStatus.sessionInactive,
          message: 'Attendance is currently closed for this event session.',
        );
      }
      if (msg.contains('REGISTRATION_CANCELLED')) {
        return const AttendanceScanResult(
          status: AttendanceScanStatus.registrationCancelled,
          message: 'Your registration for this event was cancelled.',
        );
      }
      if (msg.contains('PAYMENT_PENDING')) {
        return const AttendanceScanResult(
          status: AttendanceScanStatus.paymentPending,
          message:
              'Registration fee is unpaid. Please complete payment before check-in.',
        );
      }
      if (msg.contains('INELIGIBLE')) {
        return const AttendanceScanResult(
          status: AttendanceScanStatus.ineligible,
          message:
              'You do not meet the department or year eligibility for this event.',
        );
      }

      debugPrint('recordStudentAttendanceViaQr error: $e');
      return AttendanceScanResult(
        status: AttendanceScanStatus.error,
        message:
            'Failed to record attendance: ${msg.replaceAll('Exception: ', '')}',
      );
    }
  }
}
