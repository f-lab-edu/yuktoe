import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';
import 'package:yuktoe/presentation/onboarding/view_models/baby_registration_view_model.dart';

import 'baby_registration_view_model_test.mocks.dart';

@GenerateMocks([BabyRegistrationRepository])
void main() {
  late MockBabyRegistrationRepository mockRepository;
  late BabyRegistrationViewModel viewModel;

  setUp(() {
    mockRepository = MockBabyRegistrationRepository();
    viewModel = BabyRegistrationViewModel(repository: mockRepository);
  });

  group('initial state', () {
    test('starts with default values', () {
      expect(viewModel.name, '');
      expect(viewModel.gender, isNull);
      expect(viewModel.birthDate, isNull);
      expect(viewModel.dueDate, isNull);
      expect(viewModel.agreedToTerms, isFalse);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(viewModel.babyId, isNull);
      expect(viewModel.isValid, isFalse);
    });
  });

  group('setName', () {
    test('updates name and notifies listeners', () {
      var notified = false;
      viewModel.addListener(() => notified = true);

      viewModel.setName('아기');

      expect(viewModel.name, '아기');
      expect(notified, isTrue);
    });
  });

  group('setGender', () {
    test('updates gender and notifies listeners', () {
      var notified = false;
      viewModel.addListener(() => notified = true);

      viewModel.setGender(Gender.male);

      expect(viewModel.gender, Gender.male);
      expect(notified, isTrue);
    });
  });

  group('setBirthDate', () {
    test('updates birthDate and notifies listeners', () {
      var notified = false;
      viewModel.addListener(() => notified = true);

      final date = DateTime(2025, 1, 1);
      viewModel.setBirthDate(date);

      expect(viewModel.birthDate, date);
      expect(notified, isTrue);
    });
  });

  group('setDueDate', () {
    test('updates dueDate and notifies listeners', () {
      var notified = false;
      viewModel.addListener(() => notified = true);

      final date = DateTime(2025, 6, 1);
      viewModel.setDueDate(date);

      expect(viewModel.dueDate, date);
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
    test('returns false when name is empty', () {
      viewModel.setGender(Gender.male);
      viewModel.setBirthDate(DateTime(2025, 1, 1));
      viewModel.toggleAgreedToTerms();

      expect(viewModel.isValid, isFalse);
    });

    test('returns false when name is whitespace only', () {
      viewModel.setName('   ');
      viewModel.setGender(Gender.male);
      viewModel.setBirthDate(DateTime(2025, 1, 1));
      viewModel.toggleAgreedToTerms();

      expect(viewModel.isValid, isFalse);
    });

    test('returns false when gender is null', () {
      viewModel.setName('아기');
      viewModel.setBirthDate(DateTime(2025, 1, 1));
      viewModel.toggleAgreedToTerms();

      expect(viewModel.isValid, isFalse);
    });

    test('returns false when birthDate is null', () {
      viewModel.setName('아기');
      viewModel.setGender(Gender.male);
      viewModel.toggleAgreedToTerms();

      expect(viewModel.isValid, isFalse);
    });

    test('returns false when terms not agreed', () {
      viewModel.setName('아기');
      viewModel.setGender(Gender.male);
      viewModel.setBirthDate(DateTime(2025, 1, 1));

      expect(viewModel.isValid, isFalse);
    });

    test('returns true when all required fields are set', () {
      viewModel.setName('아기');
      viewModel.setGender(Gender.male);
      viewModel.setBirthDate(DateTime(2025, 1, 1));
      viewModel.toggleAgreedToTerms();

      expect(viewModel.isValid, isTrue);
    });

    test('returns true without dueDate (optional)', () {
      viewModel.setName('아기');
      viewModel.setGender(Gender.female);
      viewModel.setBirthDate(DateTime(2025, 3, 15));
      viewModel.toggleAgreedToTerms();

      expect(viewModel.isValid, isTrue);
      expect(viewModel.dueDate, isNull);
    });
  });

  group('submit', () {
    void setValidState() {
      viewModel.setName('아기');
      viewModel.setGender(Gender.male);
      viewModel.setBirthDate(DateTime(2025, 1, 15));
      viewModel.toggleAgreedToTerms();
    }

    test('calls createBaby and sets babyId on success', () async {
      setValidState();
      when(
        mockRepository.createBaby(
          name: '아기',
          birthDate: '2025-01-15',
          dueDate: null,
          gender: 'male',
        ),
      ).thenAnswer((_) async => 'baby-123');

      await viewModel.submit();

      expect(viewModel.babyId, 'baby-123');
      expect(viewModel.error, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('sets error when createBaby throws', () async {
      setValidState();
      when(
        mockRepository.createBaby(
          name: '아기',
          birthDate: '2025-01-15',
          dueDate: null,
          gender: 'male',
        ),
      ).thenThrow(Exception('서버 오류'));

      await viewModel.submit();

      expect(viewModel.error, '오류가 발생했습니다.');
      expect(viewModel.babyId, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('notifies listeners with loading state changes', () async {
      setValidState();
      when(
        mockRepository.createBaby(
          name: '아기',
          birthDate: '2025-01-15',
          dueDate: null,
          gender: 'male',
        ),
      ).thenAnswer((_) async => 'baby-123');

      final loadingStates = <bool>[];
      viewModel.addListener(() {
        loadingStates.add(viewModel.isLoading);
      });

      await viewModel.submit();

      expect(loadingStates, [true, false]);
    });

    test('isValid returns false while loading', () async {
      setValidState();
      expect(viewModel.isValid, isTrue);

      final completer = Completer<String>();
      when(
        mockRepository.createBaby(
          name: '아기',
          birthDate: '2025-01-15',
          dueDate: null,
          gender: 'male',
        ),
      ).thenAnswer((_) => completer.future);

      final future = viewModel.submit();

      expect(viewModel.isLoading, isTrue);
      expect(viewModel.isValid, isFalse);

      completer.complete('baby-123');
      await future;
    });

    test('formats dueDate when provided', () async {
      viewModel.setName('아기');
      viewModel.setGender(Gender.female);
      viewModel.setBirthDate(DateTime(2025, 3, 1));
      viewModel.setDueDate(DateTime(2025, 4, 15));
      viewModel.toggleAgreedToTerms();

      when(
        mockRepository.createBaby(
          name: '아기',
          birthDate: '2025-03-01',
          dueDate: '2025-04-15',
          gender: 'female',
        ),
      ).thenAnswer((_) async => 'baby-456');

      await viewModel.submit();

      expect(viewModel.babyId, 'baby-456');
    });
  });
}
