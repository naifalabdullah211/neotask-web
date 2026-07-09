import 'package:flutter/material.dart';

/// NeoTask color palette — inspired by geometric gradient tones
/// (deep navy, purple, green, light blue) WITHOUT using any official logo.
class AppColors {
  static const Color navy = Color(0xFF0B1D4D);
  static const Color deepBlue = Color(0xFF1E3A8A);
  static const Color purple = Color(0xFF7C3AED);
  static const Color green = Color(0xFF10B981);
  static const Color lightBlue = Color(0xFF38BDF8);

  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF11182C);
  static const Color textSecondary = Color(0xFF64748B);

  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusApproved = Color(0xFF10B981);
  static const Color statusRejected = Color(0xFFEF4444);
  static const Color statusInProgress = Color(0xFF38BDF8);
  static const Color statusSubmitted = Color(0xFF7C3AED);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, deepBlue, purple],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green, lightBlue],
  );
}

/// Shared type scale for "premium" surfaces (auth screens, empty states,
/// marketing-style sections). Keeps heading/body weight & spacing consistent
/// wherever this look is reused, instead of inline TextStyle literals.
class AppTextStyles {
  static const TextStyle headlineLg = TextStyle(
    color: Colors.white,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle titleMd = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static const TextStyle bodySm = TextStyle(
    color: Colors.white70,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle captionSm = TextStyle(
    color: Colors.white60,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.deepBlue,
        primary: AppColors.deepBlue,
        secondary: AppColors.purple,
        tertiary: AppColors.green,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.deepBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.deepBlue,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

Color statusColor(String statusName) {
  switch (statusName) {
    case 'assigned':
      return AppColors.textSecondary;
    case 'inProgress':
      return AppColors.statusInProgress;
    case 'submitted':
      return AppColors.statusSubmitted;
    case 'approved':
      return AppColors.statusApproved;
    case 'rejected':
      return AppColors.statusRejected;
    case 'editRequested':
      return AppColors.statusPending;
    default:
      return AppColors.textSecondary;
  }
}

String statusLabelAr(String statusName) {
  switch (statusName) {
    case 'assigned':
      return 'مُسندة';
    case 'inProgress':
      return 'قيد التنفيذ';
    case 'submitted':
      return 'بانتظار المراجعة';
    case 'approved':
      return 'مكتملة';
    case 'rejected':
      return 'مرفوضة';
    case 'editRequested':
      return 'مطلوب تعديل';
    default:
      return statusName;
  }
}
