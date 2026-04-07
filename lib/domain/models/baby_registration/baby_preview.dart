import 'package:yuktoe/constants/enum/gender.dart';

class BabyPreview {
  final String maskedName;
  final int birthYear;
  final Gender gender;

  const BabyPreview({
    required this.maskedName,
    required this.birthYear,
    required this.gender,
  });

  factory BabyPreview.fromJson(Map<String, dynamic> json) {
    return BabyPreview(
      maskedName: json['baby_name'] as String,
      birthYear: json['birth_year'] as int,
      gender: Gender.values.firstWhere((g) => g.serverValue == json['gender']),
    );
  }
}
