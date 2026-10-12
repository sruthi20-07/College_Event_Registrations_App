import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/poll_model.dart';
import 'gamification_service.dart';

/// Result of submitting or editing a vote
class PollVoteResult {
  final bool success;
  final bool isEdit;
  final String message;
  final bool isFirstStreakToday;
  final int dailyStreak;
  final String streakSymbol;

  const PollVoteResult({
    required this.success,
    required this.isEdit,
    required this.message,
    this.isFirstStreakToday = false,
    this.dailyStreak = 0,
    this.streakSymbol = '🔥',
  });
}

/// Service managing Daily Campus Polls, safe voting, vote editing, and analytics
class PollService {
  static final PollService _instance = PollService._internal();
  factory PollService() => _instance;
  PollService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GamificationService _gamificationService = GamificationService();

  CollectionReference<Map<String, dynamic>> get _pollsCollection =>
      _db.collection('polls');

  CollectionReference<Map<String, dynamic>> get _votesCollection =>
      _db.collection('poll_votes');

  // ==========================================
  // 1. STUDENT POLL STREAMS & DATA
  // ==========================================

  /// Streams the currently active daily poll for students.
  /// If no polls exist, seeds a sample poll so the feature is usable immediately.
  Stream<CampusPollModel?> streamActivePoll() {
    return _pollsCollection
        .where('status', isEqualTo: PollStatuses.active)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) {
            // Check if any polls exist at all
            final anyPolls = await _pollsCollection.limit(1).get();
            if (anyPolls.docs.isEmpty) {
              await seedDefaultDailyPoll();
              final seeded = await _pollsCollection
                  .where('status', isEqualTo: PollStatuses.active)
                  .limit(1)
                  .get();
              if (seeded.docs.isNotEmpty) {
                return CampusPollModel.fromSnapshot(seeded.docs.first);
              }
            }
            return null;
          }

          // Return the latest active poll that has not expired
          final now = DateTime.now();
          final activePolls = snapshot.docs
              .map((doc) => CampusPollModel.fromSnapshot(doc))
              .where((p) {
                if (p.startDate != null && now.isBefore(p.startDate!)) {
                  return false;
                }
                if (p.endDate != null && now.isAfter(p.endDate!)) return false;
                return true;
              })
              .toList();

