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
    provideDummy<Result<void>>(Result.ok(null));
  });

  setUp(() {
    mockService = MockBabyRegistrationService();
    repository = BabyRegistrationRepositoryImpl(mockService);
  });

  group('createBaby', () {
    const name = '아기';
    const birthDate = '2025-01-01';
    const gender = 'male';

    test('returns babyId when service returns Ok', () async {
      when(mockService.createBaby(
        name: name,
        birthDate: birthDate,
        dueDate: null,
        gender: gender,
      )).thenAnswer((_) async => Result.ok('baby-123'));

      final result = await repository.createBaby(
        name: name,
        birthDate: birthDate,
        gender: gender,
      );

      expect(result, 'baby-123');
    });

    test('throws when service returns Error', () async {
      final exception = AppException(ErrorCode.unknown, 'create failed');
      when(mockService.createBaby(
        name: name,
        birthDate: birthDate,
        dueDate: null,
        gender: gender,
      )).thenAnswer((_) async => Result.error(exception));

      expect(
        () => repository.createBaby(
          name: name,
          birthDate: birthDate,
          gender: gender,
        ),
        throwsA(same(exception)),
      );
    });
  });

  group('verifyInviteCode', () {
    const code = 'ABC-123';

    test('returns BabyPreview when service returns Ok with data', () async {
      final baby = BabyPreview(
        maskedName: '김*수',
        birthYear: 2025,
        gender: Gender.male,
      );
      when(mockService.verifyInviteCode(code))
          .thenAnswer((_) async => Result.ok(baby));

      final result = await repository.verifyInviteCode(code);

      expect(result, same(baby));
    });

    test('returns null when service returns Ok(null)', () async {
      when(mockService.verifyInviteCode(code))
          .thenAnswer((_) async => Result.ok(null));

      final result = await repository.verifyInviteCode(code);

      expect(result, isNull);
    });

    test('throws when service returns Error', () async {
      final exception = AppException(ErrorCode.unknown, 'verify failed');
      when(mockService.verifyInviteCode(code))
          .thenAnswer((_) async => Result.error(exception));

      expect(
        () => repository.verifyInviteCode(code),
        throwsA(same(exception)),
      );
    });
  });

  group('joinBabyByInviteCode', () {
    const code = 'ABC-123';

    test('returns babyId when service returns Ok', () async {
      when(mockService.joinBabyByInviteCode(code: code))
          .thenAnswer((_) async => Result.ok('baby-456'));

      final result = await repository.joinBabyByInviteCode(code: code);

      expect(result, 'baby-456');
    });

    test('throws when service returns Error', () async {
      final exception = AppException(ErrorCode.unknown, 'join failed');
      when(mockService.joinBabyByInviteCode(code: code))
          .thenAnswer((_) async => Result.error(exception));

      expect(
        () => repository.joinBabyByInviteCode(code: code),
        throwsA(same(exception)),
      );
    });
  });

  group('setupUserProfile', () {
    const babyId = 'baby-123';
    const relationship = 'mother';
    const nickname = '엄마';

    test('completes when service returns Ok', () async {
      when(mockService.setupUserProfile(
        babyId: babyId,
        relationship: relationship,
        nickname: nickname,
      )).thenAnswer((_) async => Result.ok(null));

      await repository.setupUserProfile(
        babyId: babyId,
        relationship: relationship,
        nickname: nickname,
      );

      verify(mockService.setupUserProfile(
        babyId: babyId,
        relationship: relationship,
        nickname: nickname,
      )).called(1);
    });

    test('throws when service returns Error', () async {
      final exception = AppException(ErrorCode.unknown, 'setup failed');
      when(mockService.setupUserProfile(
        babyId: babyId,
        relationship: relationship,
        nickname: nickname,
      )).thenAnswer((_) async => Result.error(exception));

      expect(
        () => repository.setupUserProfile(
          babyId: babyId,
          relationship: relationship,
          nickname: nickname,
        ),
        throwsA(same(exception)),
      );
    });
  });
}
