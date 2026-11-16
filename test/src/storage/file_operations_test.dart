import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/entities/secure_file_request.dart';
import 'package:vault_storage/src/entities/secure_file_stream_request.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/storage/file_operations.dart';

import '../../mocks.dart';
import '../../test_context.dart';

void main() {
  group('FileOperations', () {
    late FileOperations fileOperations;
    late TestContext testContext;

    setUpAll(() {
      MocksHelper.registerFallbackValues();
    });

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
      fileOperations = FileOperations();
    });

    tearDown(() {
      testContext.tearDownCommon();
    });

    group('saveSecureFile', () {
      test('should save secure file successfully on native platforms', () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileExtension = 'txt';
        const testFileId = 'test-file-id';

        when(() => testContext.mockUuid.v4()).thenReturn(testFileId);
        when(
          () => testContext.mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final result = await fileOperations.saveSecureFile(
          SecureFileRequest(
            fileBytes: fileBytes,
            fileExtension: fileExtension,
            services: testContext.fileServices(isWeb: false),
          ),
        );

        // Assert
        expect(result['fileId'], equals(testFileId));
        expect(result['extension'], equals(fileExtension));
        expect(result['filePath'], contains(testFileId));
        expect(result['filePath'], contains('.enc'));
        expect(result['secureKeyName'], equals('file_key_$testFileId'));
        expect(result.containsKey('nonce'), isTrue);
        expect(result.containsKey('mac'), isTrue);

        verify(() => testContext.mockUuid.v4()).called(1);
        verify(
          () => testContext.mockSecureStorage.write(
            key: 'file_key_$testFileId',
            value: any(named: 'value'),
          ),
        ).called(1);
      });

      test('should save secure file successfully on web platform', () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileExtension = 'txt';
        const testFileId = 'test-file-id';
        final mockBox = testContext.mockSecureFilesBox;

        when(() => testContext.mockUuid.v4()).thenReturn(testFileId);
        when(
          () => testContext.mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});
        when(() => mockBox.put(any<String>(), any<String>())).thenAnswer((_) async {});

        // Act
        final result = await fileOperations.saveSecureFile(
          SecureFileRequest(
            fileBytes: fileBytes,
            fileExtension: fileExtension,
            services: testContext.fileServices(isWeb: true),
          ),
        );

        // Assert
        expect(result['fileId'], equals(testFileId));
        expect(result['extension'], equals(fileExtension));
        expect(result['filePath'], isNull); // Web doesn't use file paths
        expect(result['secureKeyName'], equals('file_key_$testFileId'));
        expect(result.containsKey('nonce'), isTrue);
        expect(result.containsKey('mac'), isTrue);

        verify(() => testContext.mockUuid.v4()).called(1);
        verify(
          () => testContext.mockSecureStorage.write(
            key: 'file_key_$testFileId',
            value: any(named: 'value'),
          ),
        ).called(1);
        verify(() => mockBox.put(testFileId, any<Object?>())).called(1);
      });

      test('should throw StorageWriteError when encryption fails', () async {
        // Arrange
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileExtension = 'txt';

        when(() => testContext.mockUuid.v4()).thenThrow(Exception('UUID generation failed'));

        // Act & Assert
        expect(
          () => fileOperations.saveSecureFile(
            SecureFileRequest(
              fileBytes: fileBytes,
              fileExtension: fileExtension,
              services: testContext.fileServices(isWeb: false),
            ),
          ),
          throwsA(isA<StorageWriteError>()),
        );
      });
    });

    group('saveSecureFileStream (streaming)', () {
      test('should throw StorageWriteError when chunkSize is zero', () async {
        // Arrange
        final stream = Stream<List<int>>.fromIterable([
          Uint8List.fromList([1, 2, 3]),
        ]);
        when(() => testContext.mockUuid.v4()).thenReturn('chunk-test-id');

        // Act & Assert
        expect(
          () => fileOperations.saveSecureFileStream(
            SecureFileStreamRequest(
              stream: stream,
              fileExtension: 'bin',
              services: testContext.fileServices(isWeb: true),
              chunkSize: 0,
            ),
          ),
          throwsA(
            isA<StorageWriteError>().having(
              (e) => e.message,
              'message',
              contains('Chunk size must be positive'),
            ),
          ),
        );
      });

      test('should throw StorageWriteError when chunkSize is negative', () async {
        // Arrange
        final stream = Stream<List<int>>.fromIterable([
          Uint8List.fromList([1, 2, 3]),
        ]);
        when(() => testContext.mockUuid.v4()).thenReturn('chunk-test-id');

        // Act & Assert
        expect(
          () => fileOperations.saveSecureFileStream(
            SecureFileStreamRequest(
              stream: stream,
              fileExtension: 'bin',
              services: testContext.fileServices(isWeb: true),
              chunkSize: -1,
            ),
          ),
          throwsA(
            isA<StorageWriteError>().having(
              (e) => e.message,
              'message',
              contains('Chunk size must be positive'),
            ),
          ),
        );
      });

      test('should save streaming secure file successfully on web', () async {
        // Arrange
        final parts = [
          Uint8List.fromList(.generate(1024, (i) => i % 256)),
          Uint8List.fromList(.generate(2048, (i) => (i + 1) % 256)),
        ];
        final stream = Stream<List<int>>.fromIterable(parts);
        const fileExtension = 'bin';
        const testFileId = 'stream-id';

        when(() => testContext.mockUuid.v4()).thenReturn(testFileId);
        when(
          () => testContext.mockSecureFilesBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});
        when(
          () => testContext.mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final meta = await fileOperations.saveSecureFileStream(
          SecureFileStreamRequest(
            stream: stream,
            fileExtension: fileExtension,
            services: testContext.fileServices(isWeb: true),
            chunkSize: 1024,
          ),
        );

        // Assert
        expect(meta['fileId'], equals(testFileId));
        expect(meta['streaming'], isTrue);
        expect(meta['chunkCount'], greaterThan(0));
        verify(
          () => testContext.mockSecureFilesBox.put(any<String>(), any<String>()),
        ).called(greaterThan(0));
        verify(
          () => testContext.mockSecureStorage.write(
            key: 'file_key_$testFileId',
            value: any(named: 'value'),
          ),
        ).called(1);
      });
    });
  });
}
