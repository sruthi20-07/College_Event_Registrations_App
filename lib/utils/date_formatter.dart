import 'package:cloud_firestore/cloud_firestore.dart';

class DateFormatter {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Formats DateTime to string like "18 Oct 2026"
  static String formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  /// Parses Firestore Timestamp or String/DateTime into DateTime
  static DateTime parseDateTime(dynamic input) {
    if (input == null) return DateTime.now();
    if (input is Timestamp) return input.toDate();
    if (input is DateTime) return input;
    if (input is String) {
      try {
        return DateTime.parse(input);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  /// Formats time string (e.g. 10:00 AM)
  static String formatTime(DateTime? date) {
    if (date == null) return '';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Formats full date and time string (e.g. "18 Oct 2026, 10:00 AM")
  static String formatFullDateTime(DateTime? date) {
    if (date == null) return '';
    return '${formatDate(date)}, ${formatTime(date)}';
  }
}
