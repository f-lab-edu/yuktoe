import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/constants/enum/relationship.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';
import 'package:yuktoe/domain/models/baby_registration/onboarding_flow.dart';
import 'package:yuktoe/presentation/onboarding/view_models/baby_profile_setup_view_model.dart';

import 'baby_profile_setup_view_model_test.mocks.dart';

@GenerateMocks([BabyRegistrationRepository])
void main() {
  late MockBabyRegistrationRepository mockRepository;

  setUp(() {
    mockRepository = MockBabyRegistrationRepository();
  });

  BabyProfileSetupViewModel createViewModel({OnboardingFlow? flow}) {
    return BabyProfileSetupViewModel(
      flow: flow ??
          CreateBabyFlow(
            name: '아기',
            gender: Gender.male,
            birthDate: DateTime(2025, 1, 1),
          ),
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
      expect(viewModel.isValid, isFalse);
    });
  });

  group('setRelationship', () {
    test('updates relationship and notifies listeners', () {
      final viewModel = createViewModel();
      var notified = false;
      viewModel.addListener(() => notified = true);

      viewModel.setRelationship(Relationship.mom);

      expect(viewModel.relationship, Relationship.mom);
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
      viewModel.setRelationship(Relationship.mom);

      expect(viewModel.isValid, isFalse);
    });

    test('returns false when nickname is whitespace only', () {
      final viewModel = createViewModel();
      viewModel.setRelationship(Relationship.mom);
      viewModel.setNickname('   ');

      expect(viewModel.isValid, isFalse);
    });

    test('returns true when all required fields are set', () {
      final viewModel = createViewModel();
      viewModel.setRelationship(Relationship.mom);
      viewModel.setNickname('엄마');

      expect(viewModel.isValid, isTrue);
    });
  });

  group('submit with CreateBabyFlow', () {
    test('calls createBaby and returns babyId on success', () async {
      // given
      final flow = CreateBabyFlow(
        name: '아기',
        gender: Gender.male,
        birthDate: DateTime(2025, 1, 15),
        dueDate: DateTime(2025, 2, 1),
      );
      final viewModel = createViewModel(flow: flow);
      viewModel.setRelationship(Relationship.mom);
      viewModel.setNickname('엄마');

      when(mockRepository.createBaby(
        name: '아기',
        birthDate: '2025-01-15',
        dueDate: '2025-02-01',
        gender: 'male',
        relationship: 'mom',
        nickname: '엄마',
      )).thenAnswer((_) async => 'baby-123');

      // when
      final result = await viewModel.submit();

      // then
      expect(result, 'baby-123');
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
    });

    test('calls createBaby with null dueDate when not provided', () async {
      // given
      final flow = CreateBabyFlow(
        name: '아기',
        gender: Gender.female,
        birthDate: DateTime(2025, 3, 1),
      );
      final viewModel = createViewModel(flow: flow);
      viewModel.setRelationship(Relationship.dad);
      viewModel.setNickname('아빠');

      when(mockRepository.createBaby(
        name: '아기',
        birthDate: '2025-03-01',
        dueDate: null,
        gender: 'female',
        relationship: 'dad',
        nickname: '아빠',
      )).thenAnswer((_) async => 'baby-456');

      // when
      final result = await viewModel.submit();

      // then
      expect(result, 'baby-456');
    });

    test('sets error and rethrows when createBaby throws', () async {
      // given
      final viewModel = createViewModel();
      viewModel.setRelationship(Relationship.mom);
      viewModel.setNickname('엄마');

      when(mockRepository.createBaby(
        name: '아기',
        birthDate: '2025-01-01',
        dueDate: null,
        gender: 'male',
        relationship: 'mom',
        nickname: '엄마',
      )).thenThrow(Exception('서버 오류'));

      // when & then
      await expectLater(() => viewModel.submit(), throwsA(isA<Exception>()));

      expect(viewModel.error, '오류가 발생했습니다. 다시 시도해주세요.');
      expect(viewModel.isLoading, isFalse);
    });
  });

  group('submit with JoinBabyFlow', () {
    test('calls joinBabyByInviteCode and returns babyId on success', () async {
      // given
      final flow = JoinBabyFlow(inviteCode: 'ABC-123');
      final viewModel = createViewModel(flow: flow);
      viewModel.setRelationship(Relationship.family);
      viewModel.setNickname('할머니');

      when(mockRepository.joinBabyByInviteCode(
        code: 'ABC-123',
        relationship: 'family',
        nickname: '할머니',
      )).thenAnswer((_) async => 'baby-789');

      // when
      final result = await viewModel.submit();

      // then
      expect(result, 'baby-789');
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
    });

    test('sets error and rethrows when joinBabyByInviteCode throws', () async {
      // given
      final flow = JoinBabyFlow(inviteCode: 'ABC-123');
      final viewModel = createViewModel(flow: flow);
      viewModel.setRelationship(Relationship.dad);
      viewModel.setNickname('아빠');

      when(mockRepository.joinBabyByInviteCode(
        code: 'ABC-123',
        relationship: 'dad',
        nickname: '아빠',
      )).thenThrow(Exception('서버 오류'));

      // when & then
      await expectLater(() => viewModel.submit(), throwsA(isA<Exception>()));

      expect(viewModel.error, '오류가 발생했습니다. 다시 시도해주세요.');
      expect(viewModel.isLoading, isFalse);
    });
  });

  group('submit loading state', () {
    test('notifies listeners with loading state changes', () async {
      // given
      final viewModel = createViewModel();
      viewModel.setRelationship(Relationship.mom);
      viewModel.setNickname('엄마');

      when(mockRepository.createBaby(
        name: '아기',
        birthDate: '2025-01-01',
        dueDate: null,
        gender: 'male',
        relationship: 'mom',
        nickname: '엄마',
      )).thenAnswer((_) async => 'baby-123');

      final loadingStates = <bool>[];
      viewModel.addListener(() {
        loadingStates.add(viewModel.isLoading);
      });

      // when
      await viewModel.submit();

      // then - loading true -> loading false
      expect(loadingStates, [true, false]);
    });

    test('isValid returns false while loading', () async {
      // given
      final viewModel = createViewModel();
      viewModel.setRelationship(Relationship.mom);
      viewModel.setNickname('엄마');
      expect(viewModel.isValid, isTrue);

      final completer = Completer<String>();
      when(mockRepository.createBaby(
        name: '아기',
        birthDate: '2025-01-01',
        dueDate: null,
        gender: 'male',
        relationship: 'mom',
        nickname: '엄마',
      )).thenAnswer((_) => completer.future);

      // when
      final future = viewModel.submit();

      // then
      expect(viewModel.isLoading, isTrue);
      expect(viewModel.isValid, isFalse);

      completer.complete('baby-123');
      await future;
    });
  });
}
