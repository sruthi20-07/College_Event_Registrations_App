import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_formatter.dart';

/// Categories of college rewards
class RewardCategories {
  static const String freeEvent = 'free_event';
  static const String certificate = 'certificate';
  static const String collegePerk = 'college_perk';
  static const String custom = 'custom';

  static const List<String> all = [freeEvent, certificate, collegePerk, custom];

  static String getLabel(String category) {
    switch (category) {
      case freeEvent:
        return 'Free Event Pass';
      case certificate:
        return 'Certificate Benefit';
      case collegePerk:
        return 'Campus Perk';
      case custom:
        return 'Special Reward';
      default:
        return 'Reward';
    }
  }
}

/// Statuses for reward redemptions
class RedemptionStatuses {
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String fulfilled = 'fulfilled';
  static const String rejected = 'rejected';
  static const String cancelled = 'cancelled';
  static const String refunded = 'refunded';

  static const List<String> all = [
    pending,
    approved,
    fulfilled,
    rejected,
    cancelled,
    refunded,
  ];

  static bool isTerminal(String status) {
    return status == fulfilled ||
        status == rejected ||
        status == cancelled ||
        status == refunded;
  }
}

/// A reward in the college rewards catalogue
class RewardModel {
  final String id;
  final String title;
  final String description;
  final String category; // from RewardCategories
  final int coinCost;
  final int availableStock; // -1 indicates unlimited stock
  final int initialStock;
  final bool isEnabled;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final List<String> eligibilityYears;
  final List<String> eligibilityDepartments;
  final int perStudentLimit; // 0 or -1 means unlimited
  final String fulfilmentType; // 'automatic' or 'manual_approval'
  final String termsAndConditions;
  final DateTime createdAt;
  final DateTime updatedAt;

  RewardModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.coinCost,
    this.availableStock = -1,
    this.initialStock = -1,
    this.isEnabled = true,
    this.startDate,
    this.expiryDate,
    List<String>? eligibilityYears,
    List<String>? eligibilityDepartments,
    this.perStudentLimit = 1,
    this.fulfilmentType = 'manual_approval',
    this.termsAndConditions = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : eligibilityYears = eligibilityYears ?? const [],
       eligibilityDepartments = eligibilityDepartments ?? const [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  bool get isUnlimitedStock => availableStock < 0;
  bool get isOutOfStock => !isUnlimitedStock && availableStock <= 0;

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  bool get isCurrentlyAvailable => isEnabled && !isExpired && !isOutOfStock;

  bool get isDemoOrSample {
    final lowerTitle = title.toLowerCase();
    final lowerDesc = description.toLowerCase();
    final lowerTerms = termsAndConditions.toLowerCase();
    return id.startsWith('cert_') ||
        lowerTitle.contains('sample') ||
        lowerTitle.contains('demo') ||
        lowerDesc.contains('sample') ||
        lowerDesc.contains('demonstration') ||
        lowerTerms.contains('sample') ||
        lowerTerms.contains('demonstration');
  }

  factory RewardModel.fromMap(Map<String, dynamic> map, String docId) {
    final List<String> years = [];
    if (map['eligibilityYears'] is List) {
      for (final y in (map['eligibilityYears'] as List)) {
        years.add(y.toString());
      }
    }

    final List<String> depts = [];
    if (map['eligibilityDepartments'] is List) {
      for (final d in (map['eligibilityDepartments'] as List)) {
        depts.add(d.toString());
      }
    }

    return RewardModel(
      id: docId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? RewardCategories.collegePerk,
      coinCost: (map['coinCost'] ?? 0) as int,
      availableStock: (map['availableStock'] ?? -1) as int,
      initialStock: (map['initialStock'] ?? -1) as int,
      isEnabled: map['isEnabled'] as bool? ?? true,
      startDate: map['startDate'] != null
          ? DateFormatter.parseDateTime(map['startDate'])
          : null,
      expiryDate: map['expiryDate'] != null
          ? DateFormatter.parseDateTime(map['expiryDate'])
          : null,
      eligibilityYears: years,
      eligibilityDepartments: depts,
      perStudentLimit: (map['perStudentLimit'] ?? 1) as int,
      fulfilmentType: map['fulfilmentType'] as String? ?? 'manual_approval',
      termsAndConditions: map['termsAndConditions'] as String? ?? '',
      createdAt: DateFormatter.parseDateTime(map['createdAt']),
      updatedAt: DateFormatter.parseDateTime(map['updatedAt']),
    );
  }

  factory RewardModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return RewardModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'coinCost': coinCost,
      'availableStock': availableStock,
      'initialStock': initialStock,
      'isEnabled': isEnabled,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'eligibilityYears': eligibilityYears,
      'eligibilityDepartments': eligibilityDepartments,
      'perStudentLimit': perStudentLimit,
      'fulfilmentType': fulfilmentType,
      'termsAndConditions': termsAndConditions,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  RewardModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    int? coinCost,
    int? availableStock,
    int? initialStock,
    bool? isEnabled,
    DateTime? startDate,
    DateTime? expiryDate,
    List<String>? eligibilityYears,
    List<String>? eligibilityDepartments,
    int? perStudentLimit,
    String? fulfilmentType,
    String? termsAndConditions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RewardModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      coinCost: coinCost ?? this.coinCost,
      availableStock: availableStock ?? this.availableStock,
      initialStock: initialStock ?? this.initialStock,
      isEnabled: isEnabled ?? this.isEnabled,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      eligibilityYears: eligibilityYears ?? this.eligibilityYears,
      eligibilityDepartments:
          eligibilityDepartments ?? this.eligibilityDepartments,
      perStudentLimit: perStudentLimit ?? this.perStudentLimit,
      fulfilmentType: fulfilmentType ?? this.fulfilmentType,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// A recorded reward redemption
class RewardRedemptionModel {
  final String id;
  final String studentId;
  final String studentName;
  final String studentRoll;
  final String studentEmail;
  final String rewardId;
  final String rewardTitle;
  final String rewardCategory;
  final int coinCost;
  final String status; // from RedemptionStatuses
  final String statusReason;
  final String linkedEventId;
  final String linkedRegistrationId;
  final bool certificateIssued;
  final bool verifiedAttendanceMet;
  final String idempotencyKey;
  final DateTime redeemedAt;
  final DateTime? fulfilledAt;
  final String fulfilledByAdminUid;

  RewardRedemptionModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.studentRoll = '',
    this.studentEmail = '',
    required this.rewardId,
    required this.rewardTitle,
    required this.rewardCategory,
    required this.coinCost,
    this.status = RedemptionStatuses.pending,
    this.statusReason = '',
    this.linkedEventId = '',
    this.linkedRegistrationId = '',
    this.certificateIssued = false,
    this.verifiedAttendanceMet = false,
    this.idempotencyKey = '',
    DateTime? redeemedAt,
    this.fulfilledAt,
    this.fulfilledByAdminUid = '',
  }) : redeemedAt = redeemedAt ?? DateTime.now();

  bool get isPending => status == RedemptionStatuses.pending;
  bool get isApproved => status == RedemptionStatuses.approved;
  bool get isFulfilled => status == RedemptionStatuses.fulfilled;
  bool get isRejected => status == RedemptionStatuses.rejected;
  bool get isRefunded => status == RedemptionStatuses.refunded;
  bool get isCancelled => status == RedemptionStatuses.cancelled;

