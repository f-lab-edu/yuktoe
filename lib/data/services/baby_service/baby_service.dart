import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/domain/models/baby/baby_list_item.dart';

abstract interface class BabyService {
  Future<Result<List<BabyListItem>>> getMyBabies();
  Future<Result<Baby>> getBaby(String babyId);
}
