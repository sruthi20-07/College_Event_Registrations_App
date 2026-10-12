import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_formatter.dart';

/// Cryptographic QR Payload embedded inside the rotating event QR code
class AttendanceQrPayload {
  static const String qrType = 'event_attendance_qr';

  final String type;
  final String eventId;
  final String sessionId;
  final String token;
  final String title;
  final String nonce;
  final int timestamp;
  final int expiresAt;
  final String hash;

  const AttendanceQrPayload({
    this.type = qrType,
    required this.eventId,
    this.sessionId = '',
    this.token = '',
    this.title = '',
    this.nonce = '',
    this.timestamp = 0,
    this.expiresAt = 0,
    this.hash = '',
  });

  /// Generates a cryptographically random hex nonce
  static String generateNonce([int length = 16]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Creates a short-lived payload valid for [validDurationSeconds]
  factory AttendanceQrPayload.create({
    required String eventId,
    required String sessionId,
    required String adminUid,
    int validDurationSeconds = 20,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expires = now + (validDurationSeconds * 1000);
    final nonce = generateNonce(12);

    // Cross-platform signature digest combining event, session, nonce, timestamp, and adminUid
    final rawSign = '$eventId:$sessionId:$nonce:$now:$adminUid';
    final signHash = _computeSimpleHash(rawSign);

    return AttendanceQrPayload(
      eventId: eventId,
      sessionId: sessionId,
      nonce: nonce,
      timestamp: now,
      expiresAt: expires,
      hash: signHash,
    );
  }

  /// Computes a cross-platform 32-bit hash digest formatted as a 16-character hex string
  /// that executes identically across Flutter Web (JS numbers) and Flutter Mobile/Desktop (VM).
  static String _computeSimpleHash(String input) {
    int hash1 = 0x811c9dc5;
    int hash2 = 0x55555555;
    final bytes = utf8.encode(input);
    for (int i = 0; i < bytes.length; i++) {
      final byte = bytes[i];
      hash1 = ((hash1 ^ byte) * 0x01000193) & 0xFFFFFFFF;
      hash2 = (((hash2 << 5) & 0xFFFFFFFF) | ((hash2 >> 27) & 0x1F)) ^ byte;
      hash2 = (hash2 * 0x045d9f3b) & 0xFFFFFFFF;
    }
    final p1 = hash1.toRadixString(16).padLeft(8, '0');
    final p2 = hash2.toRadixString(16).padLeft(8, '0');
    return '$p1$p2';
  }

  bool get isDirectEventQr => sessionId.isEmpty && (token.isNotEmpty || eventId.isNotEmpty);

  bool get isExpired => expiresAt > 0 && DateTime.now().millisecondsSinceEpoch > expiresAt;

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'eventId': eventId,
      if (sessionId.isNotEmpty) 'sessionId': sessionId,
      if (token.isNotEmpty) 'token': token,
      if (title.isNotEmpty) 'title': title,
      if (nonce.isNotEmpty) 'nonce': nonce,
      if (timestamp > 0) 't': timestamp,
      if (expiresAt > 0) 'exp': expiresAt,
      if (hash.isNotEmpty) 'h': hash,
    };
  }

  String toRawString() => jsonEncode(toMap());

  static AttendanceQrPayload? tryParse(String raw) {
    try {
      final clean = raw.trim();
      if (clean.isEmpty) return null;

      // Handle raw evtok_ token strings (format: evtok_{eventId}_{hex} or evtok_{eventId})
      if (clean.startsWith('evtok_')) {
        final firstUnderscore = clean.indexOf('_');
        final lastUnderscore = clean.lastIndexOf('_');
        final String eventId;
        if (firstUnderscore != -1 && lastUnderscore > firstUnderscore) {
          eventId = clean.substring(firstUnderscore + 1, lastUnderscore);
        } else if (firstUnderscore != -1) {
          eventId = clean.substring(firstUnderscore + 1);
        } else {
          return null;
        }

        if (eventId.isEmpty) return null;
        return AttendanceQrPayload(
          type: qrType,
          eventId: eventId,
          token: clean,
          hash: clean,
        );
      }

      if (!clean.startsWith('{') || !clean.endsWith('}')) return null;
      final map = jsonDecode(clean);
      if (map is! Map) return null;
      if (map['type'] != qrType && map['type'] != 'college_event_attendance' && map['eventId'] == null) {
        return null;
      }

      final eventId = (map['eventId'] as String? ?? '').trim();
      if (eventId.isEmpty) return null;

      final token = (map['token'] as String? ?? map['qrToken'] as String? ?? '').trim();
      final hash = (map['h'] as String? ?? map['hash'] as String? ?? (token.isNotEmpty ? token : '')).trim();

      return AttendanceQrPayload(
        type: map['type'] as String? ?? qrType,
        eventId: eventId,
        sessionId: map['sessionId'] as String? ?? '',
        token: token,
        title: map['title'] as String? ?? '',
        nonce: map['nonce'] as String? ?? '',
        timestamp: (map['t'] as num? ?? map['timestamp'] as num? ?? 0).toInt(),
        expiresAt: (map['exp'] as num? ?? map['expiresAt'] as num? ?? 0).toInt(),
        hash: hash,
      );
    } catch (_) {
      return null;
    }
  }

}

