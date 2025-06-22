// test/unit/vault_storage/secure_file_operations_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vault_storage/src/errors/storage_error.dart';
import 'package:vault_storage/src/extensions/storage_extensions.dart';
import '../../test_context.dart';

void main() {
  final ctx = TestContext();

  setUp(ctx.setUpCommon);
  tearDown(ctx.tearDownCommon);

  group('Secure File Storage Operations', () {
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
      when(ctx.mockUuid.v4()).thenReturn(fileId);
    });

    group('saveSecureFile', () {
      test('should save file and return metadata on success', () async {
        when(ctx.mockSecureStorage
                .write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});

        final result = await ctx.vaultStorage.saveSecureFile(
          fileBytes: fileBytes,
          fileExtension: fileExtension,
        );

        expect(result.isRight(), isTrue);
        final returnedMetadata = result.getOrElse((_) => {});
        expect(returnedMetadata['filePath'], endsWith('.enc'));
        expect(returnedMetadata['secureKeyName'], isA<String>());
        verify(ctx.mockSecureStorage
                .write(key: anyNamed('key'), value: anyNamed('value')))
            .called(1);

        // Cleanup the created file
        final file = File(returnedMetadata['filePath'] as String);
        if (file.existsSync()) {
          file.deleteSync();
        }
      });

      test('should return StorageWriteError on failure', () async {
        when(ctx.mockSecureStorage
                .write(key: anyNamed('key'), value: anyNamed('value')))
            .thenThrow(Exception('Storage write error'));

        final result = await ctx.vaultStorage.saveSecureFile(
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
        final originalData =
            Uint8List.fromList(utf8.encode('some secret data'));
        final secretKey = await algorithm.newSecretKey();
        final keyBytes = await secretKey.extractBytes();
        final secretBox =
            await algorithm.encrypt(originalData, secretKey: secretKey);

        // Setup mocks and file system with the valid data
        final file = File(metadata['filePath'] as String);
        await file.writeAsBytes(secretBox.cipherText, flush: true);

        when(ctx.mockSecureStorage
                .read(key: metadata['secureKeyName'] as String))
            .thenAnswer((_) async => keyBytes.encodeBase64());

        final validMetadata = {
          'fileId': fileId,
          'filePath': metadata['filePath'],
          'secureKeyName': metadata['secureKeyName'],
          'nonce': secretBox.nonce.encodeBase64(),
          'mac': secretBox.mac.bytes.encodeBase64(),
        };

        // Call the method under test
        final result =
            await ctx.vaultStorage.getSecureFile(fileMetadata: validMetadata);

        // Assert
        expect(result.isRight(), isTrue,
            reason: result.fold((l) => l.message, (r) => ''));
        result.fold(
          (l) => fail('getSecureFile should not have failed: ${l.message}'),
          (decryptedData) => expect(decryptedData, originalData),
        );

        // Cleanup
        await file.delete();
      });

      test('should return StorageReadError if key not in secure storage',
          () async {
        final file = File(metadata['filePath'] as String);
        await file.writeAsBytes(Uint8List.fromList([10, 11, 12]), flush: true);
        when(ctx.mockSecureStorage
                .read(key: metadata['secureKeyName'] as String))
            .thenAnswer((_) async => null);

        final result =
            await ctx.vaultStorage.getSecureFile(fileMetadata: metadata);

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());

        await file.delete();
      });

      test('should return StorageReadError on file read failure', () async {
        // Don't create the file, so read will fail
        when(ctx.mockSecureStorage
                .read(key: metadata['secureKeyName'] as String))
            .thenAnswer(
                (_) async => List.generate(32, (i) => i).encodeBase64());

        final result =
            await ctx.vaultStorage.getSecureFile(fileMetadata: metadata);

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
      });
    });

    group('deleteSecureFile', () {
      test('should return unit on success', () async {
        final file = File(metadata['filePath'] as String);
        await file.create();
        when(ctx.mockSecureStorage
                .delete(key: metadata['secureKeyName'] as String))
            .thenAnswer((_) async {});

        final result =
            await ctx.vaultStorage.deleteSecureFile(fileMetadata: metadata);

        expect(result.isRight(), isTrue);
        expect(await file.exists(), isFalse);
        verify(ctx.mockSecureStorage
                .delete(key: metadata['secureKeyName'] as String))
            .called(1);
      });

      test('should return StorageDeleteError on failure', () async {
        when(ctx.mockSecureStorage
                .delete(key: metadata['secureKeyName'] as String))
            .thenThrow(Exception('Delete error'));

        final result =
            await ctx.vaultStorage.deleteSecureFile(fileMetadata: metadata);

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<StorageDeleteError>());
      });
    });

    group('Web Operations', () {
      group('saveSecureFile (Web)', () {
        test('should save file to Hive on web', () async {
          // Arrange
          final secretKey = await AesGcm.with256bits().newSecretKey();
          final keyBytes = await secretKey.extractBytes();
          final secretBox = await AesGcm.with256bits()
              .encrypt(fileBytes, secretKey: secretKey);
          final encryptedContentBase64 = secretBox.cipherText.encodeBase64();

          when(ctx.mockSecureStorage.write(
                  key: 'file_key_$fileId', value: keyBytes.encodeBase64()))
              .thenAnswer((_) async {});
          when(ctx.mockSecureFilesBox.put(fileId, encryptedContentBase64))
              .thenAnswer((_) async {});

          // Act
          final result = await ctx.vaultStorage.saveSecureFile(
              fileBytes: fileBytes, fileExtension: fileExtension, isWeb: true);

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
          final keyBytes =
              List.generate(32, (index) => index % 256); // 32 bytes exactly
          final secretKey = SecretKey(keyBytes);
          final originalData = Uint8List.fromList(utf8.encode('secret data'));
          final secretBox = await AesGcm.with256bits()
              .encrypt(originalData, secretKey: secretKey);
          final encryptedContentBase64 = secretBox.cipherText.encodeBase64();

          final webMetadata = {
            'fileId': fileId,
            'secureKeyName': 'file_key_$fileId',
            'nonce': secretBox.nonce.encodeBase64(),
            'mac': secretBox.mac.bytes.encodeBase64(),
          };

          when(ctx.mockSecureFilesBox.get(fileId))
              .thenReturn(encryptedContentBase64);
          when(ctx.mockSecureStorage.read(key: 'file_key_$fileId'))
              .thenAnswer((_) async => keyBytes.encodeBase64());

          // Act
          final result = await ctx.vaultStorage
              .getSecureFile(fileMetadata: webMetadata, isWeb: true);

          // Assert
          expect(result.isRight(), isTrue,
              reason: result.fold((l) => l.message, (r) => ''));
          result.fold((l) => null, (r) => expect(r, originalData));
        });

        test(
            'should return StorageReadError when file not found in Hive on web',
            () async {
          // Arrange
          final webMetadata = {
            'fileId': fileId,
            'secureKeyName': 'file_key_$fileId',
            'nonce': [1, 2, 3].encodeBase64(),
            'mac': [4, 5, 6].encodeBase64(),
          };

          when(ctx.mockSecureFilesBox.get(fileId)).thenReturn(null);

          // Act
          final result = await ctx.vaultStorage
              .getSecureFile(fileMetadata: webMetadata, isWeb: true);

          // Assert
          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
        });
      });

      group('deleteSecureFile (Web)', () {
        test('should delete file from Hive on web', () async {
          // Arrange
          final webMetadata = {
            'fileId': fileId,
            'secureKeyName': 'file_key_$fileId',
          };

          when(ctx.mockSecureFilesBox.delete(fileId)).thenAnswer((_) async {});
          when(ctx.mockSecureStorage.delete(key: 'file_key_$fileId'))
              .thenAnswer((_) async {});

          // Act
          final result = await ctx.vaultStorage
              .deleteSecureFile(fileMetadata: webMetadata, isWeb: true);

          // Assert
          expect(result.isRight(), isTrue);
          verify(ctx.mockSecureFilesBox.delete(fileId)).called(1);
          verify(ctx.mockSecureStorage.delete(key: 'file_key_$fileId'))
              .called(1);
        });
      });
    });
  });
}
