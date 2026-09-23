import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/storage/file_operations.dart';

import '../mocks.dart';
import '../test_context.dart';

void main() {
  test('8 MiB encrypted file round trip finishes within five seconds', () async {
    MocksHelper.registerFallbackValues();
    final context = TestContext()..setUpCommon();
    final directory = await Directory.systemTemp.createTemp('secure-stream-performance-');
    addTearDown(() async {
      context.tearDownCommon();
      await directory.delete(recursive: true);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => directory.path,
    );
    when(() => context.mockUuid.v4()).thenReturn('performance-file');
    String? encryptionKey;
    when(
      () => context.mockSecureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      encryptionKey = invocation.namedArguments[#value] as String?;
    });
    when(
      () => context.mockSecureStorage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => encryptionKey);
    final bytes = Uint8List.fromList(List<int>.generate(8 * 1024 * 1024, (index) => index % 251));
    final operations = FileOperations();
    final timer = Stopwatch()..start();
    final metadata = await operations.saveSecureFileStream(
      stream: Stream<List<int>>.value(bytes),
      fileExtension: 'bin',
      isWeb: false,
      secureStorage: context.mockSecureStorage,
      uuid: context.mockUuid,
      getBox: context.getBox,
    );
    final restored = await operations.getSecureFile(
      fileMetadata: metadata,
      isWeb: false,
      secureStorage: context.mockSecureStorage,
      getBox: context.getBox,
    );
    timer.stop();
    expect(restored, bytes);
    expect(metadata['chunkCount'], 4);
    expect(
      timer.elapsed,
      lessThan(const Duration(seconds: 5)),
      reason: 'Eight MiB must sustain at least 1.6 MiB/s, including encryption and disk I/O.',
    );
  });
}
