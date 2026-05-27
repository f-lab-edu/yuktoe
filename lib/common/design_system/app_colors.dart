import 'package:flutter/material.dart';

abstract class AppColors {
  // Color groups
  static const gray = _Gray();
  static const primary = _Primary();
  static const pink = _Pink();
  static const violet = _Violet();

  // Basic
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  // Text
  static const textPrimary = Color(0xFF101828);
  static const textSecondary = Color(0xFF6A7282);
  static const textTertiary = Color(0xFF364153);
  static const textDisabled = Color(0xFF98A2B3);
  static const textOnDark = white;

  // Background
  static const backgroundPrimary = white;
  static const backgroundSecondary = Color(0xFFF9FAFB);
  static const backgroundInverse = Color(0xFF101828);
  static const backgroundVioletLight = Color(0xFFEEF2FF);

  // Border
  static const borderPrimary = Color(0xFFE5E7EB);
  static const borderSecondary = Color(0xFFF3F4F6);
  static const divider = Color(0xFFF3F4F6);

  // Brand
  static const brandPrimary = Color(0xFF2563EB);
  static const brandPrimaryPressed = Color(0xFF1D4ED8);
  static const brandPrimaryLight = Color(0xFFEFF6FF);
  static const brandAccent = Color(0xFF2B7FFF);

  // Semantic
  static const error = Color(0xFFFB2C36);
  static const infoTitle = Color(0xFF1C398E);
  static const infoBody = Color(0xFF1447E6);

  // App specific
  static const loginGradientTop = Color.fromARGB(255, 121, 195, 255);
  static const kakaoBackground = Color(0xFFFEE500);
}

class _Gray {
  const _Gray();

  final Color t50 = const Color(0xFFF9FAFB);
  final Color t100 = const Color(0xFFF3F4F6);
  final Color t200 = const Color(0xFFE5E7EB);
  final Color t300 = const Color(0xFFD0D5DD);
  final Color t400 = const Color(0xFF98A2B3);
  final Color t500 = const Color(0xFF6A7282);
  final Color t600 = const Color(0xFF475467);
  final Color t700 = const Color(0xFF344054);
  final Color t800 = const Color(0xFF1D2939);
  final Color t900 = const Color(0xFF101828);
}

class _Primary {
  const _Primary();

  final Color t50 = const Color(0xFFEFF6FF);
  final Color t100 = const Color(0xFFDBEAFE);
  final Color t200 = const Color(0xFFBFDBFE);
  final Color t300 = const Color(0xFF93C5FD);
  final Color t400 = const Color(0xFF60A5FA);
  final Color t500 = const Color(0xFF3B82F6);
  final Color t600 = const Color(0xFF2563EB);
  final Color t700 = const Color(0xFF1D4ED8);
}

class _Pink {
  const _Pink();

  final Color t400 = const Color(0xFFF6339A);
  final Color t500 = const Color(0xFFE60076);
  final Color t600 = const Color(0xFFEC003F);
}

class _Violet {
  const _Violet();

  final Color t400 = const Color(0xFF615FFF);
  final Color t500 = const Color(0xFF4F39F6);
  final Color t600 = const Color(0xFF9810FA);
}
