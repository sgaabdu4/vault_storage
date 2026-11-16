import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/constants/storage_keys.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

import '../mocks.dart';
import '../test_context.dart';

void main() {
  group('VaultStorageImpl - Comprehensive Tests', () {
    late TestContext testContext;

    setUpAll(() {
      MocksHelper.registerFallbackValues();
    });

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
    });

    tearDown(() {
      testContext.tearDownCommon();
    });

    group('Initialization', () {
      test('should not reinitialize when already initialized', () async {
        // Arrange
        testContext.vaultStorage.isVaultStorageReady = true;

        // Act
        await testContext.vaultStorage.init();

        // Assert
        expect(testContext.vaultStorage.isVaultStorageReady, isTrue);
        verifyNever(() => testContext.mockSecureStorage.read(key: any(named: 'key')));
      });

      test('should handle initialization failure gracefully', () async {
        // Arrange
        final vaultStorage = testContext.createStorage();

        when(
          () => testContext.mockSecureStorage.read(key: StorageKeys.secureKey),
        ).thenThrow(Exception('Secure storage failed'));

        // Act & Assert
        expect(() => vaultStorage.init(), throwsA(isA<StorageInitializationError>()));
      });
    });

    group('Key Management', () {
      test('should return existing key when it exists', () async {
        // Arrange
        const existingKey = 'dGVzdEtleQ=='; // base64 encoded test key
        when(
          () => testContext.mockSecureStorage.read(key: StorageKeys.secureKey),
        ).thenAnswer((_) async => existingKey);

        // Act
        final result = await testContext.vaultStorage.getOrCreateSecureKey();

        // Assert
        expect(result, isA<List<int>>());
        verify(() => testContext.mockSecureStorage.read(key: StorageKeys.secureKey)).called(1);
        verifyNever(
          () => testContext.mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        );
      });

      test('should create new key when it does not exist', () async {
        // Arrange
        when(
          () => testContext.mockSecureStorage.read(key: StorageKeys.secureKey),
        ).thenAnswer((_) async => null);
        when(
          () => testContext.mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final result = await testContext.vaultStorage.getOrCreateSecureKey();

        // Assert
        expect(result, isA<List<int>>());
        expect(result.length, equals(32)); // AES-256 key length
        verify(() => testContext.mockSecureStorage.read(key: StorageKeys.secureKey)).called(1);
        verify(
          () => testContext.mockSecureStorage.write(
            key: StorageKeys.secureKey,
            value: any(named: 'value'),
          ),
        ).called(1);
      });

      test('should throw StorageInitializationError when key creation fails', () async {
        // Arrange
        when(
          () => testContext.mockSecureStorage.read(key: StorageKeys.secureKey),
        ).thenThrow(Exception('Secure storage failed'));

        // Act & Assert
        expect(
          () => testContext.vaultStorage.getOrCreateSecureKey(),
          throwsA(isA<StorageInitializationError>()),
        );
      });
    });

    group('Key-Value Storage - get', () {
      test('should get value from normal storage when isSecure is false', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';
        const jsonValue = '"test_value"';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockNormalBox.get(key)).thenReturn(jsonValue);

        // Act
        final result = await testContext.vaultStorage.get<String>(key, isSecure: false);

        // Assert
        expect(result, equals(value));
        verify(() => testContext.mockNormalBox.containsKey(key)).called(1);
        verify(() => testContext.mockNormalBox.get(key)).called(1);
        verifyNever(() => testContext.mockSecureBox.containsKey(any<String>()));
      });

      test('should get value from secure storage when isSecure is true', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';
        const jsonValue = '"test_value"';

        when(() => testContext.mockSecureBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockSecureBox.get(key)).thenReturn(jsonValue);

        // Act
        final result = await testContext.vaultStorage.get<String>(key, isSecure: true);

        // Assert
        expect(result, equals(value));
        verify(() => testContext.mockSecureBox.containsKey(key)).called(1);
        verify(() => testContext.mockSecureBox.get(key)).called(1);
        verifyNever(() => testContext.mockNormalBox.containsKey(any<String>()));
      });

      test('should check both storages when isSecure is null', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';
        const jsonValue = '"test_value"';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(false);
        when(() => testContext.mockSecureBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockSecureBox.get(key)).thenReturn(jsonValue);

        // Act
        final result = await testContext.vaultStorage.get<String>(key);

        // Assert
        expect(result, equals(value));
        verify(() => testContext.mockNormalBox.containsKey(key)).called(1);
        verify(() => testContext.mockSecureBox.containsKey(key)).called(1);
        verify(() => testContext.mockSecureBox.get(key)).called(1);
      });

      test('should return null when key does not exist', () async {
        // Arrange
        const key = 'nonexistent_key';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(false);
        when(() => testContext.mockSecureBox.containsKey(key)).thenReturn(false);

        // Act
        final result = await testContext.vaultStorage.get<String>(key);

        // Assert
        expect(result, isNull);
      });

      test('should throw StorageInitializationError when not initialized', () async {
        // Arrange
        testContext.vaultStorage.isVaultStorageReady = false;

        // Act & Assert
        expect(
          () => testContext.vaultStorage.get<String>('test_key'),
          throwsA(isA<StorageInitializationError>()),
        );
      });

      test('should throw StorageReadError when reading fails', () async {
        // Arrange
        const key = 'test_key';

        when(
          () => testContext.mockNormalBox.containsKey(key),
        ).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(() => testContext.vaultStorage.get<String>(key), throwsA(isA<StorageReadError>()));
      });
    });

    group('Key-Value Storage - save', () {
      test('should save value to secure storage successfully', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        when(
          () => testContext.mockSecureBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});
        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(false);

        // Act
        await testContext.vaultStorage.saveSecure(key: key, value: value);

        // Assert
        verify(() => testContext.mockSecureBox.put(key, any<Object?>())).called(1);
        verify(() => testContext.mockNormalBox.containsKey(key)).called(1);
      });

      test('should remove from normal storage if key exists there', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        when(
          () => testContext.mockSecureBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});
        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockNormalBox.delete(key)).thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.saveSecure(key: key, value: value);

        // Assert
        verify(() => testContext.mockSecureBox.put(key, any<Object?>())).called(1);
        verify(() => testContext.mockNormalBox.containsKey(key)).called(1);
        verify(() => testContext.mockNormalBox.delete(key)).called(1);
      });

      test('should save value to normal storage successfully', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        when(
          () => testContext.mockNormalBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.saveNormal(key: key, value: value);

        // Assert
        verify(() => testContext.mockNormalBox.put(key, any<Object?>())).called(1);
      });

      test('should throw StorageWriteError when save fails', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        when(
          () => testContext.mockSecureBox.put(any<String>(), any<String>()),
        ).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(
          () => testContext.vaultStorage.saveSecure(key: key, value: value),
          throwsA(isA<StorageWriteError>()),
        );
      });
    });

    group('Key-Value Storage - delete', () {
      test('should delete from both storages when key exists in both', () async {
        // Arrange
        const key = 'test_key';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockSecureBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockNormalBox.delete(key)).thenAnswer((_) async {});
        when(() => testContext.mockSecureBox.delete(key)).thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.delete(key);

        // Assert
        verify(() => testContext.mockNormalBox.delete(key)).called(1);
        verify(() => testContext.mockSecureBox.delete(key)).called(1);
      });

      test('should only delete from storage where key exists', () async {
        // Arrange
        const key = 'test_key';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockSecureBox.containsKey(key)).thenReturn(false);
        when(() => testContext.mockNormalBox.delete(key)).thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.delete(key);

        // Assert
        verify(() => testContext.mockNormalBox.delete(key)).called(1);
        verifyNever(() => testContext.mockSecureBox.delete(any<String>()));
      });

      test('should throw StorageDeleteError when deletion fails', () async {
        // Arrange
        const key = 'test_key';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockSecureBox.containsKey(key)).thenReturn(false);
        when(() => testContext.mockNormalBox.delete(key)).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(() => testContext.vaultStorage.delete(key), throwsA(isA<StorageDeleteError>()));
      });
    });

    group('Storage Management', () {
      test('should clear normal storage successfully', () async {
        // Arrange
        when(() => testContext.mockNormalBox.clear()).thenAnswer((_) async => 0);

        // Act
        await testContext.vaultStorage.clearNormal();

        // Assert
        verify(() => testContext.mockNormalBox.clear()).called(1);
      });

      test('should clear secure storage successfully', () async {
        // Arrange
        when(() => testContext.mockSecureBox.clear()).thenAnswer((_) async => 0);

        // Act
        await testContext.vaultStorage.clearSecure();

        // Assert
        verify(() => testContext.mockSecureBox.clear()).called(1);
      });

      test('should throw StorageDeleteError when clear fails', () async {
        // Arrange
        when(() => testContext.mockNormalBox.clear()).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(() => testContext.vaultStorage.clearNormal(), throwsA(isA<StorageDeleteError>()));
      });
    });
  });
}
