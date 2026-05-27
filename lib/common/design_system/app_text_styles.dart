import 'package:flutter/material.dart';

abstract class AppTextStyles {
  static const display = _Scale(fontSize: 36, letterSpacing: 0.37);
  static const heading1 = _Scale(fontSize: 30, letterSpacing: 0.40, height: 1.2);
  static const heading2 = _Scale(fontSize: 24, letterSpacing: 0.07, height: 1.33);
  static const heading3 = _Scale(fontSize: 20, letterSpacing: -0.45, height: 1.4);
  static const title = _Scale(fontSize: 18, letterSpacing: -0.44, height: 1.56);
  static const body = _Scale(fontSize: 16, letterSpacing: -0.31, height: 1.5);
  static const label = _Scale(fontSize: 14, letterSpacing: -0.15, height: 1.43);
  static const caption = _Scale(fontSize: 12, height: 1.33);
}

class _Scale {
  final double fontSize;
  final double? letterSpacing;
  final double? height;

  const _Scale({
    required this.fontSize,
    this.letterSpacing,
    this.height,
  });

  TextStyle get bold => _build(FontWeight.bold);
  TextStyle get semibold => _build(FontWeight.w600);
  TextStyle get medium => _build(FontWeight.w500);
  TextStyle get regular => _build(FontWeight.w400);

  TextStyle _build(FontWeight weight) => TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: height,
      );
}
