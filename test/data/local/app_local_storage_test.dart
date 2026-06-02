import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';

void main() {
  late AppLocalStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = AppLocalStorage(await SharedPreferences.getInstance());
  });

  test('selectedBabyId is null when nothing is stored', () {
    expect(storage.selectedBabyId, isNull);
  });

  test('setSelectedBabyId persists the value', () async {
    await storage.setSelectedBabyId('a');
    expect(storage.selectedBabyId, 'a');
  });

  test('setSelectedBabyId overwrites a previous value', () async {
    await storage.setSelectedBabyId('a');
    await storage.setSelectedBabyId('b');
    expect(storage.selectedBabyId, 'b');
  });

  test('removeSelectedBabyId clears the value', () async {
    await storage.setSelectedBabyId('a');
    await storage.removeSelectedBabyId();
    expect(storage.selectedBabyId, isNull);
  });

  test('restores value from initial mock state', () async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'restored'});
    final restored = AppLocalStorage(await SharedPreferences.getInstance());
    expect(restored.selectedBabyId, 'restored');
  });
}
