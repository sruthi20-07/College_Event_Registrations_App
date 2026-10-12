import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_formatter.dart';

/// Supported poll categories
class PollCategories {
  static const String workshops = 'Workshops';
  static const String hackathons = 'Hackathons';
  static const String clubs = 'Clubs & Fests';
  static const String festivals = 'College Festivals';
  static const String career = 'Career & Placements';
  static const String placements = 'Placements & Career';
  static const String facilities = 'Campus Facilities';
  static const String events = 'Competitions & Events';
  static const String general = 'General';

  static const List<String> all = [
    workshops,
    hackathons,
    clubs,
    festivals,
    career,
    placements,
    facilities,
    events,
    general,
  ];
}

/// Statuses for campus polls
class PollStatuses {
  static const String draft = 'draft';
  static const String scheduled = 'scheduled';
  static const String active = 'active';
  static const String closed = 'closed';
  static const String archived = 'archived';

  static const List<String> all = [draft, scheduled, active, closed, archived];
}

/// A selectable option in a poll
class PollOptionModel {
  final String id;
  final String text;
  final int voteCount;

  const PollOptionModel({
    required this.id,
    required this.text,
    this.voteCount = 0,
  });

  factory PollOptionModel.fromMap(Map<String, dynamic> map) {
    return PollOptionModel(
      id: map['id'] as String? ?? '',
      text: map['text'] as String? ?? '',
      voteCount: (map['voteCount'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'text': text, 'voteCount': voteCount};
  }

  PollOptionModel copyWith({String? id, String? text, int? voteCount}) {
    return PollOptionModel(
      id: id ?? this.id,
      text: text ?? this.text,
      voteCount: voteCount ?? this.voteCount,
    );
  }
}

/// A Daily Campus Poll
class CampusPollModel {
  final String id;
  final String question;
  final String description;
  final String category;
  final List<PollOptionModel> options;
  final int totalVotes; // Unique student votes
  final String status; // draft, scheduled, active, closed, archived
  final bool allowVoteEditing; // whether student can update vote while active
  final bool
  showResultsBeforeVoting; // whether results are visible before submitting
  final DateTime? startDate;
  final DateTime? endDate;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  CampusPollModel({
    required this.id,
    required this.question,
    this.description = '',
    this.category = PollCategories.workshops,
    required this.options,
    this.totalVotes = 0,
    this.status = PollStatuses.active,
    this.allowVoteEditing = true,
    bool? showResultsBeforeVoting,
    bool? resultsVisibleBeforeVote,
    this.startDate,
    this.endDate,
    this.createdBy = 'admin',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : showResultsBeforeVoting =
           showResultsBeforeVoting ?? resultsVisibleBeforeVote ?? false,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  bool get resultsVisibleBeforeVote => showResultsBeforeVoting;

  bool get isActive {
    if (status != PollStatuses.active) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  bool get isClosed {
    if (status == PollStatuses.closed || status == PollStatuses.archived) {
      return true;
    }
    if (endDate != null && DateTime.now().isAfter(endDate!)) return true;
    return false;
  }

  bool get isDraft => status == PollStatuses.draft;
  bool get isScheduled => status == PollStatuses.scheduled;
  bool get isArchived => status == PollStatuses.archived;

  /// Returns safe percentage [0.0 - 100.0] for a given option ID
  double percentageForOption(String optionId) {
    if (totalVotes <= 0) return 0.0;
    final opt = options.firstWhere(
      (o) => o.id == optionId,
      orElse: () => const PollOptionModel(id: '', text: '', voteCount: 0),
    );
    return ((opt.voteCount / totalVotes) * 100.0).clamp(0.0, 100.0);
  }

  /// Returns the most popular option or null if no votes yet
  PollOptionModel? get mostPopularOption {
    if (totalVotes <= 0 || options.isEmpty) return null;
    PollOptionModel top = options.first;
    for (final opt in options) {
      if (opt.voteCount > top.voteCount) {
        top = opt;
      }
    }
    return top.voteCount > 0 ? top : null;
  }

  factory CampusPollModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawOptions = map['options'];
    final List<PollOptionModel> parsedOptions = [];
    if (rawOptions is List) {
      for (final opt in rawOptions) {
        if (opt is Map<String, dynamic>) {
          parsedOptions.add(PollOptionModel.fromMap(opt));
        } else if (opt is Map) {
          parsedOptions.add(
            PollOptionModel.fromMap(Map<String, dynamic>.from(opt)),
          );
        }
      }
    }

    return CampusPollModel(
      id: docId,
      question: map['question'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? PollCategories.workshops,
      options: parsedOptions,
      totalVotes: (map['totalVotes'] ?? 0) as int,
      status: map['status'] as String? ?? PollStatuses.active,
      allowVoteEditing: map['allowVoteEditing'] as bool? ?? true,
      showResultsBeforeVoting: map['showResultsBeforeVoting'] as bool? ?? false,
      startDate: map['startDate'] != null
          ? DateFormatter.parseDateTime(map['startDate'])
          : null,
      endDate: map['endDate'] != null
          ? DateFormatter.parseDateTime(map['endDate'])
          : null,
      createdBy: map['createdBy'] as String? ?? 'admin',
      createdAt: DateFormatter.parseDateTime(map['createdAt']),
      updatedAt: DateFormatter.parseDateTime(map['updatedAt']),
    );
  }

  factory CampusPollModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return CampusPollModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'description': description,
      'category': category,
      'options': options.map((o) => o.toMap()).toList(),
      'totalVotes': totalVotes,
      'status': status,
      'allowVoteEditing': allowVoteEditing,
      'showResultsBeforeVoting': showResultsBeforeVoting,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CampusPollModel copyWith({
    String? id,
    String? question,
    String? description,
    String? category,
    List<PollOptionModel>? options,
    int? totalVotes,
    String? status,
    bool? allowVoteEditing,
    bool? showResultsBeforeVoting,
    bool? resultsVisibleBeforeVote,
    DateTime? startDate,
    DateTime? endDate,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CampusPollModel(
      id: id ?? this.id,
      question: question ?? this.question,
      description: description ?? this.description,
      category: category ?? this.category,
      options: options ?? this.options,
      totalVotes: totalVotes ?? this.totalVotes,
      status: status ?? this.status,
      allowVoteEditing: allowVoteEditing ?? this.allowVoteEditing,
      showResultsBeforeVoting:
          showResultsBeforeVoting ??
          resultsVisibleBeforeVote ??
          this.showResultsBeforeVoting,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// An individual student's vote on a poll
/// Deterministic doc ID: `${pollId}_${studentId}`
class PollVoteModel {
  final String id;
  final String pollId;
  final String studentId;
  final String studentName;
  final String selectedOptionId;
  final String selectedOptionText;
  final int editedCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PollVoteModel({
    required this.id,
    required this.pollId,
    required this.studentId,
    required this.studentName,
    required this.selectedOptionId,
    required this.selectedOptionText,
    this.editedCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PollVoteModel.fromMap(Map<String, dynamic> map, String docId) {
    return PollVoteModel(
      id: docId,
      pollId: map['pollId'] as String? ?? '',
      studentId: map['studentId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      selectedOptionId: map['selectedOptionId'] as String? ?? '',
      selectedOptionText: map['selectedOptionText'] as String? ?? '',
      editedCount: (map['editedCount'] ?? 0) as int,
      createdAt: DateFormatter.parseDateTime(map['createdAt']),
      updatedAt: DateFormatter.parseDateTime(map['updatedAt']),
    );
  }

  factory PollVoteModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PollVoteModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pollId': pollId,
      'studentId': studentId,
      'studentName': studentName,
      'selectedOptionId': selectedOptionId,
      'selectedOptionText': selectedOptionText,
      'editedCount': editedCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PollVoteModel copyWith({
    String? id,
    String? pollId,
    String? studentId,
    String? studentName,
    String? selectedOptionId,
    String? selectedOptionText,
    int? editedCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PollVoteModel(
      id: id ?? this.id,
      pollId: pollId ?? this.pollId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
      selectedOptionText: selectedOptionText ?? this.selectedOptionText,
      editedCount: editedCount ?? this.editedCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
