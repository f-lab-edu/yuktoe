import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';
import 'package:yuktoe/data/services/baby_registration_service/baby_registration_service.dart';
import 'package:yuktoe/domain/models/baby_registration/baby_preview.dart';

class BabyRegistrationRepositoryImpl implements BabyRegistrationRepository {
  final BabyRegistrationService _service;

  BabyRegistrationRepositoryImpl(this._service);

  @override
  Future<String> createBaby({
    required String name,
    String? birthDate,
    String? dueDate,
    required String gender,
    required String relationship,
    required String nickname,
  }) async {
    final result = await _service.createBaby(
      name: name,
      birthDate: birthDate,
      dueDate: dueDate,
      gender: gender,
      relationship: relationship,
      nickname: nickname,
    );

    switch (result) {
      case Ok<String>():
        return result.value;
      case Error<String>():
        throw result.error;
    }
  }

  @override
  Future<BabyPreview?> verifyInviteCode(String code) async {
    final result = await _service.verifyInviteCode(code);

    switch (result) {
      case Ok<BabyPreview?>():
        return result.value;
      case Error<BabyPreview?>():
        throw result.error;
    }
  }

  @override
  Future<String> joinBabyByInviteCode({
    required String code,
    required String relationship,
    required String nickname,
  }) async {
    final result = await _service.joinBabyByInviteCode(
      code: code,
      relationship: relationship,
      nickname: nickname,
    );

    switch (result) {
      case Ok<String>():
        return result.value;
      case Error<String>():
        throw result.error;
    }
  }
}
