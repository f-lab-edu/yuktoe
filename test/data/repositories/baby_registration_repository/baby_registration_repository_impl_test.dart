import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/core/error/app_exception.dart';
import 'package:yuktoe/core/result.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository_impl.dart';
import 'package:yuktoe/data/services/baby_registration_service/baby_registration_service.dart';
import 'package:yuktoe/domain/models/baby_registration/baby_preview.dart';

import 'baby_registration_repository_impl_test.mocks.dart';

@GenerateMocks([BabyRegistrationService])
void main() {
  late MockBabyRegistrationService mockService;
  late BabyRegistrationRepositoryImpl repository;

  setUpAll(() {
    provideDummy<Result<String>>(Result.ok(''));
    provideDummy<Result<BabyPreview?>>(Result.ok(null));
  });

  setUp(() {
    mockService = MockBabyRegistrationService();
    repository = BabyRegistrationRepositoryImpl(mockService);
  });

  group('createBaby', () {
    const name = '아기';
    const birthDate = '2025-01-01';
    const gender = 'male';
    const relationship = 'mom';
    const nickname = '엄마';

    test('returns babyId when service returns Ok', () async {
      // given
      when(mockService.createBaby(
        name: name,
        birthDate: birthDate,
        dueDate: null,
        gender: gender,
        relationship: relationship,
        nickname: nickname,
      )).thenAnswer((_) async => Result.ok('baby-123'));

      // when
      final result = await repository.createBaby(
        name: name,
        birthDate: birthDate,
        gender: gender,
        relationship: relationship,
        nickname: nickname,
      );

      // then
      expect(result, 'baby-123');
    });

    test('throws when service returns Error', () async {
      // given
      final exception = AppException(ErrorCode.unknown, 'create failed');
      when(mockService.createBaby(
        name: name,
        birthDate: birthDate,
        dueDate: null,
        gender: gender,
        relationship: relationship,
        nickname: nickname,
      )).thenAnswer((_) async => Result.error(exception));

      // when & then
      expect(
        () => repository.createBaby(
          name: name,
          birthDate: birthDate,
          gender: gender,
          relationship: relationship,
          nickname: nickname,
        ),
        throwsA(same(exception)),
      );
    });
  });

  group('verifyInviteCode', () {
    const code = 'ABC-123';

    test('returns BabyPreview when service returns Ok with data', () async {
      // given
      final baby = BabyPreview(
        maskedName: '김*수',
        birthYear: 2025,
        gender: Gender.male,
      );
      when(mockService.verifyInviteCode(code))
          .thenAnswer((_) async => Result.ok(baby));

      // when
      final result = await repository.verifyInviteCode(code);

      // then
      expect(result, same(baby));
    });

    test('returns null when service returns Ok(null)', () async {
      // given
      when(mockService.verifyInviteCode(code))
          .thenAnswer((_) async => Result.ok(null));

      // when
      final result = await repository.verifyInviteCode(code);

      // then
      expect(result, isNull);
    });

    test('throws when service returns Error', () async {
      // given
      final exception = AppException(ErrorCode.unknown, 'verify failed');
      when(mockService.verifyInviteCode(code))
          .thenAnswer((_) async => Result.error(exception));

      // when & then
      expect(
        () => repository.verifyInviteCode(code),
        throwsA(same(exception)),
      );
    });
  });

  group('joinBabyByInviteCode', () {
    const code = 'ABC-123';
    const relationship = 'dad';
    const nickname = '아빠';

    test('returns babyId when service returns Ok', () async {
      // given
      when(mockService.joinBabyByInviteCode(
        code: code,
        relationship: relationship,
        nickname: nickname,
      )).thenAnswer((_) async => Result.ok('baby-456'));

      // when
      final result = await repository.joinBabyByInviteCode(
        code: code,
        relationship: relationship,
        nickname: nickname,
      );

      // then
      expect(result, 'baby-456');
    });

    test('throws when service returns Error', () async {
      // given
      final exception = AppException(ErrorCode.unknown, 'join failed');
      when(mockService.joinBabyByInviteCode(
        code: code,
        relationship: relationship,
        nickname: nickname,
      )).thenAnswer((_) async => Result.error(exception));

      // when & then
      expect(
        () => repository.joinBabyByInviteCode(
          code: code,
          relationship: relationship,
          nickname: nickname,
        ),
        throwsA(same(exception)),
      );
    });
  });
}
