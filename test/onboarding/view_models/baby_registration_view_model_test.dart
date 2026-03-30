import 'package:flutter_test/flutter_test.dart';
import 'package:yuktoe/constants/enum/gender.dart';
import 'package:yuktoe/onboarding/view_models/baby_registration_view_model.dart';

void main() {
  late BabyRegistrationViewModel viewModel;

  setUp(() {
    viewModel = BabyRegistrationViewModel();
  });

  group('initial state', () {
    test('starts with default values', () {
      expect(viewModel.name, '');
      expect(viewModel.gender, isNull);
      expect(viewModel.birthDate, isNull);
      expect(viewModel.dueDate, isNull);
      expect(viewModel.agreedToTerms, isFalse);
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
}
