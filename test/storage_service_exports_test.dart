import 'package:flutter_test/flutter_test.dart';
import 'package:storage_service/storage_service.dart';

void main() {
  test('Exports are available', () {
    // Just check that the exports are accessible and types are correct
    expect(StorageKeys.secureKey, isA<String>());
    expect(BoxType.normal, isA<BoxType>());
    expect(StorageInitializationError('msg'), isA<StorageError>());
  });
}
