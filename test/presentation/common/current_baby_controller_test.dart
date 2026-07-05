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
    when(mockStorage.setSelectedBabyId(any)).thenAnswer((_) async {});
    when(mockStorage.removeSelectedBabyId()).thenAnswer((_) async {});
  });

  group('boot initialization', () {
    test('selectedBabyId is null when storage returns null', () {
      when(mockStorage.selectedBabyId).thenReturn(null);

      final controller = CurrentBabyController(mockStorage);

      expect(controller.selectedBabyId, isNull);
      controller.dispose();
    });

    test('selectedBabyId is restored from storage on construction', () {
      when(mockStorage.selectedBabyId).thenReturn('persisted');

      final controller = CurrentBabyController(mockStorage);

      expect(controller.selectedBabyId, 'persisted');
      controller.dispose();
    });
  });

  group('select', () {
    test('persists to storage, updates memory, and emits on stream', () async {
      when(mockStorage.selectedBabyId).thenReturn(null);
      final controller = CurrentBabyController(mockStorage);
      final emitted = <String?>[];
      final sub = controller.babyIdStream.listen(emitted.add);

      await controller.select('new-id');
      await pumpEventQueue();

      verify(mockStorage.setSelectedBabyId('new-id')).called(1);
      expect(controller.selectedBabyId, 'new-id');
      expect(emitted, ['new-id']);

      await sub.cancel();
      controller.dispose();
    });

    test('replaces a previously selected id and emits new value', () async {
      when(mockStorage.selectedBabyId).thenReturn('old-id');
      final controller = CurrentBabyController(mockStorage);
      final emitted = <String?>[];
      final sub = controller.babyIdStream.listen(emitted.add);

      await controller.select('new-id');
      await pumpEventQueue();

      expect(controller.selectedBabyId, 'new-id');
      expect(emitted, ['new-id']);

      await sub.cancel();
      controller.dispose();
    });
  });

  group('clear', () {
    test('removes from storage, clears memory, and emits null', () async {
      when(mockStorage.selectedBabyId).thenReturn('id');
      final controller = CurrentBabyController(mockStorage);
      final emitted = <String?>[];
      final sub = controller.babyIdStream.listen(emitted.add);

      await controller.clear();
      await pumpEventQueue();

      verify(mockStorage.removeSelectedBabyId()).called(1);
      expect(controller.selectedBabyId, isNull);
      expect(emitted, [null]);

      await sub.cancel();
      controller.dispose();
    });
  });
}
