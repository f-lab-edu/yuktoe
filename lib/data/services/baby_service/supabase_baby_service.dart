import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/domain/models/baby/baby_list_item.dart';

import 'baby_service.dart';

class SupabaseBabyService implements BabyService {
  final SupabaseClient _client;

  SupabaseBabyService({required SupabaseClient client}) : _client = client;

  @override
  Future<Result<List<BabyListItem>>> getMyBabies() async {
    try {
      final rows = await _client
          .from('babies')
          .select('id, name')
          .order('created_at', ascending: false);

      try {
        final items = rows
            .map((row) => _mapBabyListItem(row))
            .toList(growable: false);
        return Result.ok(items);
      } on Exception catch (e) {
        return Result.error(
          AppException(
            ErrorCode.parseFailed,
            'Failed to parse BabyListItem rows',
            cause: e,
          ),
        );
      }
    } on AuthException catch (e) {
      return Result.error(
        AppException(ErrorCode.unauthorized, e.message, cause: e),
      );
    } on PostgrestException catch (e) {
      return Result.error(
        AppException(ErrorCode.unknown, e.message, cause: e),
      );
    } on Exception catch (e) {
      return Result.error(
        AppException(ErrorCode.networkError, 'getMyBabies failed', cause: e),
      );
    }
  }

  @override
  Future<Result<Baby>> getBaby(String babyId) async {
    try {
      final row = await _client
          .from('babies')
          .select('id, name, birth_date, due_date, gender')
          .eq('id', babyId)
          .maybeSingle();

      if (row == null) {
        return Result.error(
          AppException(
            ErrorCode.notFound,
            'Baby not visible to current user',
          ),
        );
      }

      try {
        return Result.ok(_mapBaby(row));
      } on Exception catch (e) {
        return Result.error(
          AppException(
            ErrorCode.parseFailed,
            'Failed to parse Baby row',
            cause: e,
          ),
        );
      }
    } on AuthException catch (e) {
      return Result.error(
        AppException(ErrorCode.unauthorized, e.message, cause: e),
      );
    } on PostgrestException catch (e) {
      return Result.error(
        AppException(ErrorCode.unknown, e.message, cause: e),
      );
    } on Exception catch (e) {
      return Result.error(
        AppException(ErrorCode.networkError, 'getBaby failed', cause: e),
      );
    }
  }

  BabyListItem _mapBabyListItem(Map<String, dynamic> row) {
    return BabyListItem(
      id: row['id'] as String,
      name: row['name'] as String,
    );
  }

  Baby _mapBaby(Map<String, dynamic> row) {
    final birthDateRaw = row['birth_date'] as String?;
    final dueDateRaw = row['due_date'] as String?;
    return Baby(
      id: row['id'] as String,
      name: row['name'] as String,
      birthDate: birthDateRaw != null
          ? DateTime.parse(birthDateRaw).toUtc()
          : null,
      dueDate: dueDateRaw != null ? DateTime.parse(dueDateRaw).toUtc() : null,
      gender: Gender.values.firstWhere(
        (g) => g.serverValue == row['gender'],
      ),
    );
  }
}
