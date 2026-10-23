import 'package:flutter/material.dart';

/// Палитра приложения в фирменных цветах SNP: графит + жёлтый.
/// Все цвета заданы константами — достаточно поменять значения здесь.
class AppColors {
  AppColors._();

  /// Графит: заголовки, тёмные кнопки, выбранные состояния.
  static const Color primary = Color(0xFF14181D);
  static const Color primaryLight = Color(0xFF2B323B);

  /// Фирменный жёлтый SNP.
  static const Color accent = Color(0xFFFECE42);
  static const Color accentDark = Color(0xFFF2B705);
  static const Color accentSoft = Color(0xFFFFF6D6);

  /// Цвет текста и иконок поверх жёлтого.
  static const Color onAccent = Color(0xFF14181D);

  static const Color background = Color(0xFFF5F5F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFEFEFEA);
  static const Color border = Color(0xFFE3E3DC);
  static const Color divider = Color(0xFFECECE6);

  static const Color textPrimary = Color(0xFF14181D);
  static const Color textSecondary = Color(0xFF5E6470);
  static const Color textHint = Color(0xFF9EA3AD);

  static const Color success = Color(0xFF1E8E5A);
  static const Color successSoft = Color(0xFFE4F5EC);
  static const Color warning = Color(0xFFA86A00);
  static const Color warningSoft = Color(0xFFFFF4DB);
  static const Color danger = Color(0xFFD64545);
  static const Color dangerSoft = Color(0xFFFDEBEB);
  static const Color info = Color(0xFF2F6FDE);
  static const Color infoSoft = Color(0xFFE8F0FD);

  static const Color shadow = Color(0x1414181D);
  static const Color scrim = Color(0x8014181D);
  static const Color skeletonA = Color(0xFFE8E8E2);
  static const Color skeletonB = Color(0xFFF4F4F0);
}
