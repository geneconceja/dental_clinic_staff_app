/// app_colors.dart
/// Dental Clinic Staff/Admin App
///
/// Single source of truth for all color constants.
/// Do NOT use raw Color(...) or Colors.X anywhere else in the app — always
/// reference a named constant from this file.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ---------- Brand / Primary ----------
  /// Deep teal — the clinic's primary brand color.
  static const Color primary = Color(0xFF0D7377);

  /// Slightly lighter teal for hover/focus states.
  static const Color primaryLight = Color(0xFF14A8AE);

  /// Darkened teal for pressed states.
  static const Color primaryDark = Color(0xFF094F52);

  // ---------- Accent ----------
  /// Warm amber used sparingly for CTAs and highlights.
  static const Color accent = Color(0xFFE8A838);

  // ---------- Semantic / Status ----------
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFF57C00);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF1565C0);
  static const Color infoLight = Color(0xFFE3F2FD);

  // ---------- Appointment Status Colors ----------
  static const Color statusPending = Color(0xFFF57C00);
  static const Color statusConfirmed = Color(0xFF2E7D32);
  static const Color statusCancelled = Color(0xFFC62828);
  static const Color statusCompleted = Color(0xFF1565C0);
  static const Color statusNoShow = Color(0xFF6A1B9A);

  // ---------- Neutrals ----------
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEF2F6);
  static const Color border = Color(0xFFDDE3EA);
  static const Color divider = Color(0xFFEEF2F6);

  // ---------- Text ----------
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF5A6A7A);
  static const Color textDisabled = Color(0xFFADB5BD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ---------- Sidebar ----------
  static const Color sidebarBackground = Color(0xFF0A3D40);
  static const Color sidebarItemActive = Color(0xFF0D7377);
  static const Color sidebarText = Color(0xFFB2DFDB);
  static const Color sidebarTextActive = Color(0xFFFFFFFF);
}
