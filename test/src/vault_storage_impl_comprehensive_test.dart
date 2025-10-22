import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/constants/storage_keys.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
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
        final vaultStorage = VaultStorageImpl(
          secureStorage: testContext.mockSecureStorage,
          uuid: testContext.mockUuid,
          fileOperations: testContext.mockFileOperations,
        );

        when(() => testContext.mockSecureStorage.read(key: StorageKeys.secureKey))
            .thenThrow(Exception('Secure storage failed'));

        // Act & Assert
        expect(
          () => vaultStorage.init(),
          throwsA(isA<StorageInitializationError>()),
        );
      });
    });

    group('Key Management', () {
      test('should return existing key when it exists', () async {
        // Arrange
        const existingKey = 'dGVzdEtleQ=='; // base64 encoded test key
        when(() => testContext.mockSecureStorage.read(key: StorageKeys.secureKey))
            .thenAnswer((_) async => existingKey);

        // Act
        final result = await testContext.vaultStorage.getOrCreateSecureKey();

        // Assert
        expect(result, isA<List<int>>());
        verify(() => testContext.mockSecureStorage.read(key: StorageKeys.secureKey)).called(1);
        verifyNever(() => testContext.mockSecureStorage.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            ));
      });

      test('should create new key when it does not exist', () async {
        // Arrange
        when(() => testContext.mockSecureStorage.read(key: StorageKeys.secureKey))
            .thenAnswer((_) async => null);
        when(() => testContext.mockSecureStorage.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            )).thenAnswer((_) async {});

        // Act
        final result = await testContext.vaultStorage.getOrCreateSecureKey();

        // Assert
        expect(result, isA<List<int>>());
        expect(result.length, equals(32)); // AES-256 key length
        verify(() => testContext.mockSecureStorage.read(key: StorageKeys.secureKey)).called(1);
        verify(() => testContext.mockSecureStorage.write(
              key: StorageKeys.secureKey,
              value: any(named: 'value'),
            )).called(1);
      });

      test('should throw StorageInitializationError when key creation fails', () async {
        // Arrange
        when(() => testContext.mockSecureStorage.read(key: StorageKeys.secureKey))
            .thenThrow(Exception('Secure storage failed'));

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

        when(() => testContext.mockNormalBox.containsKey(key))
            .thenThrow(Exception('Database error'));

        // Act & Assert
        expect(
          () => testContext.vaultStorage.get<String>(key),
          throwsA(isA<StorageReadError>()),
        );
      });
    });

    group('Key-Value Storage - save', () {
      test('should save value to secure storage successfully', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        when(() => testContext.mockSecureBox.put(any<String>(), any<String>()))
            .thenAnswer((_) async {});
        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(false);

        // Act
        await testContext.vaultStorage.saveSecure(key: key, value: value);

        // Assert
        verify(() => testContext.mockSecureBox.put(key, any<String>())).called(1);
        verify(() => testContext.mockNormalBox.containsKey(key)).called(1);
      });

      test('should remove from normal storage if key exists there', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        when(() => testContext.mockSecureBox.put(any<String>(), any<String>()))
            .thenAnswer((_) async {});
        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockNormalBox.delete(key)).thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.saveSecure(key: key, value: value);

        // Assert
        verify(() => testContext.mockSecureBox.put(key, any())).called(1);
        verify(() => testContext.mockNormalBox.containsKey(key)).called(1);
        verify(() => testContext.mockNormalBox.delete(key)).called(1);
      });

      test('should save value to normal storage successfully', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        when(() => testContext.mockNormalBox.put(any<String>(), any<String>()))
            .thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.saveNormal(key: key, value: value);

        // Assert
        verify(() => testContext.mockNormalBox.put(key, any())).called(1);
      });

      test('should throw StorageWriteError when save fails', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        when(() => testContext.mockSecureBox.put(any<String>(), any<String>()))
            .thenThrow(Exception('Database error'));

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
        expect(
          () => testContext.vaultStorage.delete(key),
          throwsA(isA<StorageDeleteError>()),
        );
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
        expect(
          () => testContext.vaultStorage.clearNormal(),
          throwsA(isA<StorageDeleteError>()),
        );
      });
    });

    group('File Storage', () {
      test('should save secure file successfully', () async {
        // Arrange
        const key = 'test_file';
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileName = 'test.txt';
        final mockMetadata = {'fileId': 'test-id', 'extension': 'txt'};

        when(() => testContext.mockFileOperations.saveSecureFile(
              fileBytes: any(named: 'fileBytes'),
              fileExtension: any(named: 'fileExtension'),
              isWeb: any(named: 'isWeb'),
              secureStorage: any(named: 'secureStorage'),
              uuid: any(named: 'uuid'),
              getBox: any(named: 'getBox'),
            )).thenAnswer((_) async => mockMetadata);
        when(() => testContext.mockSecureFilesBox.put(any<String>(), any<String>()))
            .thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.saveSecureFile(
          key: key,
          fileBytes: fileBytes,
          originalFileName: fileName,
        );

        // Assert
        verify(() => testContext.mockFileOperations.saveSecureFile(
              fileBytes: fileBytes,
              fileExtension: 'txt',
              isWeb: any(named: 'isWeb'),
              secureStorage: any(named: 'secureStorage'),
              uuid: any(named: 'uuid'),
              getBox: any(named: 'getBox'),
            )).called(1);
        verify(() => testContext.mockSecureFilesBox.put(key, any())).called(1);
      });

      test('should save normal file successfully', () async {
        // Arrange
        const key = 'test_file';
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileName = 'test.txt';
        final mockMetadata = {'fileId': 'test-id', 'extension': 'txt'};

        when(() => testContext.mockFileOperations.saveNormalFile(
              fileBytes: any(named: 'fileBytes'),
              fileExtension: any(named: 'fileExtension'),
              isWeb: any(named: 'isWeb'),
              uuid: any(named: 'uuid'),
              getBox: any(named: 'getBox'),
            )).thenAnswer((_) async => mockMetadata);
        when(() => testContext.mockNormalFilesBox.put(any<String>(), any<String>()))
            .thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.saveNormalFile(
          key: key,
          fileBytes: fileBytes,
          originalFileName: fileName,
        );

        // Assert
        verify(() => testContext.mockFileOperations.saveNormalFile(
              fileBytes: fileBytes,
              fileExtension: 'txt',
              isWeb: any(named: 'isWeb'),
              uuid: any(named: 'uuid'),
              getBox: any(named: 'getBox'),
            )).called(1);
        verify(() => testContext.mockNormalFilesBox.put(key, any())).called(1);
      });

      test('should return null when file does not exist', () async {
        // Arrange
        const key = 'nonexistent_file';

        when(() => testContext.mockNormalFilesBox.containsKey(key)).thenReturn(false);
        when(() => testContext.mockSecureFilesBox.containsKey(key)).thenReturn(false);

        // Act
        final result = await testContext.vaultStorage.getFile(key);

        // Assert
        expect(result, isNull);
      });

      test('should delete file from both storages when it exists in both', () async {
        // Arrange
        const key = 'test_file';

        // Provide JSON metadata for both normal and secure
        const normalJson = '{"fileId":"normal-id","extension":"txt"}';
        const secureJson =
            '{"fileId":"secure-id","secureKeyName":"file_key_secure-id","nonce":"bnVsbA==","mac":"bnVsbA=="}';

        when(() => testContext.mockNormalFilesBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockNormalFilesBox.get(key)).thenAnswer((_) async => normalJson);
        when(() => testContext.mockSecureFilesBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockSecureFilesBox.get(key)).thenAnswer((_) async => secureJson);

        // Underlying deletions
        when(() => testContext.mockFileOperations.deleteNormalFile(
              fileMetadata: any(named: 'fileMetadata'),
              isWeb: any(named: 'isWeb'),
              getBox: any(named: 'getBox'),
            )).thenAnswer((_) async {});
        when(() => testContext.mockFileOperations.deleteSecureFile(
              fileMetadata: any(named: 'fileMetadata'),
              isWeb: any(named: 'isWeb'),
              secureStorage: any(named: 'secureStorage'),
              getBox: any(named: 'getBox'),
            )).thenAnswer((_) async {});

        // Metadata deletions
        when(() => testContext.mockNormalFilesBox.delete(key)).thenAnswer((_) async {});
        when(() => testContext.mockSecureFilesBox.delete(key)).thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.deleteFile(key);

        // Assert
        verify(() => testContext.mockNormalFilesBox.delete(key)).called(1);
        verify(() => testContext.mockSecureFilesBox.delete(key)).called(1);
      });

      test('should throw StorageWriteError when file save fails', () async {
        // Arrange
        const key = 'test_file';
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        when(() => testContext.mockFileOperations.saveSecureFile(
              fileBytes: any(named: 'fileBytes'),
              fileExtension: any(named: 'fileExtension'),
              isWeb: any(named: 'isWeb'),
              secureStorage: any(named: 'secureStorage'),
              uuid: any(named: 'uuid'),
              getBox: any(named: 'getBox'),
            )).thenThrow(Exception('File save failed'));

        // Act & Assert
        expect(
          () => testContext.vaultStorage.saveSecureFile(
            key: key,
            fileBytes: fileBytes,
          ),
          throwsA(isA<StorageWriteError>()),
        );
      });
    });

    group('Disposal', () {
      test('should dispose successfully when initialized', () async {
        // Arrange
        testContext.vaultStorage.isVaultStorageReady = true;

        // Act
        await testContext.vaultStorage.dispose();

        // Assert
        expect(testContext.vaultStorage.isVaultStorageReady, isFalse);
        expect(testContext.vaultStorage.boxes.isEmpty, isTrue);
      });

      test('should handle disposal gracefully when not initialized', () async {
        // Arrange
        testContext.vaultStorage.isVaultStorageReady = false;

        // Act & Assert - Should not throw
        await testContext.vaultStorage.dispose();

        expect(testContext.vaultStorage.isVaultStorageReady, isFalse);
      });
    });

    group('Helper Methods', () {
      test('should get value from normal box correctly', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';
        const jsonValue = '"test_value"';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockNormalBox.get(key)).thenReturn(jsonValue);

        // Act
        final result = await testContext.vaultStorage.getFromBox<String>(BoxType.normal, key);

        // Assert
        expect(result, equals(value));
      });

      test('should return null when key does not exist in box', () async {
        // Arrange
        const key = 'nonexistent_key';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(false);

        // Act
        final result = await testContext.vaultStorage.getFromBox<String>(BoxType.normal, key);

        // Assert
        expect(result, isNull);
      });

      test('should set value in normal box correctly', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        when(() => testContext.mockNormalBox.put(any<String>(), any<String>()))
            .thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.setInBox(BoxType.normal, key, value);

        // Assert
        verify(() => testContext.mockNormalBox.put(key, any())).called(1);
      });

      test('should throw StorageInitializationError when box is not opened', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        testContext.vaultStorage.boxes.remove(BoxType.normal);

        // Act & Assert
        expect(
          () => testContext.vaultStorage.setInBox(BoxType.normal, key, value),
          throwsA(isA<StorageInitializationError>()),
        );
      });

      test('should return the correct box for given type', () {
        // Act
        final normalBox = testContext.vaultStorage.getInternalBox(BoxType.normal);
        final secureBox = testContext.vaultStorage.getInternalBox(BoxType.secure);

        // Assert
        expect(normalBox, equals(testContext.mockNormalBox));
        expect(secureBox, equals(testContext.mockSecureBox));
      });
    });

    group('Edge Cases and Error Scenarios', () {
      test('should handle JSON serialization errors gracefully', () async {
        // Arrange
        const key = 'test_key';
        const invalidJson = 'invalid_json';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockNormalBox.get(key)).thenReturn(invalidJson);

        // Act & Assert
        expect(
          () => testContext.vaultStorage.get<String>(key, isSecure: false),
          throwsA(isA<StorageSerializationError>()),
        );
      });

      test('should maintain state consistency after errors', () async {
        // Arrange
        const key = 'error_key';
        const value = 'error_value';

        when(() => testContext.mockNormalBox.put(any<String>(), any<String>()))
            .thenThrow(Exception('Temporary error'));

        // Act & Assert
        expect(
          () => testContext.vaultStorage.saveNormal(key: key, value: value),
          throwsA(isA<StorageWriteError>()),
        );

        // Storage should still be ready after error
        expect(testContext.vaultStorage.isVaultStorageReady, isTrue);
      });

      test('should handle concurrent access gracefully', () async {
        // Arrange
        const key = 'concurrent_key';
        const value = 'concurrent_value';

        when(() => testContext.mockNormalBox.put(any<String>(), any<String>()))
            .thenAnswer((_) async {});

        // Act - Simulate concurrent writes
        final futures = List.generate(
            10, (index) => testContext.vaultStorage.saveNormal(key: key, value: '${value}_$index'));

        // Assert - Should complete without throwing
        await Future.wait(futures);

        verify(() => testContext.mockNormalBox.put(key, any())).called(10);
      });
    });
  });
}