/// Firestore Model for an active Attendance Session created by Admin
class AttendanceSessionModel {
  final String id;
  final String eventId;
  final String eventTitle;
  final String createdByAdminUid;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? closedAt;
  final bool isActive;
  final int refreshIntervalSeconds;
  final String currentNonce;
  final String currentHash;
  final int attendeeCount;
  final DateTime lastRotatedAt;

  AttendanceSessionModel({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.createdByAdminUid,
    required this.createdAt,
    this.expiresAt,
    this.closedAt,
    this.isActive = true,
    this.refreshIntervalSeconds = 15,
    this.currentNonce = '',
    this.currentHash = '',
    this.attendeeCount = 0,
    DateTime? lastRotatedAt,
  }) : lastRotatedAt = lastRotatedAt ?? createdAt;

  factory AttendanceSessionModel.fromMap(Map<String, dynamic> map, String docId) {
    return AttendanceSessionModel(
      id: docId,
      eventId: map['eventId'] as String? ?? '',
      eventTitle: map['eventTitle'] as String? ?? '',
      createdByAdminUid: map['createdByAdminUid'] as String? ?? '',
      createdAt: DateFormatter.parseDateTime(map['createdAt']),
      expiresAt: map['expiresAt'] != null ? DateFormatter.parseDateTime(map['expiresAt']) : null,
      closedAt: map['closedAt'] != null ? DateFormatter.parseDateTime(map['closedAt']) : null,
      isActive: map['isActive'] as bool? ?? true,
      refreshIntervalSeconds: (map['refreshIntervalSeconds'] as num? ?? 15).toInt(),
      currentNonce: map['currentNonce'] as String? ?? '',
      currentHash: map['currentHash'] as String? ?? '',
      attendeeCount: (map['attendeeCount'] as num? ?? 0).toInt(),
      lastRotatedAt: DateFormatter.parseDateTime(map['lastRotatedAt'] ?? map['createdAt']),
    );
  }

  factory AttendanceSessionModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AttendanceSessionModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'eventTitle': eventTitle,
      'createdByAdminUid': createdByAdminUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
      'isActive': isActive,
      'refreshIntervalSeconds': refreshIntervalSeconds,
      'currentNonce': currentNonce,
      'currentHash': currentHash,
      'attendeeCount': attendeeCount,
      'lastRotatedAt': Timestamp.fromDate(lastRotatedAt),
    };
  }

  AttendanceSessionModel copyWith({
    String? id,
    String? eventId,
    String? eventTitle,
    String? createdByAdminUid,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? closedAt,
    bool? isActive,
    int? refreshIntervalSeconds,
    String? currentNonce,
    String? currentHash,
    int? attendeeCount,
    DateTime? lastRotatedAt,
  }) {
    return AttendanceSessionModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      eventTitle: eventTitle ?? this.eventTitle,
      createdByAdminUid: createdByAdminUid ?? this.createdByAdminUid,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      closedAt: closedAt ?? this.closedAt,
      isActive: isActive ?? this.isActive,
      refreshIntervalSeconds: refreshIntervalSeconds ?? this.refreshIntervalSeconds,
      currentNonce: currentNonce ?? this.currentNonce,
      currentHash: currentHash ?? this.currentHash,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      lastRotatedAt: lastRotatedAt ?? this.lastRotatedAt,
    );
  }
}
