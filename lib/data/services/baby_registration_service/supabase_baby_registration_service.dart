import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/baby_registration/baby_preview.dart';

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
  }) async {
    try {
      final result = await _client.rpc(
        'create_baby',
        params: {
          'p_name': name,
          'p_birth_date': birthDate,
          'p_due_date': dueDate,
          'p_gender': gender,
        },
      );

      if (result == null) {
        return Result.error(
          AppException(ErrorCode.invalidResponse, 'create_baby returned null'),
        );
      }

      return Result.ok(result.toString());
    } on Exception catch (e) {
      return Result.error(
        AppException(ErrorCode.unknown, 'create_baby failed', cause: e),
      );
    }
  }

  @override
  Future<Result<BabyPreview?>> verifyInviteCode(String code) async {
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
        return Result.error(
          AppException(ErrorCode.invalidResponse, 'verify_invite_code returned unexpected type: ${result.runtimeType}'),
        );
      }

      try {
        return Result.ok(BabyPreview.fromJson(json));
      } on Exception catch (e) {
        return Result.error(
          AppException(ErrorCode.parseFailed, 'Failed to parse BabyPreview', cause: e),
        );
      }
    } on Exception catch (e) {
      return Result.error(
        AppException(ErrorCode.unknown, 'verify_invite_code failed', cause: e),
      );
    }
  }

  @override
  Future<Result<String>> joinBabyByInviteCode({required String code}) async {
    try {
      final result = await _client.rpc(
        'join_baby_by_invite_code',
        params: {'p_code': code},
      );

      if (result == null) {
        return Result.error(
          AppException(ErrorCode.invalidResponse, 'join_baby_by_invite_code returned null'),
        );
      }

      return Result.ok(result.toString());
    } on Exception catch (e) {
      return Result.error(
        AppException(ErrorCode.unknown, 'join_baby_by_invite_code failed', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> setupUserProfile({
    required String babyId,
    required String relationship,
    required String nickname,
  }) async {
    try {
      await _client.rpc(
        'setup_user_profile',
        params: {
          'p_baby_id': babyId,
          'p_relationship': relationship,
          'p_nickname': nickname,
        },
      );

      return Result.ok(null);
    } on Exception catch (e) {
      return Result.error(
        AppException(ErrorCode.unknown, 'setup_user_profile failed', cause: e),
      );
    }
  }
}
