import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/constants/enum/relationship.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';
import 'package:yuktoe/presentation/onboarding/view_models/baby_profile_setup_view_model.dart';

import 'baby_profile_setup_view_model_test.mocks.dart';

@GenerateMocks([BabyRegistrationRepository])
void main() {
  late MockBabyRegistrationRepository mockRepository;

  setUp(() {
    mockRepository = MockBabyRegistrationRepository();
  });

  BabyProfileSetupViewModel createViewModel({String babyId = 'test-baby-id'}) {
    return BabyProfileSetupViewModel(
      babyId: babyId,
      repository: mockRepository,
    );
  }

  group('initial state', () {
    test('starts with default values', () {
      final viewModel = createViewModel();

      expect(viewModel.relationship, isNull);
      expect(viewModel.nickname, '');
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(viewModel.isSuccess, isFalse);
      expect(viewModel.isValid, isFalse);
    });
  });

  group('setRelationship', () {
    test('updates relationship and notifies listeners', () {
      final viewModel = createViewModel();
      var notified = false;
      viewModel.addListener(() => notified = true);

      viewModel.setRelationship(Relationship.mother);

      expect(viewModel.relationship, Relationship.mother);
      expect(notified, isTrue);
    });
  });

  group('setNickname', () {
    test('updates nickname and notifies listeners', () {
      final viewModel = createViewModel();
      var notified = false;
      viewModel.addListener(() => notified = true);

      viewModel.setNickname('엄마');

      expect(viewModel.nickname, '엄마');
      expect(notified, isTrue);
    });

    test('ignores nickname exceeding max length', () {
      final viewModel = createViewModel();
      final longName = 'a' * (BabyProfileSetupViewModel.nicknameMaxLength + 1);

      viewModel.setNickname(longName);

      expect(viewModel.nickname, '');
    });

    test('accepts nickname at exactly max length', () {
      final viewModel = createViewModel();
      final maxName = 'a' * BabyProfileSetupViewModel.nicknameMaxLength;

      viewModel.setNickname(maxName);

      expect(viewModel.nickname, maxName);
    });
  });

  group('isValid', () {
    test('returns false when relationship is null', () {
      final viewModel = createViewModel();
      viewModel.setNickname('엄마');

      expect(viewModel.isValid, isFalse);
    });

    test('returns false when nickname is empty', () {
      final viewModel = createViewModel();
      viewModel.setRelationship(Relationship.mother);

      expect(viewModel.isValid, isFalse);
    });

    test('returns false when nickname is whitespace only', () {
      final viewModel = createViewModel();
      viewModel.setRelationship(Relationship.mother);
      viewModel.setNickname('   ');

      expect(viewModel.isValid, isFalse);
    });

    test('returns true when all required fields are set', () {
      final viewModel = createViewModel();
      viewModel.setRelationship(Relationship.mother);
      viewModel.setNickname('엄마');

      expect(viewModel.isValid, isTrue);
    });
  });

  group('submit', () {
    test('calls setupUserProfile and sets isSuccess on success', () async {
      final viewModel = createViewModel();
      viewModel.setRelationship(Relationship.mother);
      viewModel.setNickname('엄마');

      when(
        mockRepository.setupUserProfile(
          babyId: 'test-baby-id',
          relationship: 'mother',
          nickname: '엄마',
        ),
      ).thenAnswer((_) async {});

      await viewModel.submit();

      expect(viewModel.isSuccess, isTrue);
      expect(viewModel.error, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('sets error when setupUserProfile throws', () async {
      final viewModel = createViewModel();
      viewModel.setRelationship(Relationship.mother);
      viewModel.setNickname('엄마');

      when(
        mockRepository.setupUserProfile(
          babyId: 'test-baby-id',
          relationship: 'mother',
          nickname: '엄마',
        ),
      ).thenThrow(Exception('서버 오류'));

      await viewModel.submit();

      expect(viewModel.error, '오류가 발생했습니다.');
      expect(viewModel.isSuccess, isFalse);
      expect(viewModel.isLoading, isFalse);
    });

    test('notifies listeners with loading state changes', () async {
      final viewModel = createViewModel();
      viewModel.setRelationship(Relationship.mother);
      viewModel.setNickname('엄마');

      when(
        mockRepository.setupUserProfile(
          babyId: 'test-baby-id',
          relationship: 'mother',
          nickname: '엄마',
        ),
      ).thenAnswer((_) async {});

      final loadingStates = <bool>[];
      viewModel.addListener(() {
        loadingStates.add(viewModel.isLoading);
      });

      await viewModel.submit();

      expect(loadingStates, [true, false]);
    });

    test('isValid returns false while loading', () async {
      final viewModel = createViewModel();
      viewModel.setRelationship(Relationship.mother);
      viewModel.setNickname('엄마');
      expect(viewModel.isValid, isTrue);

      final completer = Completer<void>();
      when(
        mockRepository.setupUserProfile(
          babyId: 'test-baby-id',
          relationship: 'mother',
          nickname: '엄마',
        ),
      ).thenAnswer((_) => completer.future);

      final future = viewModel.submit();

      expect(viewModel.isLoading, isTrue);
      expect(viewModel.isValid, isFalse);

      completer.complete();
      await future;
    });
  });
}
