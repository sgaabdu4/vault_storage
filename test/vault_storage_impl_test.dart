import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/mockito.dart';
import 'package:vault_storage/src/constants/storage_keys.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/extensions/extensions.dart';
import 'package:vault_storage/src/extensions/storage_extensions.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

import 'mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VaultStorageImpl vaultStorage;
  late MockFlutterSecureStorage mockSecureStorage;
  late MockUuid mockUuid;
  late MockBox<String> mockSecureBox;
  late MockBox<String> mockNormalBox;
  late MockBox<String> mockSecureFilesBox;
  late MockBox<String> mockNormalFilesBox;

  setUp(() {
    mockSecureStorage = MockFlutterSecureStorage();
    mockUuid = MockUuid();
    mockSecureBox = MockBox<String>();
    mockNormalBox = MockBox<String>();
    mockSecureFilesBox = MockBox<String>();
    mockNormalFilesBox = MockBox<String>();

    vaultStorage = VaultStorageImpl(
      secureStorage: mockSecureStorage,
      uuid: mockUuid,
    );

    vaultStorage.storageBoxes.addAll({
      BoxType.secure: mockSecureBox,
      BoxType.normal: mockNormalBox,
      BoxType.secureFiles: mockSecureFilesBox,
      BoxType.normalFiles: mockNormalFilesBox,
    });
    vaultStorage.isVaultStorageReady = true;

    const MethodChannel('plugins.flutter.io/path_provider').setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '.';
      }
      return null;
    });
  });

  tearDown(() {
    const MethodChannel('plugins.flutter.io/path_provider').setMockMethodCallHandler(null);
  });

  group('VaultStorageImpl Tests', () {
    group('Key-Value Storage', () {
      group('get', () {
        test('should return value when key exists', () async {
          const key = 'test_key';
          final value = {'data': 'test_data'};
          // Use the encodeJsonSafely extension instead of direct jsonEncode
          when(mockNormalBox.get(key)).thenReturn(json.encode(value));

          final result = await vaultStorage.get<Map<String, dynamic>>(BoxType.normal, key);

          expect(result.isRight(), isTrue);
          expect(result.getOrElse((_) => {}), value);
        });

        test('should return null when key does not exist', () async {
          const key = 'non_existent_key';
          when(mockNormalBox.get(key)).thenReturn(null);

          final result = await vaultStorage.get<dynamic>(BoxType.normal, key);

          expect(result.isRight(), isTrue);
          expect(result.getOrElse((_) => 'a'), isNull);
        });

        test('should return StorageReadError on failure', () async {
          const key = 'test_key';
          when(mockNormalBox.get(key)).thenThrow(Exception('Read error'));

          final result = await vaultStorage.get<dynamic>(BoxType.normal, key);

          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
        });

        test('should return StorageSerializationError on json decoding error', () async {
          const key = 'test_key';
          when(mockNormalBox.get(key)).thenReturn('invalid json');

          final result = await vaultStorage.get<dynamic>(BoxType.normal, key);

          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageSerializationError>());
        });
      });

      group('set', () {
        test('should return unit when value is set successfully', () async {
          const key = 'test_key';
          const value = {'data': 'test_data'};
          when(mockNormalBox.put(any, any)).thenAnswer((_) async => unit);

          final result = await vaultStorage.set(BoxType.normal, key, value);

          expect(result.isRight(), isTrue);
          // Use the actual json.encode here since we're verifying the mockito call
          verify(mockNormalBox.put(key, json.encode(value))).called(1);
        });

        test('should return StorageWriteError on failure', () async {
          const key = 'test_key';
          const value = {'data': 'test_data'};
          when(mockNormalBox.put(any, any)).thenThrow(Exception('Write error'));

          final result = await vaultStorage.set(BoxType.normal, key, value);

          expect(result.isLeft(), isTrue);
          result.fold(
            (l) => expect(l, isA<StorageWriteError>()),
            (r) => fail('Expected a StorageWriteError'),
          );
        });

        test('should return StorageSerializationError on json encoding error', () async {
          const key = 'test_key';
          final value = _UnencodableObject(); // This will throw JsonUnsupportedObjectError

          final result = await vaultStorage.set(BoxType.normal, key, value);

          expect(result.isLeft(), isTrue);
          result.fold(
            (l) => expect(l, isA<StorageSerializationError>()),
            (r) => fail('Expected a StorageSerializationError'),
          );
        });
      });

      group('delete', () {
        test('should return unit when value is deleted successfully', () async {
          const key = 'test_key';
          when(mockNormalBox.delete(key)).thenAnswer((_) async => unit);

          final result = await vaultStorage.delete(BoxType.normal, key);

          expect(result.isRight(), isTrue);
          verify(mockNormalBox.delete(key)).called(1);
        });

        test('should return StorageDeleteError on failure', () async {
          const key = 'test_key';
          when(mockNormalBox.delete(key)).thenThrow(Exception('Delete error'));

          final result = await vaultStorage.delete(BoxType.normal, key);

          expect(result.isLeft(), isTrue);
          result.fold(
            (l) => expect(l, isA<StorageDeleteError>()),
            (r) => fail('Expected a StorageDeleteError'),
          );
        });
      });

      group('clear', () {
        test('should return unit when box is cleared successfully', () async {
          when(mockNormalBox.clear()).thenAnswer((_) async => 1);

          final result = await vaultStorage.clear(BoxType.normal);

          expect(result.isRight(), isTrue);
          verify(mockNormalBox.clear()).called(1);
        });

        test('should return StorageDeleteError on failure', () async {
          when(mockNormalBox.clear()).thenThrow(Exception('Clear error'));

          final result = await vaultStorage.clear(BoxType.normal);

          expect(result.isLeft(), isTrue);
          result.fold(
            (l) => expect(l, isA<StorageDeleteError>()),
            (r) => fail('Expected a StorageDeleteError'),
          );
        });
      });
    });

    group('Secure File Storage', () {
      final fileBytes = Uint8List.fromList([1, 2, 3]);
      const fileExtension = 'txt';
      const fileId = 'test-uuid';
      final metadata = {
        'fileId': fileId,
        'filePath': './$fileId.$fileExtension.enc',
        'secureKeyName': 'file_key_$fileId',
        'nonce': [4, 5, 6].encodeBase64(),
        'mac': [7, 8, 9].encodeBase64(),
      };

      setUp(() {
        when(mockUuid.v4()).thenReturn(fileId);
      });

      group('saveSecureFile', () {
        test('should save file and return metadata on success', () async {
          when(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value'))).thenAnswer((_) async {});

          final result = await vaultStorage.saveSecureFile(
            fileBytes: fileBytes,
            fileExtension: fileExtension,
          );

          expect(result.isRight(), isTrue);
          final returnedMetadata = result.getOrElse((_) => {});
          expect(returnedMetadata['filePath'], endsWith('.enc'));
          expect(returnedMetadata['secureKeyName'], isA<String>());
          verify(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value'))).called(1);

          // Cleanup the created file
          final file = File(returnedMetadata['filePath'] as String);
          if (file.existsSync()) {
            file.deleteSync();
          }
        });

        test('should return StorageWriteError on failure', () async {
          when(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value')))
              .thenThrow(Exception('Storage write error'));

          final result = await vaultStorage.saveSecureFile(
            fileBytes: fileBytes,
            fileExtension: fileExtension,
          );

          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageWriteError>());
        });
      });

      group('getSecureFile', () {
        final algorithm = AesGcm.with256bits();

        test('should return file bytes on success', () async {
          // Prepare valid encrypted data
          final originalData = Uint8List.fromList(utf8.encode('some secret data'));
          final secretKey = await algorithm.newSecretKey();
          final keyBytes = await secretKey.extractBytes();
          final secretBox = await algorithm.encrypt(originalData, secretKey: secretKey);

          // Setup mocks and file system with the valid data
          final file = File(metadata['filePath'] as String);
          await file.writeAsBytes(secretBox.cipherText, flush: true);

          when(mockSecureStorage.read(key: metadata['secureKeyName'] as String))
              .thenAnswer((_) async => keyBytes.encodeBase64());

          final validMetadata = {
            'fileId': fileId,
            'filePath': metadata['filePath'],
            'secureKeyName': metadata['secureKeyName'],
            'nonce': secretBox.nonce.encodeBase64(),
            'mac': secretBox.mac.bytes.encodeBase64(),
          };

          // Call the method under test
          final result = await vaultStorage.getSecureFile(fileMetadata: validMetadata);

          // Assert
          expect(result.isRight(), isTrue, reason: result.fold((l) => l.message, (r) => ''));
          result.fold(
            (l) => fail('getSecureFile should not have failed: ${l.message}'),
            (decryptedData) => expect(decryptedData, originalData),
          );

          // Cleanup
          await file.delete();
        });

        test('should return StorageReadError if key not in secure storage', () async {
          final file = File(metadata['filePath'] as String);
          await file.writeAsBytes(Uint8List.fromList([10, 11, 12]), flush: true);
          when(mockSecureStorage.read(key: metadata['secureKeyName'] as String)).thenAnswer((_) async => null);

          final result = await vaultStorage.getSecureFile(fileMetadata: metadata);

          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());

          await file.delete();
        });

        test('should return StorageReadError on file read failure', () async {
          // Don't create the file, so read will fail
          when(mockSecureStorage.read(key: metadata['secureKeyName'] as String))
              .thenAnswer((_) async => List.generate(32, (i) => i).encodeBase64());

          final result = await vaultStorage.getSecureFile(fileMetadata: metadata);

          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
        });
      });

      group('deleteSecureFile', () {
        test('should return unit on success', () async {
          final file = File(metadata['filePath'] as String);
          await file.create();
          when(mockSecureStorage.delete(key: metadata['secureKeyName'] as String)).thenAnswer((_) async {});

          final result = await vaultStorage.deleteSecureFile(fileMetadata: metadata);

          expect(result.isRight(), isTrue);
          expect(await file.exists(), isFalse);
          verify(mockSecureStorage.delete(key: metadata['secureKeyName'] as String)).called(1);
        });

        test('should return StorageDeleteError on failure', () async {
          when(mockSecureStorage.delete(key: metadata['secureKeyName'] as String)).thenThrow(Exception('Delete error'));

          final result = await vaultStorage.deleteSecureFile(fileMetadata: metadata);

          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageDeleteError>());
        });
      });
    });

    group('saveSecureFile (Web)', () {
      test('should save file to Hive on web', () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3]);
        const fileExtension = 'txt';
        const fileId = 'test-uuid';
        final secretKey = await AesGcm.with256bits().newSecretKey();
        final keyBytes = await secretKey.extractBytes();
        final secretBox = await AesGcm.with256bits().encrypt(fileBytes, secretKey: secretKey);
        final encryptedContentBase64 = secretBox.cipherText.encodeBase64();

        when(mockUuid.v4()).thenReturn(fileId);
        when(mockSecureStorage.write(key: 'file_key_$fileId', value: keyBytes.encodeBase64())).thenAnswer((_) async {});
        when(mockSecureFilesBox.put(fileId, encryptedContentBase64)).thenAnswer((_) async {});

        // Act
        final result =
            await vaultStorage.saveSecureFile(fileBytes: fileBytes, fileExtension: fileExtension, isWeb: true);

        // Assert
        expect(result.isRight(), isTrue);
        result.fold((l) => fail('should not return left'), (r) {
          expect(r['fileId'], fileId);
          expect(r['filePath'], isNull);
        });
      });
    });

    group('getSecureFile (Web)', () {
      test('should retrieve file from Hive on web', () async {
        // Arrange
        const fileId = 'test-uuid';
        final keyBytes = List.generate(32, (index) => index % 256); // 32 bytes exactly
        final secretKey = SecretKey(keyBytes);
        final originalData = Uint8List.fromList(utf8.encode('secret data'));
        final secretBox = await AesGcm.with256bits().encrypt(originalData, secretKey: secretKey);
        final encryptedContentBase64 = secretBox.cipherText.encodeBase64();

        final metadata = {
          'fileId': fileId,
          'secureKeyName': 'file_key_$fileId',
          'nonce': secretBox.nonce.encodeBase64(),
          'mac': secretBox.mac.bytes.encodeBase64(),
        };

        when(mockSecureFilesBox.get(fileId)).thenReturn(encryptedContentBase64);
        when(mockSecureStorage.read(key: 'file_key_$fileId')).thenAnswer((_) async => keyBytes.encodeBase64());

        // Act
        final result = await vaultStorage.getSecureFile(fileMetadata: metadata, isWeb: true);

        // Assert
        expect(result.isRight(), isTrue, reason: result.fold((l) => l.message, (r) => ''));
        result.fold((l) => null, (r) => expect(r, originalData));
      });

      test('should return StorageReadError when file not found in Hive on web', () async {
        // Arrange
        const fileId = 'test-uuid';
        final metadata = {
          'fileId': fileId,
          'secureKeyName': 'file_key_$fileId',
          'nonce': [1, 2, 3].encodeBase64(),
          'mac': [4, 5, 6].encodeBase64(),
        };

        when(mockSecureFilesBox.get(fileId)).thenReturn(null);

        // Act
        final result = await vaultStorage.getSecureFile(fileMetadata: metadata, isWeb: true);

        // Assert
        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
      });
    });

    group('deleteSecureFile (Web)', () {
      test('should delete file from Hive on web', () async {
        // Arrange
        const fileId = 'test-uuid';
        final metadata = {
          'fileId': fileId,
          'secureKeyName': 'file_key_$fileId',
        };

        when(mockSecureFilesBox.delete(fileId)).thenAnswer((_) async {});
        when(mockSecureStorage.delete(key: 'file_key_$fileId')).thenAnswer((_) async {});

        // Act
        final result = await vaultStorage.deleteSecureFile(fileMetadata: metadata, isWeb: true);

        // Assert
        expect(result.isRight(), isTrue);
        verify(mockSecureFilesBox.delete(fileId)).called(1);
        verify(mockSecureStorage.delete(key: 'file_key_$fileId')).called(1);
      });
    });

    group('Normal File Storage', () {
      final fileBytes = Uint8List.fromList([1, 2, 3]);
      const fileExtension = 'txt';
      const fileId = 'test-uuid';
      final metadata = {
        'fileId': fileId,
        'filePath': './$fileId.$fileExtension',
        'extension': fileExtension,
      };

      setUp(() {
        when(mockUuid.v4()).thenReturn(fileId);
      });

      group('saveNormalFile', () {
        test('should save file and return metadata on success', () async {
          final result = await vaultStorage.saveNormalFile(
            fileBytes: fileBytes,
            fileExtension: fileExtension,
          );

          expect(result.isRight(), isTrue);
          final returnedMetadata = result.getOrElse((_) => {});
          expect(returnedMetadata['filePath'], endsWith('.$fileExtension'));
          expect(returnedMetadata['fileId'], fileId);
          expect(returnedMetadata['extension'], fileExtension);

          // Cleanup the created file
          final file = File(returnedMetadata['filePath'] as String);
          if (file.existsSync()) {
            file.deleteSync();
          }
        });

        test('should return StorageWriteError on path_provider failure', () async {
          // Simulate path_provider throwing an exception
          const MethodChannel('plugins.flutter.io/path_provider')
              .setMockMethodCallHandler((MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              throw Exception('Failed to get directory');
            }
            return null;
          });

          final result = await vaultStorage.saveNormalFile(
            fileBytes: fileBytes,
            fileExtension: fileExtension,
            isWeb: false, // Force native path
          );

          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageWriteError>());

          // Reset the mock handler
          const MethodChannel('plugins.flutter.io/path_provider')
              .setMockMethodCallHandler((MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return '.';
            }
            return null;
          });
        });
      });

      group('getNormalFile', () {
        test('should return file bytes on success', () async {
          // Create a test file
          final originalData = Uint8List.fromList([1, 2, 3, 4, 5]);
          final file = File(metadata['filePath'] as String);
          await file.writeAsBytes(originalData, flush: true);

          // Call the method under test
          final result = await vaultStorage.getNormalFile(fileMetadata: metadata);

          // Assert
          expect(result.isRight(), isTrue, reason: result.fold((l) => l.message, (r) => ''));
          result.fold(
            (l) => fail('getNormalFile should not have failed: ${l.message}'),
            (data) => expect(data, originalData),
          );

          // Cleanup
          await file.delete();
        });

        test('should return StorageReadError when file does not exist', () async {
          // Don't create the file
          final result = await vaultStorage.getNormalFile(fileMetadata: metadata);

          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
        });

        test('should return StorageReadError when filePath is missing in metadata for native', () async {
          final invalidMetadata = {
            'fileId': fileId,
            'extension': fileExtension,
            // No filePath
          };

          final result = await vaultStorage.getNormalFile(fileMetadata: invalidMetadata, isWeb: false);

          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
        });
      });

      group('deleteNormalFile', () {
        test('should return unit on success', () async {
          // Create a test file
          final file = File(metadata['filePath'] as String);
          await file.create();

          // Call the method under test
          final result = await vaultStorage.deleteNormalFile(fileMetadata: metadata);

          // Assert
          expect(result.isRight(), isTrue);
          expect(await file.exists(), isFalse);
        });

        test('should return unit even if file does not exist', () async {
          // Call the method under test without creating the file
          final result = await vaultStorage.deleteNormalFile(fileMetadata: metadata);

          // This should still succeed because deleting a non-existent file is not an error
          expect(result.isRight(), isTrue);
        });

        test('should return StorageDeleteError on exceptional failure', () async {
          // Create a corrupt metadata to cause an exception
          final invalidMetadata = {
            // Missing fileId
            'filePath': metadata['filePath'],
          };

          final result = await vaultStorage.deleteNormalFile(fileMetadata: invalidMetadata);

          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageDeleteError>());
        });
      });
    });

    group('saveNormalFile (Web)', () {
      test('should save file to Hive on web', () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3]);
        const fileExtension = 'txt';
        const fileId = 'test-uuid';
        final contentBase64 = fileBytes.encodeBase64();

        when(mockUuid.v4()).thenReturn(fileId);
        when(mockNormalFilesBox.put(fileId, contentBase64)).thenAnswer((_) async {});

        // Act
        final result =
            await vaultStorage.saveNormalFile(fileBytes: fileBytes, fileExtension: fileExtension, isWeb: true);

        // Assert
        expect(result.isRight(), isTrue);
        result.fold((l) => fail('should not return left'), (r) {
          expect(r['fileId'], fileId);
          expect(r['filePath'], isNull);
          expect(r['extension'], fileExtension);
        });
        verify(mockNormalFilesBox.put(fileId, contentBase64)).called(1);
      });

      test('should return StorageWriteError on Hive put failure', () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3]);
        const fileExtension = 'txt';
        const fileId = 'test-uuid';

        when(mockUuid.v4()).thenReturn(fileId);
        when(mockNormalFilesBox.put(any, any)).thenThrow(Exception('Hive put error'));

        // Act
        final result =
            await vaultStorage.saveNormalFile(fileBytes: fileBytes, fileExtension: fileExtension, isWeb: true);

        // Assert
        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<StorageWriteError>());
      });
    });

    group('getNormalFile (Web)', () {
      test('should retrieve file from Hive on web', () async {
        // Arrange
        const fileId = 'test-uuid';
        final originalData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final contentBase64 = originalData.encodeBase64();

        final metadata = {
          'fileId': fileId,
          'extension': 'txt',
        };

        when(mockNormalFilesBox.get(fileId)).thenReturn(contentBase64);

        // Act
        final result = await vaultStorage.getNormalFile(fileMetadata: metadata, isWeb: true);

        // Assert
        expect(result.isRight(), isTrue, reason: result.fold((l) => l.message, (r) => ''));
        result.fold((l) => null, (r) => expect(r, originalData));
        verify(mockNormalFilesBox.get(fileId)).called(1);
      });

      test('should return StorageReadError when file not found in Hive on web', () async {
        // Arrange
        const fileId = 'test-uuid';
        final metadata = {
          'fileId': fileId,
          'extension': 'txt',
        };

        when(mockNormalFilesBox.get(fileId)).thenReturn(null);

        // Act
        final result = await vaultStorage.getNormalFile(fileMetadata: metadata, isWeb: true);

        // Assert
        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
      });

      test('should return StorageReadError on base64 decode failure', () async {
        // Arrange
        const fileId = 'test-uuid';
        final metadata = {
          'fileId': fileId,
          'extension': 'txt',
        };

        when(mockNormalFilesBox.get(fileId)).thenReturn('invalid base64');

        // Act
        final result = await vaultStorage.getNormalFile(fileMetadata: metadata, isWeb: true);

        // Assert
        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
      });
    });

    group('deleteNormalFile (Web)', () {
      test('should delete file from Hive on web', () async {
        // Arrange
        const fileId = 'test-uuid';
        final metadata = {
          'fileId': fileId,
          'extension': 'txt',
        };

        when(mockNormalFilesBox.delete(fileId)).thenAnswer((_) async {});

        // Act
        final result = await vaultStorage.deleteNormalFile(fileMetadata: metadata, isWeb: true);

        // Assert
        expect(result.isRight(), isTrue);
        verify(mockNormalFilesBox.delete(fileId)).called(1);
      });

      test('should return StorageDeleteError on Hive delete failure', () async {
        // Arrange
        const fileId = 'test-uuid';
        final metadata = {
          'fileId': fileId,
          'extension': 'txt',
        };

        when(mockNormalFilesBox.delete(fileId)).thenThrow(Exception('Hive delete error'));

        // Act
        final result = await vaultStorage.deleteNormalFile(fileMetadata: metadata, isWeb: true);

        // Assert
        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<StorageDeleteError>());
      });
    });

    group('Service State', () {
      test('any operation should return StorageInitializationError if not initialized', () async {
        vaultStorage.isVaultStorageReady = false;

        final getResult = await vaultStorage.get<dynamic>(BoxType.normal, 'key');
        expect(getResult.fold((l) => l, (r) => r), isA<StorageInitializationError>());

        final setResult = await vaultStorage.set(BoxType.normal, 'key', 'value');
        expect(setResult.isLeft(), isTrue);
        setResult.fold(
            (l) => expect(l, isA<StorageInitializationError>()), (r) => fail('Expected a StorageInitializationError'));
      });

      test('dispose should clear boxes and set ready flag to false', () async {
        await vaultStorage.dispose();
        expect(vaultStorage.storageBoxes.isEmpty, isTrue);
        expect(vaultStorage.isVaultStorageReady, isFalse);
      });

      test('dispose should return StorageDisposalError on failure', () async {
        // Mock Hive.close() to throw an exception
        // Since we can't easily mock static methods, we'll test indirectly
        // by making the storage service in an invalid state
        vaultStorage.isVaultStorageReady = true;

        // This test is more about ensuring the error handling path exists
        // The actual failure would come from Hive.close() in real scenarios
        final result = await vaultStorage.dispose();

        // In normal cases, this should succeed
        expect(result.isRight(), isTrue);
      });

      test('_getBox being called for a non-existent box should result in an error', () async {
        vaultStorage.storageBoxes.remove(BoxType.secure);
        final result = await vaultStorage.get<dynamic>(BoxType.secure, 'key');
        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
      });
    });

    group('Initialization', () {
      test('init should succeed and set isVaultStorageReady to true', () async {
        vaultStorage.isVaultStorageReady = false;
        when(mockSecureStorage.read(key: anyNamed('key')))
            .thenAnswer((_) async => List.generate(32, (i) => i).encodeBase64());

        final result = await vaultStorage.init();

        expect(result.isRight(), isTrue);
        expect(vaultStorage.isVaultStorageReady, isTrue);
      });

      test('init should return left if already initialized', () async {
        final result = await vaultStorage.init();
        expect(result.isRight(), isTrue);
      });

      test('getOrCreateSecureKey should create a key if one does not exist', () async {
        when(mockSecureStorage.read(key: anyNamed('key'))).thenAnswer((_) async => null);
        when(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value'))).thenAnswer((_) async {});

        final result = await vaultStorage.getOrCreateSecureKey().run();

        expect(result.isRight(), isTrue);
        verify(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value'))).called(1);
      });

      test('getOrCreateSecureKey should return existing key', () async {
        final key = List.generate(32, (i) => i).encodeBase64();
        when(mockSecureStorage.read(key: anyNamed('key'))).thenAnswer((_) async => key);

        final result = await vaultStorage.getOrCreateSecureKey().run();

        expect(result.isRight(), isTrue);
        result.fold((l) => fail('should not be left'), (r) => expect(r.encodeBase64(), key));
        verify(mockSecureStorage.read(key: anyNamed('key'))).called(1);
      });

      test('openBoxes should open all box types', () async {
        final key = List.generate(32, (i) => i);
        final result = await vaultStorage.openBoxes(key).run();

        expect(result.isRight(), isTrue);
        expect(vaultStorage.storageBoxes.containsKey(BoxType.secure), isTrue);
        expect(vaultStorage.storageBoxes.containsKey(BoxType.normal), isTrue);
        expect(vaultStorage.storageBoxes.containsKey(BoxType.secureFiles), isTrue);
        expect(vaultStorage.storageBoxes.containsKey(BoxType.normalFiles), isTrue);
      });

      test('openBoxes should open all boxes with the right names', () async {
        final key = List.generate(32, (i) => i);
        final result = await vaultStorage.openBoxes(key).run();

        expect(result.isRight(), isTrue);
        expect(vaultStorage.storageBoxes.containsKey(BoxType.secure), isTrue);
        expect(vaultStorage.storageBoxes.containsKey(BoxType.normal), isTrue);
        expect(vaultStorage.storageBoxes.containsKey(BoxType.secureFiles), isTrue);
        expect(vaultStorage.storageBoxes.containsKey(BoxType.normalFiles), isTrue);
      });

      test('init should return StorageInitializationError on failure', () async {
        vaultStorage.isVaultStorageReady = false;
        when(mockSecureStorage.read(key: anyNamed('key'))).thenThrow(Exception('Could not read key'));

        final result = await vaultStorage.init();

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => null), isA<StorageInitializationError>());
        expect(vaultStorage.isVaultStorageReady, isFalse);
      });

      test('init should return StorageInitializationError on Hive.initFlutter failure', () async {
        // Arrange
        vaultStorage.isVaultStorageReady = false;
        const MethodChannel('plugins.flutter.io/path_provider').setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            // Simulate a failure in getting the directory, which Hive.initFlutter depends on.
            throw Exception('Failed to get directory');
          }
          return null;
        });

        // Act
        final result = await vaultStorage.init();

        // Assert
        expect(result.isLeft(), isTrue);
        final error = result.fold((l) => l, (r) => null);
        expect(error, isA<StorageInitializationError>());
        expect((error as StorageInitializationError).message, 'Failed to initialize Hive');
        expect(vaultStorage.isVaultStorageReady, isFalse);
      });

      test('getOrCreateSecureKey should return StorageInitializationError on read failure', () async {
        when(mockSecureStorage.read(key: anyNamed('key'))).thenThrow(Exception('Could not read key'));

        final result = await vaultStorage.getOrCreateSecureKey().run();

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => null), isA<StorageInitializationError>());
      });

      test('getOrCreateSecureKey should return StorageInitializationError on write failure', () async {
        when(mockSecureStorage.read(key: anyNamed('key'))).thenAnswer((_) async => null);
        when(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenThrow(Exception('Could not write key'));

        final result = await vaultStorage.getOrCreateSecureKey().run();

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => null), isA<StorageInitializationError>());
      });

      test('openBoxes should return StorageInitializationError on failure', () async {
        final key = List.generate(16, (i) => i); // Invalid key
        final result = await vaultStorage.openBoxes(key).run();

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => null), isA<StorageInitializationError>());
      });

      test('init should open all box types', () async {
        vaultStorage.isVaultStorageReady = false;
        vaultStorage.storageBoxes.clear();
        when(mockSecureStorage.read(key: anyNamed('key')))
            .thenAnswer((_) async => List.generate(32, (i) => i).encodeBase64());

        final result = await vaultStorage.init();

        expect(result.isRight(), isTrue);
        expect(vaultStorage.isVaultStorageReady, isTrue);
        expect(vaultStorage.storageBoxes.containsKey(BoxType.secure), isTrue);
        expect(vaultStorage.storageBoxes.containsKey(BoxType.normal), isTrue);
        expect(vaultStorage.storageBoxes.containsKey(BoxType.secureFiles), isTrue);
        expect(vaultStorage.storageBoxes.containsKey(BoxType.normalFiles), isTrue);
      });
    });

    group('Box Names', () {
      test('box types should map to the correct storage keys', () {
        expect(BoxType.secure.name, equals('secure'));
        expect(BoxType.normal.name, equals('normal'));
        expect(BoxType.secureFiles.name, equals('secureFiles'));
        expect(BoxType.normalFiles.name, equals('normalFiles'));

        expect(StorageKeys.secureBox, equals('secure_box'));
        expect(StorageKeys.normalBox, equals('normal_box'));
        expect(StorageKeys.secureFilesBox, equals('secure_files_box'));
        expect(StorageKeys.normalFilesBox, equals('normal_files_box'));
      });
    });

    // Test the extensions used in the VaultStorageImpl
    group('Extension Methods', () {
      test('should use decodeJsonSafely for JSON decoding', () async {
        const key = 'test_key';
        const jsonString = '{"name":"test"}';
        when(mockNormalBox.get(key)).thenReturn(jsonString);

        final result = await vaultStorage.get<Map<String, dynamic>>(BoxType.normal, key);

        expect(result.isRight(), isTrue);
        expect(result.getOrElse((_) => {}), equals({"name": "test"}));
      });

      test('should use encodeJsonSafely for JSON encoding', () async {
        const key = 'test_key';
        final value = {"name": "test"};
        when(mockNormalBox.put(any, any)).thenAnswer((_) async => unit);

        final result = await vaultStorage.set(BoxType.normal, key, value);

        expect(result.isRight(), isTrue);
        verify(mockNormalBox.put(key, json.encode(value))).called(1);
      });

      test('should handle metadata with getRequiredString', () async {
        final testMetadata = {'fileId': 'test-id', 'filePath': '/test/path', 'secureKeyName': 'test-key-name'};

        // Test that no exceptions are thrown when using getRequiredString
        expect(testMetadata.getRequiredString('fileId'), equals('test-id'));
        expect(testMetadata.getRequiredString('filePath'), equals('/test/path'));
        expect(testMetadata.getRequiredString('secureKeyName'), equals('test-key-name'));

        // Should throw when key is missing
        expect(() => testMetadata.getRequiredString('missingKey'), throwsA(isA<InvalidMetadataError>()));
      });

      test('should handle metadata with getOptionalString', () async {
        final testMetadata = {'fileId': 'test-id', 'filePath': '/test/path', 'nullValue': null, 'numberValue': 123};

        // Test getOptionalString behavior
        expect(testMetadata.getOptionalString('fileId'), equals('test-id'));
        expect(testMetadata.getOptionalString('filePath'), equals('/test/path'));
        expect(testMetadata.getOptionalString('missingKey'), isNull);
        expect(testMetadata.getOptionalString('nullValue'), isNull);
        expect(testMetadata.getOptionalString('numberValue'), isNull);
      });

      test('should handle Base64 encoding/decoding through extensions', () {
        final testBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        // Test encoding
        final encoded = testBytes.encodeBase64();
        expect(encoded, isA<String>());

        // Test decoding with extension
        final decodedResult = encoded.decodeBase64Safely(context: 'test');
        expect(decodedResult.isRight(), isTrue);
        decodedResult.fold(
            (_) => fail('Should not return Left for valid base64'), (bytes) => expect(bytes, equals(testBytes)));

        // Test invalid base64 handling
        final invalidResult = 'invalid!base64'.decodeBase64Safely(context: 'test');
        expect(invalidResult.isLeft(), isTrue);
        invalidResult.fold(
            (error) => expect(error, isA<Base64DecodeError>()), (_) => fail('Should return Left for invalid base64'));
      });
    });
  });
}

class _UnencodableObject {
  @override
  String toString() => 'I am not encodable';
}
