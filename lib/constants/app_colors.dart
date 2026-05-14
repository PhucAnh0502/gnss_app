import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ===== BACKGROUND COLORS =====
  static const primaryDark = Color(0xFF0A0F1E);
  static const bgMainGradientEnd = Color(0xFF020810);
  static const bgSidebar = Color(0xFF0F1629);
  static const bgInput = Color(0xFF131B2E);
  static const bgCard = Color(0xFF141D30);
  static const bgElevated = Color(0xFF1C2940);
  static const bgHover = Color(0xFF243352);

  // ===== TEXT COLORS =====
  static const textLight = Color(0xFFF1F5F9);
  static const textDim = Color(0xFFCBD5E1);
  static const textMuted = Color(0xFF94A3B8);

  // ===== PRIMARY BRAND COLORS =====
  static const brandBlue = Color(0xFF3B82F6);
  static const brandBlueLight = Color(0xFF60A5FA);
  static const brandBlueDark = Color(0xFF1E40AF);
  static const brandBlueHover = Color(0xFF2563EB);

  // ===== SEMANTIC COLORS =====
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFF6EE7B7);
  static const successDark = Color(0xFF047857);

  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFBBF24);
  static const warningDark = Color(0xFFB45309);

  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFFCA5A5);
  static const errorDark = Color(0xFFDC2626);

  static const info = Color(0xFF0EA5E9);
  static const infoLight = Color(0xFF38BDF8);
  static const infoDark = Color(0xFF0369A1);

  // ===== ACCENT COLORS =====
  static const purple = Color(0xFF8B5CF6);
  static const purpleLight = Color(0xFFA78BFA);
  static const purpleDark = Color(0xFF6D28D9);

  static const cyan = Color(0xFF06B6D4);
  static const cyanLight = Color(0xFF22D3EE);
  static const cyanDark = Color(0xFF0891B2);

  // ===== NEUTRAL GRAYS =====
  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate50 = Color(0xFFF8FAFC);

  // ===== STATUS INDICATORS =====
  static const statusActive = success;
  static const statusInactive = slate500;
  static const statusMaintenance = warning;

  // ===== UTILITY =====
  static const transparent = Color(0x00000000);
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);

  // ===== GRADIENTS =====
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandBlue, Color(0xFF22D3EE)],
  );

  static const darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryDark, bgMainGradientEnd],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F1D39), Color(0xFF081120)],
  );
}
