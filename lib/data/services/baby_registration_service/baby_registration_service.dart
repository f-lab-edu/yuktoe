import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/baby_registration/baby_preview.dart';

abstract interface class BabyRegistrationService {
  Future<Result<String>> createBaby({
    required String name,
    String? birthDate,
    String? dueDate,
    required String gender,
  });

  Future<Result<BabyPreview?>> verifyInviteCode(String code);

  Future<Result<String>> joinBabyByInviteCode({required String code});

  Future<Result<void>> setupUserProfile({
    required String babyId,
    required String relationship,
    required String nickname,
  });
}
