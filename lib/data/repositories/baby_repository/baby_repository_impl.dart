import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository.dart';
import 'package:yuktoe/data/services/baby_service/baby_service.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/domain/models/baby/baby_list_item.dart';

class BabyRepositoryImpl implements BabyRepository {
  final BabyService _service;

  BabyRepositoryImpl(this._service);

  @override
  Future<Result<List<BabyListItem>>> getMyBabies() async {
    final result = await _service.getMyBabies();
    switch (result) {
      case Ok<List<BabyListItem>>():
        if (result.value.isEmpty) {
          return Result.error(
            AppException(
              ErrorCode.notFound,
              'No babies available for current user',
            ),
          );
        }
        return Result.ok(result.value);
      case Error<List<BabyListItem>>():
        return Result.error(result.error);
    }
  }

  @override
  Future<Result<Baby>> getBaby(String babyId) async {
    final result = await _service.getBaby(babyId);
    switch (result) {
      case Ok<Baby>():
        return Result.ok(result.value);
      case Error<Baby>():
        return Result.error(result.error);
    }
  }
}
