// test/unit/vault_storage/normal_file_operations_test.dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vault_storage/src/errors/storage_error.dart';
import 'package:vault_storage/src/extensions/storage_extensions.dart';
import '../../test_context.dart';

void main() {
  final ctx = TestContext();

  setUp(ctx.setUpCommon);
  tearDown(ctx.tearDownCommon);

  group('Normal File Storage Operations', () {
    final fileBytes = Uint8List.fromList([1, 2, 3]);
    const fileExtension = 'txt';
    const fileId = 'test-uuid';
    final metadata = {
      'fileId': fileId,
      'filePath': './$fileId.$fileExtension',
      'extension': fileExtension,
    };

    setUp(() {
      when(ctx.mockUuid.v4()).thenReturn(fileId);
    });

    group('saveNormalFile', () {
      test('should save file and return metadata on success', () async {
        final result = await ctx.vaultStorage.saveNormalFile(
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

      test('should return StorageWriteError on path_provider failure',
          () async {
        // Simulate path_provider throwing an exception
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              throw Exception('Failed to get directory');
            }
            return null;
          },
        );

        final result = await ctx.vaultStorage.saveNormalFile(
          fileBytes: fileBytes,
          fileExtension: fileExtension,
          isWeb: false, // Force native path
        );

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<StorageWriteError>());

        // Reset the mock handler
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return '.';
            }
            return null;
          },
        );
      });
    });

    group('getNormalFile', () {
      test('should return file bytes on success', () async {
        // Create a test file
        final originalData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final file = File(metadata['filePath'] as String);
        await file.writeAsBytes(originalData, flush: true);

        // Call the method under test
        final result =
            await ctx.vaultStorage.getNormalFile(fileMetadata: metadata);

        // Assert
        expect(result.isRight(), isTrue,
            reason: result.fold((l) => l.message, (r) => ''));
        result.fold(
          (l) => fail('getNormalFile should not have failed: ${l.message}'),
          (data) => expect(data, originalData),
        );

        // Cleanup
        await file.delete();
      });

      test('should return StorageReadError when file does not exist', () async {
        // Don't create the file
        final result =
            await ctx.vaultStorage.getNormalFile(fileMetadata: metadata);

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
      });

      test(
          'should return StorageReadError when filePath is missing in metadata for native',
          () async {
        final invalidMetadata = {
          'fileId': fileId,
          'extension': fileExtension,
          // No filePath
        };

        final result = await ctx.vaultStorage
            .getNormalFile(fileMetadata: invalidMetadata, isWeb: false);

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
        final result =
            await ctx.vaultStorage.deleteNormalFile(fileMetadata: metadata);

        // Assert
        expect(result.isRight(), isTrue);
        expect(await file.exists(), isFalse);
      });

      test('should return unit even if file does not exist', () async {
        // Call the method under test without creating the file
        final result =
            await ctx.vaultStorage.deleteNormalFile(fileMetadata: metadata);

        // This should still succeed because deleting a non-existent file is not an error
        expect(result.isRight(), isTrue);
      });

      test('should return StorageDeleteError on exceptional failure', () async {
        // Create a corrupt metadata to cause an exception
        final invalidMetadata = {
          // Missing fileId
          'filePath': metadata['filePath'],
        };

        final result = await ctx.vaultStorage
            .deleteNormalFile(fileMetadata: invalidMetadata);

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<StorageDeleteError>());
      });
    });

    group('Web Operations', () {
      group('saveNormalFile (Web)', () {
        test('should save file to Hive on web', () async {
          // Arrange
          final contentBase64 = fileBytes.encodeBase64();

          when(ctx.mockNormalFilesBox.put(fileId, contentBase64))
              .thenAnswer((_) async {});

          // Act
          final result = await ctx.vaultStorage.saveNormalFile(
              fileBytes: fileBytes, fileExtension: fileExtension, isWeb: true);

          // Assert
          expect(result.isRight(), isTrue);
          result.fold((l) => fail('should not return left'), (r) {
            expect(r['fileId'], fileId);
            expect(r['filePath'], isNull);
            expect(r['extension'], fileExtension);
          });
          verify(ctx.mockNormalFilesBox.put(fileId, contentBase64)).called(1);
        });

        test('should return StorageWriteError on Hive put failure', () async {
          // Arrange
          when(ctx.mockNormalFilesBox.put(any, any))
              .thenThrow(Exception('Hive put error'));

          // Act
          final result = await ctx.vaultStorage.saveNormalFile(
              fileBytes: fileBytes, fileExtension: fileExtension, isWeb: true);

          // Assert
          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageWriteError>());
        });
      });

      group('getNormalFile (Web)', () {
        test('should retrieve file from Hive on web', () async {
          // Arrange
          final originalData = Uint8List.fromList([1, 2, 3, 4, 5]);
          final contentBase64 = originalData.encodeBase64();

          final webMetadata = {
            'fileId': fileId,
            'extension': 'txt',
          };

          when(ctx.mockNormalFilesBox.get(fileId)).thenReturn(contentBase64);

          // Act
          final result = await ctx.vaultStorage
              .getNormalFile(fileMetadata: webMetadata, isWeb: true);

          // Assert
          expect(result.isRight(), isTrue,
              reason: result.fold((l) => l.message, (r) => ''));
          result.fold((l) => null, (r) => expect(r, originalData));
          verify(ctx.mockNormalFilesBox.get(fileId)).called(1);
        });

        test(
            'should return StorageReadError when file not found in Hive on web',
            () async {
          // Arrange
          final webMetadata = {
            'fileId': fileId,
            'extension': 'txt',
          };

          when(ctx.mockNormalFilesBox.get(fileId)).thenReturn(null);

          // Act
          final result = await ctx.vaultStorage
              .getNormalFile(fileMetadata: webMetadata, isWeb: true);

          // Assert
          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
        });

        test('should return StorageReadError on base64 decode failure',
            () async {
          // Arrange
          final webMetadata = {
            'fileId': fileId,
            'extension': 'txt',
          };

          when(ctx.mockNormalFilesBox.get(fileId)).thenReturn('invalid base64');

          // Act
          final result = await ctx.vaultStorage
              .getNormalFile(fileMetadata: webMetadata, isWeb: true);

          // Assert
          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
        });
      });

      group('deleteNormalFile (Web)', () {
        test('should delete file from Hive on web', () async {
          // Arrange
          final webMetadata = {
            'fileId': fileId,
            'extension': 'txt',
          };

          when(ctx.mockNormalFilesBox.delete(fileId)).thenAnswer((_) async {});

          // Act
          final result = await ctx.vaultStorage
              .deleteNormalFile(fileMetadata: webMetadata, isWeb: true);

          // Assert
          expect(result.isRight(), isTrue);
          verify(ctx.mockNormalFilesBox.delete(fileId)).called(1);
        });

        test('should return StorageDeleteError on Hive delete failure',
            () async {
          // Arrange
          final webMetadata = {
            'fileId': fileId,
            'extension': 'txt',
          };

          when(ctx.mockNormalFilesBox.delete(fileId))
              .thenThrow(Exception('Hive delete error'));

          // Act
          final result = await ctx.vaultStorage
              .deleteNormalFile(fileMetadata: webMetadata, isWeb: true);

          // Assert
          expect(result.isLeft(), isTrue);
          expect(result.fold((l) => l, (r) => r), isA<StorageDeleteError>());
        });
      });
    });
  });
}
