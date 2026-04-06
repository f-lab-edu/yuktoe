import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/baby_registration/baby_summary.dart';

import 'baby_registration_service.dart';

class SupabaseBabyRegistrationService implements BabyRegistrationService {
  final SupabaseClient _client;

  SupabaseBabyRegistrationService({required SupabaseClient client})
    : _client = client;

  @override
  Future<Result<String>> createBaby({
    required String name,
    String? birthDate,
    String? dueDate,
    required String gender,
    required String relationship,
    required String nickname,
  }) async {
    try {
      final result = await _client.rpc(
        'create_baby_with_owner',
        params: {
          'p_name': name,
          'p_birth_date': birthDate,
          'p_due_date': dueDate,
          'p_gender': gender,
          'p_relationship': relationship,
          'p_nickname': nickname,
        },
      );

      if (result == null) {
        return Result.error(AppException('아기 생성 결과를 받지 못했습니다.'));
      }

      return Result.ok(result.toString());
    } on Exception catch (e) {
      return Result.error(AppException('아기 생성에 실패했습니다.', cause: e));
    }
  }

  @override
  Future<Result<BabySummary?>> verifyInviteCode(String code) async {
    try {
      final result = await _client.rpc(
        'verify_invite_code',
        params: {'p_code': code},
      );

      if (result == null) return Result.ok(null);

      final Map<String, dynamic> json;
      if (result is Map<String, dynamic>) {
        json = result;
      } else {
        return Result.error(AppException('초대코드 검증 응답 형식이 올바르지 않습니다.'));
      }

      try {
        return Result.ok(BabySummary.fromJson(json));
      } on Exception catch (e) {
        return Result.error(AppException('초대코드 검증 응답 파싱에 실패했습니다.', cause: e));
      }
    } on Exception catch (e) {
      return Result.error(AppException('초대코드 검증에 실패했습니다.', cause: e));
    }
  }

  @override
  Future<Result<String>> joinBabyByInviteCode({
    required String code,
    required String relationship,
    required String nickname,
  }) async {
    try {
      final result = await _client.rpc(
        'join_baby_by_invite_code',
        params: {
          'p_code': code,
          'p_relationship': relationship,
          'p_nickname': nickname,
        },
      );

      if (result == null) {
        return Result.error(AppException('아기 참여 결과를 받지 못했습니다.'));
      }

      return Result.ok(result.toString());
    } on Exception catch (e) {
      return Result.error(AppException('아기 참여에 실패했습니다.', cause: e));
    }
  }
}