          if (activePolls.isEmpty) return null;
          activePolls.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return activePolls.first;
        });
  }

  /// Streams the authenticated student's vote for a given poll.
  /// Uses deterministic doc ID: `${pollId}_${studentId}`
  Stream<PollVoteModel?> streamStudentVote(String pollId, String studentId) {
    if (pollId.isEmpty || studentId.isEmpty) return Stream.value(null);
    final voteDocId = '${pollId}_$studentId';
    return _votesCollection.doc(voteDocId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PollVoteModel.fromSnapshot(doc);
    });
  }

  /// Fetches a poll by its document ID
  Future<CampusPollModel?> getPoll(String pollId) async {
    if (pollId.isEmpty) return null;
    try {
      final doc = await _pollsCollection.doc(pollId).get();
      if (!doc.exists) return null;
      return CampusPollModel.fromSnapshot(doc);
    } catch (e) {
      debugPrint('Error getting poll $pollId: $e');
      return null;
    }
  }

  // ==========================================
  // 2. SECURE VOTE SUBMISSION & EDITING
  // ==========================================

  /// Atomically submits a new vote or updates an existing vote.
  /// Guarantees exact count aggregation, prevents duplicate voter counts on edit,
  /// and updates daily engagement streak only on first valid vote of the day.
  Future<PollVoteResult> submitOrUpdateVote({
    required String pollId,
    required String studentId,
    required String studentName,
    required String optionId,
  }) async {
    if (pollId.isEmpty || studentId.isEmpty || optionId.isEmpty) {
      return const PollVoteResult(
        success: false,
        isEdit: false,
        message: 'Invalid vote parameters.',
      );
    }

    try {
      final voteDocId = '${pollId}_$studentId';
      final pollRef = _pollsCollection.doc(pollId);
      final voteRef = _votesCollection.doc(voteDocId);
      final now = DateTime.now();

      final result = await _db.runTransaction((transaction) async {
        // 1. Read fresh poll state
        final pollSnap = await transaction.get(pollRef);
        if (!pollSnap.exists) {
          throw Exception('This poll no longer exists.');
        }

        final poll = CampusPollModel.fromSnapshot(pollSnap);

        // Check if poll is active
        if (!poll.isActive) {
          throw Exception('Voting for this poll has closed.');
        }

        // Validate optionId exists in poll
        final targetOption = poll.options.firstWhere(
          (o) => o.id == optionId,
          orElse: () => throw Exception('Selected option is not valid.'),
        );

        // 2. Read existing vote doc (deterministic ID)
        final voteSnap = await transaction.get(voteRef);
        final bool isExistingVote = voteSnap.exists;

        if (isExistingVote) {
          // --- VOTE EDITING PATH ---
          if (!poll.allowVoteEditing) {
            throw Exception('Vote editing is not permitted for this poll.');
          }

          final existingVote = PollVoteModel.fromSnapshot(voteSnap);
          final String oldOptionId = existingVote.selectedOptionId;

          // If student selected the same option, no-op
          if (oldOptionId == optionId) {
            return (isEdit: true, newVote: existingVote, wasNoOp: true);
          }

          // Adjust option counts: decrement old, increment new.
          // Note: totalVotes DOES NOT CHANGE on edit!
          final updatedOptions = poll.options.map((opt) {
            if (opt.id == oldOptionId) {
              return opt.copyWith(
                voteCount: (opt.voteCount - 1).clamp(0, 999999),
              );
            } else if (opt.id == optionId) {
              return opt.copyWith(voteCount: opt.voteCount + 1);
            }
            return opt;
          }).toList();

          // Update poll document
          transaction.update(pollRef, {
            'options': updatedOptions.map((o) => o.toMap()).toList(),
            'updatedAt': Timestamp.fromDate(now),
          });

          // Update vote document
          final updatedVote = existingVote.copyWith(
            selectedOptionId: optionId,
            selectedOptionText: targetOption.text,
            editedCount: existingVote.editedCount + 1,
            updatedAt: now,
          );

          transaction.set(
            voteRef,
            updatedVote.toMap(),
            SetOptions(merge: true),
          );

          return (isEdit: true, newVote: updatedVote, wasNoOp: false);
        } else {
          // --- NEW VOTE PATH ---
          // Increment chosen option and increment total unique voters
          final updatedOptions = poll.options.map((opt) {
            if (opt.id == optionId) {
              return opt.copyWith(voteCount: opt.voteCount + 1);
            }
            return opt;
          }).toList();

          transaction.update(pollRef, {
            'options': updatedOptions.map((o) => o.toMap()).toList(),
            'totalVotes': poll.totalVotes + 1,
            'updatedAt': Timestamp.fromDate(now),
          });

          final newVote = PollVoteModel(
            id: voteDocId,
            pollId: pollId,
            studentId: studentId,
            studentName: studentName.isNotEmpty ? studentName : 'Student',
            selectedOptionId: optionId,
            selectedOptionText: targetOption.text,
            editedCount: 0,
            createdAt: now,
            updatedAt: now,
          );

          transaction.set(voteRef, newVote.toMap());

          return (isEdit: false, newVote: newVote, wasNoOp: false);
        }
      });

      // 3. Handle streak integration
      if (!result.isEdit) {
        // First-time vote: record daily engagement streak
        final streakRes = await _gamificationService.recordDailyPollVote(
          studentId,
        );

        return PollVoteResult(
          success: true,
          isEdit: false,
          message: 'Your vote is in! ${streakRes.symbol}',
          isFirstStreakToday: streakRes.isFirstToday,
          dailyStreak: streakRes.dailyStreak,
          streakSymbol: streakRes.symbol,
        );
      } else {
        // Vote edit: does NOT increment streak or awards
        return PollVoteResult(
          success: true,
          isEdit: true,
          message: result.wasNoOp
              ? 'Vote confirmed.'
              : 'Your vote has been updated successfully.',
          isFirstStreakToday: false,
          dailyStreak: 0,
          streakSymbol: '🔥',
        );
      }
    } catch (e) {
      debugPrint('Error submitting or editing vote: $e');
      return PollVoteResult(
        success: false,
        isEdit: false,
        message: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ==========================================
  // 3. ADMIN POLL MANAGEMENT & ANALYTICS
  // ==========================================

  /// Streams all polls for administrator overview
  Stream<List<CampusPollModel>> streamAllPollsAdmin() {
    return _pollsCollection.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => CampusPollModel.fromSnapshot(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Creates a new poll
  Future<String> createPoll(CampusPollModel poll) async {
    try {
      final docRef = poll.id.isNotEmpty
          ? _pollsCollection.doc(poll.id)
          : _pollsCollection.doc();
      final toSave = poll.copyWith(id: docRef.id);
      await docRef.set(toSave.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating poll: $e');
      rethrow;
    }
  }

  /// Updates an existing poll safely
  Future<void> updatePoll(CampusPollModel poll) async {
    try {
      await _pollsCollection
          .doc(poll.id)
          .set(
            poll.copyWith(updatedAt: DateTime.now()).toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('Error updating poll: $e');
      rethrow;
    }
  }

  /// Sets poll status to active
  Future<void> publishPoll(String pollId) async {
    try {
      await _pollsCollection.doc(pollId).update({
        'status': PollStatuses.active,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Error publishing poll: $e');
      rethrow;
    }
  }

  /// Closes a poll immediately
  Future<void> closePoll(String pollId) async {
    try {
      await _pollsCollection.doc(pollId).update({
        'status': PollStatuses.closed,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Error closing poll: $e');
      rethrow;
    }
  }

  /// Archives an old poll
  Future<void> archivePoll(String pollId) async {
    try {
      await _pollsCollection.doc(pollId).update({
        'status': PollStatuses.archived,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Error archiving poll: $e');
      rethrow;
    }
  }

  /// Deletes a poll if it has no recorded votes
  Future<bool> deletePoll(String pollId) async {
    try {
      final pollDoc = await _pollsCollection.doc(pollId).get();
      if (!pollDoc.exists) return false;
      final poll = CampusPollModel.fromSnapshot(pollDoc);
      if (poll.totalVotes > 0) {
        throw Exception(
          'Cannot delete a poll that already has student votes. Close or archive it instead.',
        );
      }
      await _pollsCollection.doc(pollId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting poll: $e');
      rethrow;
    }
  }

  // ==========================================
  // 4. SEEDING DEFAULT ACTIVE POLL
  // ==========================================

  /// Seeds an initial default active poll if the collection is empty
  Future<void> seedDefaultDailyPoll() async {
    try {
      final now = DateTime.now();
      final defaultPoll = CampusPollModel(
        id: 'daily_poll_workshop_preferences',
        question:
            'Which technical workshop would you like to attend next weekend?',
        description:
            'Help our campus tech committees schedule the most in-demand hands-on sessions!',
        category: PollCategories.workshops,
        options: const [
          PollOptionModel(
            id: 'opt_flutter',
            text: 'Flutter & Cross-Platform Mobile Apps',
            voteCount: 0,
          ),
          PollOptionModel(
            id: 'opt_ai',
            text: 'Generative AI & Agentic Workflow Engineering',
            voteCount: 0,
          ),
          PollOptionModel(
            id: 'opt_cyber',
            text: 'Ethical Hacking & Cyber Defence Bootcamp',
            voteCount: 0,
          ),
          PollOptionModel(
            id: 'opt_cloud',
            text: 'Cloud Native Architecture & DevOps with Docker',
            voteCount: 0,
          ),
        ],
        totalVotes: 0,
        status: PollStatuses.active,
        allowVoteEditing: true,
        showResultsBeforeVoting: false,
        startDate: now.subtract(const Duration(hours: 1)),
        endDate: now.add(const Duration(days: 7)),
        createdBy: 'campus_admin',
        createdAt: now,
        updatedAt: now,
      );

      await _pollsCollection
          .doc(defaultPoll.id)
          .set(defaultPoll.toMap(), SetOptions(merge: true));
      debugPrint('Seeded default active daily campus poll.');
    } catch (e) {
      debugPrint('Error seeding default poll: $e');
    }
  }
}
