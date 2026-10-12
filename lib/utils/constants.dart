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

  static bool isAdminOrStaff(String? role) {
    if (role == null) return false;
    final r = role.trim().toLowerCase();
    return r == admin || r == faculty || r == coordinator;
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

class AcademicYears {
  static const String all = 'All Years';
  static const String year1 = '1st Year';
  static const String year2 = '2nd Year';
  static const String year3 = '3rd Year';
  static const String year4 = '4th Year';

  static const List<String> years = [
    year1,
    year2,
    year3,
    year4,
  ];

  static const List<String> allWithOption = [
    all,
    year1,
    year2,
    year3,
    year4,
  ];

  /// Normalizes year string for robust matching (e.g. '2nd', '2', '2nd Year')
  static String normalize(String input) {
    final clean = input.trim().toLowerCase();
    if (clean.contains('1') || clean.contains('first')) return year1;
    if (clean.contains('2') || clean.contains('second')) return year2;
    if (clean.contains('3') || clean.contains('third')) return year3;
    if (clean.contains('4') || clean.contains('fourth')) return year4;
    return input.trim();
  }

  static bool matches(List<String> allowedYears, String studentYear) {
    if (allowedYears.isEmpty || allowedYears.contains('All') || allowedYears.contains(all)) {
      return true;
    }
    if (studentYear.trim().isEmpty) return false;
    final normalizedStudent = normalize(studentYear);
    return allowedYears.any((y) => normalize(y) == normalizedStudent || y == studentYear);
  }
}

class AcademicDepartments {
  static const String all = 'All Departments';
  static const String it = 'Information Technology';
  static const String cse = 'Computer Science';
  static const String ece = 'Electronics & Communication';
  static const String eee = 'Electrical & Electronics';
  static const String mech = 'Mechanical Engineering';
  static const String civil = 'Civil Engineering';
  static const String aiDs = 'AI & Data Science';

  static const List<String> departments = [
    it,
    cse,
    ece,
    eee,
    mech,
    civil,
    aiDs,
  ];

  static const List<String> allWithOption = [
    all,
    it,
    cse,
    ece,
    eee,
    mech,
    civil,
    aiDs,
  ];

  /// Normalizes department string for robust matching (e.g. 'CSE' -> 'Computer Science')
  static String normalize(String input) {
    final clean = input.trim().toLowerCase();
    if (clean == 'it' || clean.contains('information tech')) return it;
    if (clean == 'cse' || clean == 'cs' || clean.contains('computer science')) return cse;
    if (clean == 'ece' || clean.contains('electronics') && clean.contains('comm')) return ece;
    if (clean == 'eee' || clean.contains('electrical')) return eee;
    if (clean == 'mech' || clean.contains('mechanical')) return mech;
    if (clean == 'civil' || clean.contains('civil')) return civil;
    if (clean.contains('ai') || clean.contains('data science') || clean == 'aids') return aiDs;
    return input.trim();
  }

  static bool matches(List<String> allowedDepts, String studentDept) {
    if (allowedDepts.isEmpty || allowedDepts.contains('All') || allowedDepts.contains(all)) {
      return true;
    }
    if (studentDept.trim().isEmpty) return false;
    final normalizedStudent = normalize(studentDept);
    return allowedDepts.any((d) => normalize(d) == normalizedStudent || d.toLowerCase() == studentDept.toLowerCase());
  }
}

class PaymentStatuses {
  static const String free = 'free';
  static const String completed = 'completed';
  static const String pending = 'pending';
  static const String failed = 'failed';
}
