import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';

import 'current_baby_controller_test.mocks.dart';

@GenerateMocks([AppLocalStorage])
void main() {
  late MockAppLocalStorage mockStorage;

  setUp(() {
    mockStorage = MockAppLocalStorage();
  });

  group('boot initialization', () {
    test('selectedBabyId is null when storage returns null', () {
      when(mockStorage.selectedBabyId).thenReturn(null);

      final controller = CurrentBabyController(mockStorage);

      expect(controller.selectedBabyId, isNull);
    });

    test('selectedBabyId is restored from storage on construction', () {
      when(mockStorage.selectedBabyId).thenReturn('persisted');

      final controller = CurrentBabyController(mockStorage);

      expect(controller.selectedBabyId, 'persisted');
    });
  });

  group('select', () {
    test('persists to storage, updates memory, and notifies listeners',
        () async {
      when(mockStorage.selectedBabyId).thenReturn(null);
      when(mockStorage.setSelectedBabyId(any)).thenAnswer((_) async {});
      final controller = CurrentBabyController(mockStorage);
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.select('new-id');

      verify(mockStorage.setSelectedBabyId('new-id')).called(1);
      expect(controller.selectedBabyId, 'new-id');
      expect(notifyCount, 1);
    });

    test('replaces a previously selected id', () async {
      when(mockStorage.selectedBabyId).thenReturn('old-id');
      when(mockStorage.setSelectedBabyId(any)).thenAnswer((_) async {});
      final controller = CurrentBabyController(mockStorage);
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.select('new-id');

      verify(mockStorage.setSelectedBabyId('new-id')).called(1);
      expect(controller.selectedBabyId, 'new-id');
      expect(notifyCount, 1);
    });
  });

  group('clear', () {
    test('removes from storage, clears memory, and notifies listeners',
        () async {
      when(mockStorage.selectedBabyId).thenReturn('id');
      when(mockStorage.removeSelectedBabyId()).thenAnswer((_) async {});
      final controller = CurrentBabyController(mockStorage);
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.clear();

      verify(mockStorage.removeSelectedBabyId()).called(1);
      expect(controller.selectedBabyId, isNull);
      expect(notifyCount, 1);
    });
  });
}
