import 'package:flutter/material.dart';
import 'package:yuktoe/presentation/home/models/quick_log_kind.dart';

/// 빠른 기록 버튼 / 입력 dialog 제목용 짧은 한국어 라벨 (spec §3.5 제목 열).
extension QuickLogKindLabel on QuickLogKind {
  String get shortLabel => switch (this) {
    QuickLogKind.breast => '모유',
    QuickLogKind.sleep => '수면',
    QuickLogKind.formula => '분유',
    QuickLogKind.pumpingFeed => '유축수유',
    QuickLogKind.pumping => '유축',
    QuickLogKind.babyFood => '이유식',
    QuickLogKind.snack => '간식',
    QuickLogKind.water => '물',
    QuickLogKind.diaper => '기저귀',
  };

  /// 홈에서 탭 시 스탑워치 카드로 진입하는 종류(모유수유 / 수면).
  bool get isStopwatch =>
      this == QuickLogKind.breast || this == QuickLogKind.sleep;

  /// 빠른 기록 버튼의 단색 라인(outlined) 아이콘 (Figma).
  IconData get lineIcon => switch (this) {
    QuickLogKind.formula => Icons.local_drink_outlined,
    QuickLogKind.breast => Icons.favorite_border,
    QuickLogKind.diaper => Icons.baby_changing_station_outlined,
    QuickLogKind.sleep => Icons.bedtime_outlined,
    QuickLogKind.pumping => Icons.opacity_outlined,
    QuickLogKind.pumpingFeed => Icons.local_cafe_outlined,
    QuickLogKind.babyFood => Icons.restaurant_outlined,
    QuickLogKind.snack => Icons.cookie_outlined,
    QuickLogKind.water => Icons.water_drop_outlined,
  };
}
