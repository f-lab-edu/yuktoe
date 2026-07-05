import 'package:flutter/material.dart';
import 'package:yuktoe/constants/enum/record_type.dart';

/// 빠른 기록 버튼 / 입력 dialog 제목용 짧은 한국어 라벨 (spec §3.5 제목 열).
extension RecordTypeLabel on RecordType {
  String get shortLabel => switch (this) {
    RecordType.breast => '모유',
    RecordType.sleep => '수면',
    RecordType.formula => '분유',
    RecordType.pumpingFeed => '유축수유',
    RecordType.pumping => '유축',
    RecordType.babyFood => '이유식',
    RecordType.snack => '간식',
    RecordType.water => '물',
    RecordType.diaper => '기저귀',
  };

  /// 홈에서 탭 시 스탑워치 카드로 진입하는 타입(모유수유 / 수면).
  bool get isStopwatch => this == RecordType.breast || this == RecordType.sleep;

  /// 빠른 기록 버튼의 단색 라인(outlined) 아이콘 (Figma).
  IconData get lineIcon => switch (this) {
    RecordType.formula => Icons.local_drink_outlined,
    RecordType.breast => Icons.favorite_border,
    RecordType.diaper => Icons.baby_changing_station_outlined,
    RecordType.sleep => Icons.bedtime_outlined,
    RecordType.pumping => Icons.opacity_outlined,
    RecordType.pumpingFeed => Icons.local_cafe_outlined,
    RecordType.babyFood => Icons.restaurant_outlined,
    RecordType.snack => Icons.cookie_outlined,
    RecordType.water => Icons.water_drop_outlined,
  };
}
