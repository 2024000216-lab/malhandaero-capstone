import 'package:flutter/material.dart';

import 'services/app_settings.dart';

/// 와이어프레임 3차 색상 — 흰 배경 대비가 충분한 진한 색 위주
class AppColors {
  static const primary = Color(0xFF2B4ACB);
  static const primaryShadow = Color(0xFF1E3594);
  static const text = Color(0xFF1C1C1C);
  static const sub = Color(0xFF45453F);
  static const border = Color(0xFF6B6B66);
  static const lightBorder = Color(0xFFC9C9C4);
  static const divider = Color(0xFFDADAD6);
  static const surface = Color(0xFFF4F4F1);
  static const danger = Color(0xFFB23A0A);
  static const dangerBg = Color(0xFFFBEDE6);
  static const warnBg = Color(0xFFFFF6F1);
  static const success = Color(0xFF1F7A45);
  static const disabledBg = Color(0xFFECECE8);
  static const disabledFg = Color(0xFF5A5A55);

  // 확인 화면 하이라이트 (색 + 글자 이름표 + 밑줄을 함께 사용)
  static const dateBg = Color(0xFFE3E8FA);
  static const dateFg = Color(0xFF2B4ACB);
  static const timeBg = Color(0xFFEDE4F7);
  static const timeFg = Color(0xFF6A3D9A);
  static const placeBg = Color(0xFFDDF0E4);
  static const placeFg = Color(0xFF1F7A45);
  static const titleBg = Color(0xFFFBEFD0);
  static const titleFg = Color(0xFF7A5000);

  // 와이어프레임 5차 — 색약 모드 / 크게 보기 모드
  static const primaryColorBlind = Color(0xFF1F4FD1);
  static const ink = Color(0xFF111111);
  static const grayBg = Color(0xFFF2F1ED);
  static const iconBg = Color(0xFFE8ECFB);

  /// 색약 모드 여부에 맞는 주요 색
  static Color primaryOf(BuildContext context) =>
      SettingsScope.of(context).colorBlind ? primaryColorBlind : primary;
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    dividerColor: AppColors.divider,
  );
}
