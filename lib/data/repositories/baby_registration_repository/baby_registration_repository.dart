import 'package:yuktoe/domain/models/baby_registration/baby_preview.dart';

abstract interface class BabyRegistrationRepository {
  Future<String> createBaby({
    required String name,
    String? birthDate,
    String? dueDate,
    required String gender,
  });

  Future<BabyPreview?> verifyInviteCode(String code);

  Future<void> joinBaby({required String babyId});

  Future<void> setupUserProfile({
    required String babyId,
    required String relationship,
    required String nickname,
  });
}
