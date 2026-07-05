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
    test('persists to storage, updates memory, and emits on stream',
        () async {
      when(mockStorage.selectedBabyId).thenReturn(null);
      when(mockStorage.setSelectedBabyId(any)).thenAnswer((_) async {});
      final controller = CurrentBabyController(mockStorage);
      final emissions = <String?>[];
      final sub = controller.selectedBabyIdStream.listen(emissions.add);

      await controller.select('new-id');
      await Future<void>.delayed(Duration.zero);

      verify(mockStorage.setSelectedBabyId('new-id')).called(1);
      expect(controller.selectedBabyId, 'new-id');
      expect(emissions, ['new-id']);

      await sub.cancel();
    });

    test('replaces a previously selected id', () async {
      when(mockStorage.selectedBabyId).thenReturn('old-id');
      when(mockStorage.setSelectedBabyId(any)).thenAnswer((_) async {});
      final controller = CurrentBabyController(mockStorage);
      final emissions = <String?>[];
      final sub = controller.selectedBabyIdStream.listen(emissions.add);

      await controller.select('new-id');
      await Future<void>.delayed(Duration.zero);

      verify(mockStorage.setSelectedBabyId('new-id')).called(1);
      expect(controller.selectedBabyId, 'new-id');
      expect(emissions, ['new-id']);

      await sub.cancel();
    });
  });

  group('clear', () {
    test('removes from storage, clears memory, and emits null on stream',
        () async {
      when(mockStorage.selectedBabyId).thenReturn('id');
      when(mockStorage.removeSelectedBabyId()).thenAnswer((_) async {});
      final controller = CurrentBabyController(mockStorage);
      final emissions = <String?>[];
      final sub = controller.selectedBabyIdStream.listen(emissions.add);

      await controller.clear();
      await Future<void>.delayed(Duration.zero);

      verify(mockStorage.removeSelectedBabyId()).called(1);
      expect(controller.selectedBabyId, isNull);
      expect(emissions, [null]);

      await sub.cancel();
    });
  });
}
