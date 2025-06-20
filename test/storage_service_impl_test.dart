import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/mockito.dart';
import 'package:storage_service/src/enum/storage_box_type.dart';
import 'package:storage_service/src/errors/storage_error.dart';
import 'package:storage_service/src/storage_service_impl.dart';

import 'mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageServiceImpl storageService;
  late MockFlutterSecureStorage mockSecureStorage;
  late MockUuid mockUuid;
  late MockBox<String> mockSecureBox;
  late MockBox<String> mockNormalBox;

  setUp(() {
    mockSecureStorage = MockFlutterSecureStorage();
    mockUuid = MockUuid();
    mockSecureBox = MockBox<String>();
    mockNormalBox = MockBox<String>();

    storageService = StorageServiceImpl(
      secureStorage: mockSecureStorage,
      uuid: mockUuid,
    );

    storageService.storageBoxes.addAll({
      BoxType.secure: mockSecureBox,
      BoxType.normal: mockNormalBox,
    });
    storageService.isStorageServiceReady = true;

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

  group('StorageServiceImpl Tests', () {
    group('Key-Value Storage', () {
      group('get', () {
        test('should return value when key exists', () async {
          const key = 'test_key';
          final value = {'data': 'test_data'};
          when(mockNormalBox.get(key)).thenReturn(jsonEncode(value));

          final result = await storageService.get<Map<String, dynamic>>(BoxType.normal, key);

          expect(result.isRight(), isTrue);
          expect(result.getOrElse((_) => {}), value);
        });

        test('should return null when key does not exist', () async {
          const key = 'non_existent_key';
          when(mockNormalBox.get(key)).thenReturn(null);

          final result = await storageService.get<dynamic>(BoxType.normal, key);

          expect(result.isRight(), isTrue);
          expect(result.getOrElse((_) => 'a'), isNull);
        });

        test('should return StorageReadError on failure', () async {
          const key = 'test_key';
          when(mockNormalBox.get(key)).thenThrow(Exception('Read error'));

          final result = await storageService.get<dynamic>(BoxType.normal, key);

          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
        });

        test('should return StorageSerializationError on json decoding error', () async {
          const key = 'test_key';
          when(mockNormalBox.get(key)).thenReturn('invalid json');

          final result = await storageService.get<dynamic>(BoxType.normal, key);

          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageSerializationError>());
        });
      });

      group('set', () {
        test('should return unit when value is set successfully', () async {
          const key = 'test_key';
          const value = {'data': 'test_data'};
          when(mockNormalBox.put(any, any)).thenAnswer((_) async => unit);

          final result = await storageService.set(BoxType.normal, key, value);

          expect(result.isRight(), isTrue);
          verify(mockNormalBox.put(key, jsonEncode(value))).called(1);
        });

        test('should return StorageWriteError on failure', () async {
          const key = 'test_key';
          const value = {'data': 'test_data'};
          when(mockNormalBox.put(any, any)).thenThrow(Exception('Write error'));

          final result = await storageService.set(BoxType.normal, key, value);

          expect(result.isLeft(), isTrue);
          result.fold(
            (l) => expect(l, isA<StorageWriteError>()),
            (r) => fail('Expected a StorageWriteError'),
          );
        });

        test('should return StorageSerializationError on json encoding error', () async {
          const key = 'test_key';
          final value = _UnencodableObject(); // This will throw JsonUnsupportedObjectError

          final result = await storageService.set(BoxType.normal, key, value);

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

          final result = await storageService.delete(BoxType.normal, key);

          expect(result.isRight(), isTrue);
          verify(mockNormalBox.delete(key)).called(1);
        });

        test('should return StorageDeleteError on failure', () async {
          const key = 'test_key';
          when(mockNormalBox.delete(key)).thenThrow(Exception('Delete error'));

          final result = await storageService.delete(BoxType.normal, key);

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

          final result = await storageService.clear(BoxType.normal);

          expect(result.isRight(), isTrue);
          verify(mockNormalBox.clear()).called(1);
        });

        test('should return StorageDeleteError on failure', () async {
          when(mockNormalBox.clear()).thenThrow(Exception('Clear error'));

          final result = await storageService.clear(BoxType.normal);

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
        'filePath': './$fileId.$fileExtension.enc',
        'secureKeyName': 'file_key_$fileId',
        'nonce': base64Url.encode([4, 5, 6]),
        'mac': base64Url.encode([7, 8, 9]),
      };

      setUp(() {
        when(mockUuid.v4()).thenReturn(fileId);
      });

      group('saveSecureFile', () {
        test('should save file and return metadata on success', () async {
          when(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value'))).thenAnswer((_) async {});

          final result = await storageService.saveSecureFile(
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

          final result = await storageService.saveSecureFile(
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
              .thenAnswer((_) async => base64Url.encode(keyBytes));

          final validMetadata = {
            'filePath': metadata['filePath'],
            'secureKeyName': metadata['secureKeyName'],
            'nonce': base64Url.encode(secretBox.nonce),
            'mac': base64Url.encode(secretBox.mac.bytes),
          };

          // Call the method under test
          final result = await storageService.getSecureFile(fileMetadata: validMetadata);

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

          final result = await storageService.getSecureFile(fileMetadata: metadata);

          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());

          await file.delete();
        });

        test('should return StorageReadError on file read failure', () async {
          // Don't create the file, so read will fail
          when(mockSecureStorage.read(key: metadata['secureKeyName'] as String))
              .thenAnswer((_) async => base64Url.encode(List.generate(32, (i) => i)));

          final result = await storageService.getSecureFile(fileMetadata: metadata);

          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
        });
      });

      group('deleteSecureFile', () {
        test('should return unit on success', () async {
          final file = File(metadata['filePath'] as String);
          await file.create();
          when(mockSecureStorage.delete(key: metadata['secureKeyName'] as String)).thenAnswer((_) async {});

          final result = await storageService.deleteSecureFile(fileMetadata: metadata);

          expect(result.isRight(), isTrue);
          expect(await file.exists(), isFalse);
          verify(mockSecureStorage.delete(key: metadata['secureKeyName'] as String)).called(1);
        });

        test('should return StorageDeleteError on failure', () async {
          when(mockSecureStorage.delete(key: metadata['secureKeyName'] as String)).thenThrow(Exception('Delete error'));

          final result = await storageService.deleteSecureFile(fileMetadata: metadata);

          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageDeleteError>());
        });
      });
    });

    group('Service State', () {
      test('any operation should return StorageInitializationError if not initialized', () async {
        storageService.isStorageServiceReady = false;

        final getResult = await storageService.get<dynamic>(BoxType.normal, 'key');
        expect(getResult.fold((l) => l, (r) => r), isA<StorageInitializationError>());

        final setResult = await storageService.set(BoxType.normal, 'key', 'value');
        expect(setResult.isLeft(), isTrue);
        setResult.fold((l) => expect(l, isA<StorageInitializationError>()),
            (r) => fail('Expected a StorageInitializationError()'));
      });

      test('dispose should clear boxes and set ready flag to false', () async {
        await storageService.dispose();
        expect(storageService.storageBoxes.isEmpty, isTrue);
        expect(storageService.isStorageServiceReady, isFalse);
      });

      test('_getBox being called for a non-existent box should result in an error', () async {
        storageService.storageBoxes.remove(BoxType.secure);
        final result = await storageService.get<dynamic>(BoxType.secure, 'key');
        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
      });
    });

    group('Initialization', () {
      test('init should succeed and set isStorageServiceReady to true', () async {
        storageService.isStorageServiceReady = false;
        when(mockSecureStorage.read(key: anyNamed('key')))
            .thenAnswer((_) async => base64UrlEncode(List.generate(32, (i) => i)));

        final result = await storageService.init();

        expect(result.isRight(), isTrue);
        expect(storageService.isStorageServiceReady, isTrue);
      });

      test('init should return left if already initialized', () async {
        final result = await storageService.init();
        expect(result.isRight(), isTrue);
      });

      test('getOrCreateSecureKey should create a key if one does not exist', () async {
        when(mockSecureStorage.read(key: anyNamed('key'))).thenAnswer((_) async => null);
        when(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value'))).thenAnswer((_) async {});

        final result = await storageService.getOrCreateSecureKey().run();

        expect(result.isRight(), isTrue);
        verify(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value'))).called(1);
      });

      test('getOrCreateSecureKey should return existing key', () async {
        final key = base64UrlEncode(List.generate(32, (i) => i));
        when(mockSecureStorage.read(key: anyNamed('key'))).thenAnswer((_) async => key);

        final result = await storageService.getOrCreateSecureKey().run();

        expect(result.isRight(), isTrue);
        result.fold((l) => fail('should not be left'), (r) => expect(base64UrlEncode(r), key));
        verify(mockSecureStorage.read(key: anyNamed('key'))).called(1);
      });

      test('openBoxes should open secure and normal boxes', () async {
        final key = List.generate(32, (i) => i);
        final result = await storageService.openBoxes(key).run();

        expect(result.isRight(), isTrue);
        expect(storageService.storageBoxes.containsKey(BoxType.secure), isTrue);
        expect(storageService.storageBoxes.containsKey(BoxType.normal), isTrue);
      });

      test('init should return StorageInitializationError on failure', () async {
        storageService.isStorageServiceReady = false;
        when(mockSecureStorage.read(key: anyNamed('key'))).thenThrow(Exception('Could not read key'));

        final result = await storageService.init();

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => null), isA<StorageInitializationError>());
        expect(storageService.isStorageServiceReady, isFalse);
      });

      test('getOrCreateSecureKey should return StorageInitializationError on read failure', () async {
        when(mockSecureStorage.read(key: anyNamed('key'))).thenThrow(Exception('Could not read key'));

        final result = await storageService.getOrCreateSecureKey().run();

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => null), isA<StorageInitializationError>());
      });

      test('getOrCreateSecureKey should return StorageInitializationError on write failure', () async {
        when(mockSecureStorage.read(key: anyNamed('key'))).thenAnswer((_) async => null);
        when(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenThrow(Exception('Could not write key'));

        final result = await storageService.getOrCreateSecureKey().run();

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => null), isA<StorageInitializationError>());
      });

      test('openBoxes should return StorageInitializationError on failure', () async {
        final key = List.generate(16, (i) => i); // Invalid key
        final result = await storageService.openBoxes(key).run();

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => null), isA<StorageInitializationError>());
      });
    });
  });
}

class _UnencodableObject {
  @override
  String toString() => 'I am not encodable';
}
