import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';
import 'package:yuktoe/domain/models/baby_registration/baby_summary.dart';

class BabyRegistrationRepositoryImpl implements BabyRegistrationRepository {
  final SupabaseClient _client;

  BabyRegistrationRepositoryImpl({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  @override
  Future<String> createBaby({
    required String name,
    String? birthDate,
    String? dueDate,
    required String gender,
    required String relationship,
    required String nickname,
  }) async {
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
      throw Exception('아기 생성 결과를 받지 못했습니다.');
    }

    return result.toString();
  }

  @override
  Future<BabySummary?> verifyInviteCode(String code) async {
    final result = await _client.rpc(
      'verify_invite_code',
      params: {'p_code': code},
    );

    if (result == null) return null;

    if (result is Map<String, dynamic>) {
      return BabySummary.fromJson(result);
    }

    if (result is List && result.isNotEmpty) {
      final first = result.first;
      if (first is Map<String, dynamic>) {
        return BabySummary.fromJson(first);
      }
      if (first is Map) {
        return BabySummary.fromJson(Map<String, dynamic>.from(first));
      }
    }

    if (result is Map) {
      return BabySummary.fromJson(Map<String, dynamic>.from(result));
    }

    throw Exception('초대코드 검증 응답 형식이 올바르지 않습니다.');
  }

  @override
  Future<String> joinBabyByInviteCode({
    required String code,
    required String relationship,
    required String nickname,
  }) async {
    final result = await _client.rpc(
      'join_baby_by_invite_code',
      params: {
        'p_code': code,
        'p_relationship': relationship,
        'p_nickname': nickname,
      },
    );

    if (result == null) {
      throw Exception('아기 참여 결과를 받지 못했습니다.');
    }

    return result.toString();
  }
}
