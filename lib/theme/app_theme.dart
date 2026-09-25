import 'package:flutter/material.dart';

/// Central place for the Eventary visual language.
/// Keeping colors/typography here means the whole app can be
/// re-themed later (e.g. white-label for different clients)
/// without touching widget code.
class AppColors {
  AppColors._();

  static const Color navy = Color(0xFF11172B);
  static const Color navyDark = Color(0xFF0B0F1E);
  static const Color charcoal = Color(0xFF1B2136);
  static const Color surface = Color(0xFFF6F7FB);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE4E7F0);
  static const Color textPrimary = Color(0xFF161B2C);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnDark = Color(0xFFE9ECF7);
  static const Color textOnDarkMuted = Color(0xFF9AA2C0);

  static const Color accent = Color(0xFF6C5CE7); // purple accent
  static const Color accentSecondary = Color(0xFF4C6FFF); // blue accent
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444); // <- baris baru

  static const List<Color> accentGradient = [accent, accentSecondary];

  static const Color mapBackground = Color(0xFFE9EDF7);
  static const Color mapGrid = Color(0xFFD6DCEE);
  static const Color mapLand = Color(0xFFDDE3F2);
}

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> subtle = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> floating = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Segoe UI',
    scaffoldBackgroundColor: AppColors.surface,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      secondary: AppColors.accentSecondary,
      surface: AppColors.card,
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    splashFactory: NoSplash.splashFactory,
    hoverColor: AppColors.accent.withOpacity(0.06),
    visualDensity: VisualDensity.standard,
  );
}
