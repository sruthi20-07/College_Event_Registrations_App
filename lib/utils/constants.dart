import 'package:flutter/material.dart';

class AppColors {
  // Main Pastel Theme Palette Tokens (Explicit & Canonical)
  static const Color background = Color(0xFFFAF9F6); // Warm off-white
  
  // Sage Green (Primary Brand)
  static const Color primarySage = Color(0xFFA8C3A0); // Primary pastel sage green
  static const Color pastelSage = primarySage;
  static const Color sageDark = Color(0xFF4A6B44); // Deep sage for readable text & icons
  static const Color sageLight = Color(0xFFE8F1E6); // Very soft sage tint
  static const Color primary = primarySage;
  static const Color primaryDark = sageDark;
  static const Color primaryLight = sageLight;

  // Soft Lavender
  static const Color pastelLavender = Color(0xFFD9D2F0); // Soft lavender
  static const Color lavenderDark = Color(0xFF5D5184); // Deep lavender
  static const Color lavenderLight = Color(0xFFF1EEF9); // Lavender tint
  static const Color lavender = pastelLavender;

  // Pale Peach
  static const Color pastelPeach = Color(0xFFF6D7C3); // Pale peach
  static const Color peachDark = Color(0xFF9A5930); // Deep peach
  static const Color peachLight = Color(0xFFFAF0E9); // Peach tint
  static const Color peach = pastelPeach;

  // Powder Pink
  static const Color pastelPink = Color(0xFFF2D5DC); // Powder pink
  static const Color pinkDark = Color(0xFF8F4154); // Deep pink
  static const Color pinkLight = Color(0xFFFAEEF1); // Pink tint
  static const Color pink = pastelPink;

  // Light Sky Blue
  static const Color pastelSkyBlue = Color(0xFFD7E7F4); // Light sky blue
  static const Color skyBlueDark = Color(0xFF386389); // Deep sky blue
  static const Color skyBlueLight = Color(0xFFEDF4FA); // Sky blue tint
  static const Color skyBlue = pastelSkyBlue;

  // Cards & Surfaces
  static const Color cardWhite = Color(0xFFFFFFFF); // White cards
  static const Color cardBackground = Color(0xFFFFFFFF);
  
  // Typography
  static const Color textMain = Color(0xFF343A40); // Main text
  static const Color textPrimary = Color(0xFF343A40);
  static const Color textSecondary = Color(0xFF7A828A); // Secondary text
  
  // Borders & Dividers
  static const Color border = Color(0xFFE8E8E4); // Borders and dividers
  static const Color divider = Color(0xFFE8E8E4);

  // Status Colors (Pastel base with clear readable dark tone)
  static const Color success = Color(0xFFA8C3A0);
  static const Color successDark = Color(0xFF3E5C38);
  static const Color warning = Color(0xFFF6D7C3);
  static const Color warningDark = Color(0xFF9A5930);
  static const Color error = Color(0xFFF2D5DC);
  static const Color errorDark = Color(0xFF9B2C3B);
}

class UserRoles {
  static const String student = 'student';
  static const String faculty = 'faculty';
  static const String coordinator = 'coordinator';
  static const String admin = 'admin';

  static const List<String> allRoles = [student, faculty, coordinator, admin];

  static bool isAdminOrStaff(String role) {
    return role == admin || role == faculty || role == coordinator;
  }
}

class EventCategories {
  static const String all = 'All';
  static const String technical = 'Technical';
  static const String workshop = 'Workshop';
  static const String cultural = 'Cultural';
  static const String sports = 'Sports';
  static const String hackathon = 'Hackathon';
  static const String seminar = 'Seminar';

  static const List<String> categories = [
    technical,
    workshop,
    cultural,
    sports,
    hackathon,
    seminar,
  ];
}

class EventStatuses {
  static const String upcoming = 'upcoming';
  static const String ongoing = 'ongoing';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
}

class RegistrationStatuses {
  static const String registered = 'registered';
  static const String cancelled = 'cancelled';
}

class PaymentStatuses {
  static const String free = 'free';
  static const String completed = 'completed';
  static const String pending = 'pending';
  static const String failed = 'failed';
}
