import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/vault_storage.dart';

void main() {
  group('VaultStorage Factory', () {
    test('should create instance without security config', () {
      final storage = VaultStorage.create();
      expect(storage, isNotNull);
      expect(storage, isA<IVaultStorage>());
    });

    test('should create instance with security config', () {
      final securityConfig = VaultSecurityConfig.production(
        watcherMail: 'test@example.com',
      );
      final storage = VaultStorage.create(securityConfig: securityConfig);
      expect(storage, isNotNull);
      expect(storage, isA<IVaultStorage>());
    });

    test('should create instance with custom boxes', () {
      final storage = VaultStorage.create(
        customBoxes: [
          const BoxConfig(name: 'test_box', encrypted: true),
          const BoxConfig(name: 'another_box'),
        ],
      );
      expect(storage, isNotNull);
      expect(storage, isA<IVaultStorage>());
    });

    test('should create instance with storage directory', () {
      final storage = VaultStorage.create(
        storageDirectory: 'custom_dir',
      );
      expect(storage, isNotNull);
      expect(storage, isA<IVaultStorage>());
    });

    test('should create instance with all parameters', () {
      final securityConfig = VaultSecurityConfig.production(
        watcherMail: 'test@example.com',
      );
      final storage = VaultStorage.create(
        securityConfig: securityConfig,
        customBoxes: [
          const BoxConfig(name: 'test_box', encrypted: true),
        ],
        storageDirectory: 'custom_dir',
      );
      expect(storage, isNotNull);
      expect(storage, isA<IVaultStorage>());
    });
  });
}
