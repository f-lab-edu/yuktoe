import 'package:yuktoe/domain/models/baby_registration/baby_summary.dart';

abstract interface class BabyRegistrationRepository {
  Future<String> createBaby({
    required String name,
    String? birthDate,
    String? dueDate,
    required String gender,
    required String relationship,
    required String nickname,
  });

  Future<BabySummary?> verifyInviteCode(String code);

  Future<String> joinBabyByInviteCode({
    required String code,
    required String relationship,
    required String nickname,
  });
}
