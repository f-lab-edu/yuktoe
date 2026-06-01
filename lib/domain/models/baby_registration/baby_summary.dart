import 'package:yuktoe/constants/enum/gender.dart';

class BabySummary {
  final String babyId;
  final String name;
  final DateTime? birthDate;
  final DateTime? dueDate;
  final Gender gender;

  const BabySummary({
    required this.babyId,
    required this.name,
    this.birthDate,
    this.dueDate,
    required this.gender,
  });

  factory BabySummary.fromJson(Map<String, dynamic> json) {
    return BabySummary(
      babyId: json['baby_id'] as String,
      name: json['baby_name'] as String,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      gender: Gender.values.firstWhere((g) => g.serverValue == json['gender']),
    );
  }
}