  factory RewardRedemptionModel.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    return RewardRedemptionModel(
      id: docId,
      studentId: map['studentId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      studentRoll: map['studentRoll'] as String? ?? '',
      studentEmail: map['studentEmail'] as String? ?? '',
      rewardId: map['rewardId'] as String? ?? '',
      rewardTitle: map['rewardTitle'] as String? ?? '',
      rewardCategory:
          map['rewardCategory'] as String? ?? RewardCategories.collegePerk,
      coinCost: (map['coinCost'] ?? 0) as int,
      status: map['status'] as String? ?? RedemptionStatuses.pending,
      statusReason: map['statusReason'] as String? ?? '',
      linkedEventId: map['linkedEventId'] as String? ?? '',
      linkedRegistrationId: map['linkedRegistrationId'] as String? ?? '',
      certificateIssued: map['certificateIssued'] as bool? ?? false,
      verifiedAttendanceMet: map['verifiedAttendanceMet'] as bool? ?? false,
      idempotencyKey: map['idempotencyKey'] as String? ?? '',
      redeemedAt: DateFormatter.parseDateTime(map['redeemedAt']),
      fulfilledAt: map['fulfilledAt'] != null
          ? DateFormatter.parseDateTime(map['fulfilledAt'])
          : null,
      fulfilledByAdminUid: map['fulfilledByAdminUid'] as String? ?? '',
    );
  }

  factory RewardRedemptionModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return RewardRedemptionModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'studentRoll': studentRoll,
      'studentEmail': studentEmail,
      'rewardId': rewardId,
      'rewardTitle': rewardTitle,
      'rewardCategory': rewardCategory,
      'coinCost': coinCost,
      'status': status,
      'statusReason': statusReason,
      'linkedEventId': linkedEventId,
      'linkedRegistrationId': linkedRegistrationId,
      'certificateIssued': certificateIssued,
      'verifiedAttendanceMet': verifiedAttendanceMet,
      'idempotencyKey': idempotencyKey,
      'redeemedAt': Timestamp.fromDate(redeemedAt),
      'fulfilledAt': fulfilledAt != null
          ? Timestamp.fromDate(fulfilledAt!)
          : null,
      'fulfilledByAdminUid': fulfilledByAdminUid,
    };
  }
}

/// Unified coin transaction ledger entry
class CoinTransactionModel {
  final String id;
  final String studentId;
  final int amount; // positive = credit, negative = debit
  final String
  type; // 'attendance_verified', 'reward_redemption', 'redemption_refund', 'admin_adjustment', 'streak_milestone', 'referral_bonus'
  final String title;
  final String description;
  final String refId; // eventId, rewardId, redemptionId
  final String idempotencyKey;
  final DateTime createdAt;

