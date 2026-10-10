import 'package:flutter/material.dart';

class AppColors {
  // Canonical Vibrant Pastel Palette Tokens
  static const Color background = Color(0xFFFFF8F2); // Warm Cream
  static const Color cardWhite = Color(0xFFFFFFFF); // Card Background
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Primary Accent (Coral)
  static const Color coral = Color(0xFFFF7A59); // Primary Accent Coral
  static const Color coralDark = Color(0xFFC84525); // Deep Coral for text/icons
  static const Color coralLight = Color(0xFFFFEFEB); // Coral Tint
  static const Color primary = coral;
  static const Color primaryDark = coralDark;
  static const Color primaryLight = coralLight;

  // Secondary Accent (Vibrant Lavender)
  static const Color lavender = Color(0xFF7C6CF2); // Vibrant Lavender
  static const Color lavenderDark = Color(0xFF4C3EBE); // Deep Lavender for text/icons
  static const Color lavenderLight = Color(0xFFF1EFFF); // Lavender Tint
  static const Color secondary = lavender;
  static const Color pastelLavender = lavender;

  // Mint Green
  static const Color mint = Color(0xFF72C9A7); // Mint
  static const Color mintDark = Color(0xFF267D5B); // Deep Mint
  static const Color mintLight = Color(0xFFEBF7F2); // Mint Tint
  static const Color primarySage = mint; // Compatibility aliases
  static const Color pastelSage = mint;
  static const Color sageDark = mintDark;
  static const Color sageLight = mintLight;

  // Sky Blue
  static const Color skyBlue = Color(0xFF70B7F4); // Sky Blue
  static const Color skyBlueDark = Color(0xFF276FA8); // Deep Sky Blue
  static const Color skyBlueLight = Color(0xFFEEF6FD); // Sky Blue Tint
  static const Color pastelSkyBlue = skyBlue;

  // Pink
  static const Color pink = Color(0xFFF4A7C5); // Pink
  static const Color pinkDark = Color(0xFFA63964); // Deep Pink
  static const Color pinkLight = Color(0xFFFDF0F5); // Pink Tint
  static const Color pastelPink = pink;

  // Sunny Yellow
  static const Color sunnyYellow = Color(0xFFFFC857); // Sunny Yellow
  static const Color yellowDark = Color(0xFF9E6D00); // Deep Yellow
  static const Color yellowLight = Color(0xFFFFF8E7); // Yellow Tint
  static const Color pastelPeach = sunnyYellow; // Compatibility aliases
  static const Color peach = sunnyYellow;
  static const Color peachDark = yellowDark;
  static const Color peachLight = yellowLight;

  // Typography
  static const Color textMain = Color(0xFF292638); // Primary text
  static const Color textPrimary = Color(0xFF292638);
  static const Color textSecondary = Color(0xFF777586); // Secondary text

  // Borders & Dividers
  static const Color border = Color(0xFFF0E8E2); // Border
  static const Color divider = Color(0xFFF0E8E2);

  // Status Colors
  static const Color success = mint;
  static const Color successDark = mintDark;
  static const Color warning = sunnyYellow;
  static const Color warningDark = yellowDark;
  static const Color error = pink;
  static const Color errorDark = Color(0xFFDC2626);
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
