import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';
import 'package:yuktoe/domain/models/baby_registration/baby_preview.dart';
import 'package:yuktoe/presentation/onboarding/view_models/invite_code_view_model.dart';

import 'invite_code_view_model_test.mocks.dart';

@GenerateMocks([BabyRegistrationRepository])
void main() {
  late MockBabyRegistrationRepository mockRepository;
  late InviteCodeViewModel viewModel;

  setUp(() {
    mockRepository = MockBabyRegistrationRepository();
    viewModel = InviteCodeViewModel(repository: mockRepository);
  });

  group('initial state', () {
    test('starts with default values', () {
      expect(viewModel.code, '');
      expect(viewModel.agreedToTerms, isFalse);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(viewModel.verifiedBaby, isNull);
      expect(viewModel.isValid, isFalse);
    });
  });

  group('setCode', () {
    test('updates code and notifies listeners', () {
      var notified = false;
      viewModel.addListener(() => notified = true);

      viewModel.setCode('ABC-123');

      expect(viewModel.code, 'ABC-123');
      expect(notified, isTrue);
    });
  });

  group('toggleAgreedToTerms', () {
    test('toggles value and notifies listeners', () {
      final notifications = <bool>[];
      viewModel.addListener(() {
        notifications.add(viewModel.agreedToTerms);
      });

      viewModel.toggleAgreedToTerms();
      viewModel.toggleAgreedToTerms();

      expect(notifications, [true, false]);
    });
  });

  group('isValid', () {
    test('returns false when code is empty', () {
      viewModel.toggleAgreedToTerms();

      expect(viewModel.isValid, isFalse);
    });

    test('returns false when code is whitespace only', () {
      viewModel.setCode('   ');
      viewModel.toggleAgreedToTerms();

      expect(viewModel.isValid, isFalse);
    });

    test('returns false when terms not agreed', () {
      viewModel.setCode('ABC-123');

      expect(viewModel.isValid, isFalse);
    });

    test('returns true when code is set and terms agreed', () {
      viewModel.setCode('ABC-123');
      viewModel.toggleAgreedToTerms();

      expect(viewModel.isValid, isTrue);
    });
  });

  group('verifyInviteCode', () {
    test('sets verifiedBaby when repository returns data', () async {
      // given
      final baby = BabyPreview(
        maskedName: '김*수',
        birthYear: 2025,
        gender: Gender.male,
      );
      viewModel.setCode('ABC-123');
      when(mockRepository.verifyInviteCode('ABC-123'))
          .thenAnswer((_) async => baby);

      // when
      await viewModel.verifyInviteCode();

      // then
      expect(viewModel.verifiedBaby, same(baby));
      expect(viewModel.error, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('sets verifiedBaby to null when repository returns null', () async {
      // given
      viewModel.setCode('INVALID');
      when(mockRepository.verifyInviteCode('INVALID'))
          .thenAnswer((_) async => null);

      // when
      await viewModel.verifyInviteCode();

      // then
      expect(viewModel.verifiedBaby, isNull);
      expect(viewModel.error, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('sets error when repository throws', () async {
      // given
      viewModel.setCode('ABC-123');
      when(mockRepository.verifyInviteCode('ABC-123'))
          .thenThrow(Exception('서버 오류'));

      // when
      await viewModel.verifyInviteCode();

      // then
      expect(viewModel.error, '초대 코드 확인 중 오류가 발생했습니다.');
      expect(viewModel.verifiedBaby, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('notifies listeners with loading state changes', () async {
      // given
      viewModel.setCode('ABC-123');
      when(mockRepository.verifyInviteCode('ABC-123'))
          .thenAnswer((_) async => null);

      final loadingStates = <bool>[];
      viewModel.addListener(() {
        loadingStates.add(viewModel.isLoading);
      });

      // when
      await viewModel.verifyInviteCode();

      // then - loading true -> loading false
      expect(loadingStates, [true, false]);
    });

    test('isValid returns false while loading', () async {
      // given
      viewModel.setCode('ABC-123');
      viewModel.toggleAgreedToTerms();
      expect(viewModel.isValid, isTrue);

      final completer = Completer<BabyPreview?>();
      when(mockRepository.verifyInviteCode('ABC-123'))
          .thenAnswer((_) => completer.future);

      // when
      final future = viewModel.verifyInviteCode();

      // then
      expect(viewModel.isLoading, isTrue);
      expect(viewModel.isValid, isFalse);

      completer.complete(null);
      await future;
    });

    test('clears previous error and verifiedBaby on new call', () async {
      // given - first call fails
      viewModel.setCode('BAD');
      when(mockRepository.verifyInviteCode('BAD'))
          .thenThrow(Exception('오류'));
      await viewModel.verifyInviteCode();
      expect(viewModel.error, isNotNull);

      // given - second call succeeds
      final baby = BabyPreview(
        maskedName: '이*연',
        birthYear: 2025,
        gender: Gender.female,
      );
      viewModel.setCode('GOOD');
      when(mockRepository.verifyInviteCode('GOOD'))
          .thenAnswer((_) async => baby);

      // when
      await viewModel.verifyInviteCode();

      // then
      expect(viewModel.error, isNull);
      expect(viewModel.verifiedBaby, same(baby));
    });
  });

  group('clearVerifiedBaby', () {
    test('clears verifiedBaby and error, notifies listeners', () async {
      // given
      final baby = BabyPreview(
        maskedName: '김*수',
        birthYear: 2025,
        gender: Gender.male,
      );
      viewModel.setCode('ABC-123');
      when(mockRepository.verifyInviteCode('ABC-123'))
          .thenAnswer((_) async => baby);
      await viewModel.verifyInviteCode();
      expect(viewModel.verifiedBaby, isNotNull);

      var notified = false;
      viewModel.addListener(() => notified = true);

      // when
      viewModel.clearVerifiedBaby();

      // then
      expect(viewModel.verifiedBaby, isNull);
      expect(viewModel.error, isNull);
      expect(notified, isTrue);
    });
  });
}