  CoinTransactionModel({
    required this.id,
    required this.studentId,
    required this.amount,
    required this.type,
    required this.title,
    this.description = '',
    this.refId = '',
    this.idempotencyKey = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCredit => amount > 0;
  bool get isDebit => amount < 0;

  factory CoinTransactionModel.fromMap(Map<String, dynamic> map, String docId) {
    return CoinTransactionModel(
      id: docId,
      studentId: map['studentId'] as String? ?? '',
      amount: (map['amount'] ?? map['coinsAwarded'] ?? 0) as int,
      type: map['type'] ?? map['rewardType'] ?? 'attendance_verified',
      title: map['title'] ?? map['rewardReason'] ?? 'Coin Activity',
      description: map['description'] ?? '',
      refId: map['refId'] ?? map['eventId'] ?? '',
      idempotencyKey: map['idempotencyKey'] ?? '',
      createdAt: DateFormatter.parseDateTime(map['createdAt']),
    );
  }

  factory CoinTransactionModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return CoinTransactionModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'amount': amount,
      'type': type,
      'title': title,
      'description': description,
      'refId': refId,
      'idempotencyKey': idempotencyKey,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Configurable Gamification & Earning Rules
class GamificationRuleModel {
  final String id;
  final String name;
  final String
  activityType; // 'attendance', 'streak_milestone', 'referral', 'profile'
  final int coinAmount;
  final bool isEnabled;
  final String description;
  final Map<String, dynamic> metadata;

  const GamificationRuleModel({
    required this.id,
    required this.name,
    required this.activityType,
    required this.coinAmount,
    this.isEnabled = true,
    this.description = '',
    this.metadata = const {},
  });

  factory GamificationRuleModel.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    return GamificationRuleModel(
      id: docId,
      name: map['name'] as String? ?? '',
      activityType: map['activityType'] as String? ?? 'attendance',
      coinAmount: (map['coinAmount'] ?? 50) as int,
      isEnabled: map['isEnabled'] as bool? ?? true,
      description: map['description'] as String? ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'activityType': activityType,
      'coinAmount': coinAmount,
      'isEnabled': isEnabled,
      'description': description,
      'metadata': metadata,
    };
  }
}

/// Referral tracking record
class ReferralRecordModel {
  final String id; // deterministic: ${referrerUid}_${referredUid}
  final String referrerUid;
  final String referrerCode;
  final String referredUid;
  final String referredName;
  final String status; // 'pending', 'qualified', 'completed'
  final String qualifyingAction;
  final int coinsAwarded;
  final int friendCoinsAwarded;
  final DateTime createdAt;
  final DateTime? qualifiedAt;

  ReferralRecordModel({
    required this.id,
    required this.referrerUid,
    required this.referrerCode,
    required this.referredUid,
    required this.referredName,
    this.status = 'pending',
    this.qualifyingAction = 'first_event_attended',
    this.coinsAwarded = 0,
    this.friendCoinsAwarded = 50,
    DateTime? createdAt,
    this.qualifiedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCompleted => status == 'completed' || status == 'qualified';
  String get displayStatus => isCompleted ? 'Completed' : 'Pending';

  factory ReferralRecordModel.fromMap(Map<String, dynamic> map, String docId) {
    return ReferralRecordModel(
      id: docId,
      referrerUid: map['referrerUid'] as String? ?? '',
      referrerCode: map['referrerCode'] as String? ?? '',
      referredUid: map['referredUid'] as String? ?? '',
      referredName: map['referredName'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      qualifyingAction:
          map['qualifyingAction'] as String? ?? 'first_event_attended',
      coinsAwarded: (map['coinsAwarded'] ?? 0) as int,
      friendCoinsAwarded: (map['friendCoinsAwarded'] ?? 50) as int,
      createdAt: DateFormatter.parseDateTime(map['createdAt']),
      qualifiedAt: map['qualifiedAt'] != null
          ? DateFormatter.parseDateTime(map['qualifiedAt'])
          : null,
    );
  }

  factory ReferralRecordModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ReferralRecordModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'referrerUid': referrerUid,
      'referrerCode': referrerCode,
      'referredUid': referredUid,
      'referredName': referredName,
      'status': status,
      'qualifyingAction': qualifyingAction,
      'coinsAwarded': coinsAwarded,
      'friendCoinsAwarded': friendCoinsAwarded,
      'createdAt': Timestamp.fromDate(createdAt),
      'qualifiedAt': qualifiedAt != null
          ? Timestamp.fromDate(qualifiedAt!)
          : null,
    };
  }

  ReferralRecordModel copyWith({
    String? id,
    String? referrerUid,
    String? referrerCode,
    String? referredUid,
    String? referredName,
    String? status,
    String? qualifyingAction,
    int? coinsAwarded,
    int? friendCoinsAwarded,
    DateTime? createdAt,
    DateTime? qualifiedAt,
  }) {
    return ReferralRecordModel(
      id: id ?? this.id,
      referrerUid: referrerUid ?? this.referrerUid,
      referrerCode: referrerCode ?? this.referrerCode,
      referredUid: referredUid ?? this.referredUid,
      referredName: referredName ?? this.referredName,
      status: status ?? this.status,
      qualifyingAction: qualifyingAction ?? this.qualifyingAction,
      coinsAwarded: coinsAwarded ?? this.coinsAwarded,
      friendCoinsAwarded: friendCoinsAwarded ?? this.friendCoinsAwarded,
      createdAt: createdAt ?? this.createdAt,
      qualifiedAt: qualifiedAt ?? this.qualifiedAt,
    );
  }
}

enum ReferralValidationStatus {
  valid,
  notFound,
  selfReferral,
  alreadyReferred,
  invalidFormat,
}

class ReferralValidationResult {
  final ReferralValidationStatus status;
  final String message;
  final String? referrerUid;
  final String? referrerName;
  final String? normalizedCode;

  const ReferralValidationResult({
    required this.status,
    required this.message,
    this.referrerUid,
    this.referrerName,
    this.normalizedCode,
  });

  bool get isValid => status == ReferralValidationStatus.valid;
}
