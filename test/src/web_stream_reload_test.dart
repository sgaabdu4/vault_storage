import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/entities/secure_file_stream_request.dart';
import 'package:vault_storage/src/storage/file_operations.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

import '../helpers/invocation_arguments.dart';
import '../mocks.dart';
import '../test_context.dart';

const _twoMiBAndMore = (2 << 20) + 10 * 1024;

void main() {
  group('a streamed secure file on the web path after its metadata box reloads', () {
    late TestContext testContext;
    late Directory hiveDirectory;

    setUpAll(MocksHelper.registerFallbackValues);

    setUp(() async {
      testContext = TestContext();
      testContext.setUpCommon();
      hiveDirectory = await Directory.systemTemp.createTemp('vault-web-reload');
      Hive.init(hiveDirectory.path);
    });

    tearDown(() async {
      testContext.tearDownCommon();
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    test('reads back every byte', () async {
      final storedChunks = <String, Object?>{};
      String? encodedKey;
      when(() => testContext.mockUuid.v4()).thenReturn('reloaded-file');
      when(() => testContext.mockSecureFilesBox.put(any<String>(), any<Object?>())).thenAnswer((
        invocation,
      ) async {
        storedChunks[firstPositionalName(invocation)] = invocation.positionalArguments[1];
      });
      when(
        () => testContext.mockSecureFilesBox.get(any<String>()),
      ).thenAnswer((invocation) async => storedChunks[invocation.positionalArguments[0]]);
      when(
        () => testContext.mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        encodedKey = namedStringValue(invocation);
      });
      when(
        () => testContext.mockSecureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => encodedKey);
      final original = Uint8List.fromList(.generate(_twoMiBAndMore, (index) => index % 251));
      final operations = FileOperations();
      final saved = await operations.saveSecureFileStream(
        SecureFileStreamRequest(
          stream: .value(original),
          fileExtension: 'bin',
          services: testContext.fileServices(isWeb: true),
        ),
      );
      expect(saved['chunkCount'], 2);

      LazyBox<Object?> box = await Hive.openLazyBox<Object?>('metadata');
      await box.put('file', saved);
      await box.close();
      box = await Hive.openLazyBox<Object?>('metadata');
      final reloaded = await box.get('file');
      when(() => testContext.mockSecureFilesBox.containsKey('file')).thenReturn(true);
      when(
        () => testContext.mockSecureFilesBox.get('file'),
      ).thenAnswer((_) async => StoredValue(reloaded, .native));

      final metadata = await testContext.vaultStorage.getFileMetadata('file', isSecure: true);

      expect(
        await operations.getSecureFile(
          fileMetadata: metadata,
          isWeb: true,
          secureStorage: testContext.mockSecureStorage,
          getBox: testContext.getBox,
        ),
        original,
      );
    });
  });
}
