import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository_impl.dart';
import 'package:yuktoe/data/services/baby_service/baby_service.dart';
import 'package:yuktoe/domain/models/baby/baby.dart';
import 'package:yuktoe/domain/models/baby/baby_list_item.dart';

import 'baby_repository_impl_test.mocks.dart';

@GenerateMocks([BabyService])
void main() {
  late MockBabyService mockService;
  late BabyRepositoryImpl repository;

  setUpAll(() {
    provideDummy<Result<List<BabyListItem>>>(
      Result.ok(const <BabyListItem>[]),
    );
    provideDummy<Result<Baby>>(
      Result.ok(Baby(id: 'dummy', name: 'dummy', gender: Gender.male)),
    );
  });

  setUp(() {
    mockService = MockBabyService();
    repository = BabyRepositoryImpl(mockService);
  });

  group('getMyBabies', () {
    test('passes through non-empty list', () async {
      final items = [
        BabyListItem(id: 'a', name: 'A'),
        BabyListItem(id: 'b', name: 'B'),
      ];
      when(mockService.getMyBabies())
          .thenAnswer((_) async => Result.ok(items));

      final result = await repository.getMyBabies();

      expect(result, isA<Ok<List<BabyListItem>>>());
      expect((result as Ok<List<BabyListItem>>).value, same(items));
    });

    test('converts empty list to notFound', () async {
      when(mockService.getMyBabies())
          .thenAnswer((_) async => Result.ok(const []));

      final result = await repository.getMyBabies();

      expect(result, isA<Error<List<BabyListItem>>>());
      expect(
        (result as Error<List<BabyListItem>>).error.code,
        ErrorCode.notFound,
      );
    });

    test('passes through service error', () async {
      final exception = AppException(ErrorCode.networkError, 'offline');
      when(mockService.getMyBabies())
          .thenAnswer((_) async => Result.error(exception));

      final result = await repository.getMyBabies();

      expect(result, isA<Error<List<BabyListItem>>>());
      expect((result as Error<List<BabyListItem>>).error, same(exception));
    });
  });

  group('getBaby', () {
    test('passes through Baby on success', () async {
      final baby = Baby(id: 'a', name: 'A', gender: Gender.male);
      when(mockService.getBaby('a'))
          .thenAnswer((_) async => Result.ok(baby));

      final result = await repository.getBaby('a');

      expect(result, isA<Ok<Baby>>());
      expect((result as Ok<Baby>).value, same(baby));
    });

    test('passes through notFound', () async {
      final exception = AppException(ErrorCode.notFound, 'missing');
      when(mockService.getBaby('a'))
          .thenAnswer((_) async => Result.error(exception));

      final result = await repository.getBaby('a');

      expect(result, isA<Error<Baby>>());
      expect((result as Error<Baby>).error, same(exception));
    });

    test('passes through unauthorized', () async {
      final exception = AppException(ErrorCode.unauthorized, 'auth');
      when(mockService.getBaby('a'))
          .thenAnswer((_) async => Result.error(exception));

      final result = await repository.getBaby('a');

      expect(result, isA<Error<Baby>>());
      expect((result as Error<Baby>).error, same(exception));
    });
  });
}
