import 'package:flutter_test/flutter_test.dart';
import 'package:storage_service/src/providers/storage_service_providers.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  test('storageServiceProvider is defined', () {
    expect(storageServiceProvider, isNotNull);
  });

  test('Provider can be read (throws if not initialized)', () async {
    final container = ProviderContainer();
    expect(() => container.read(storageServiceProvider), returnsNormally);
  });
}
