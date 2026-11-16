import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/entities/secure_file_stream_request.dart';
import 'package:vault_storage/src/storage/file_operations.dart';

import '../helpers/cpu_time.dart';
import '../mocks.dart';
import '../test_context.dart';

void main() {
  test('8 MiB encrypted file round trip uses under five seconds of processor time', () async {
    MocksHelper.registerFallbackValues();
    final harness = TestContext()..setUpCommon();
    final directory = await Directory.systemTemp.createTemp('secure-stream-performance-');
    addTearDown(() async {
      harness.tearDownCommon();
      await directory.delete(recursive: true);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => directory.path,
    );
    when(() => harness.mockUuid.v4()).thenReturn('performance-file');
    String? encryptionKey;
    when(
      () => harness.mockSecureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      if (invocation.namedArguments[#value] case final String value) encryptionKey = value;
    });
    when(
      () => harness.mockSecureStorage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => encryptionKey);
    final bytes = Uint8List.fromList(.generate(8 * 1024 * 1024, (index) => index % 251));
    final operations = FileOperations();
    final started = processCpuTime();
    final metadata = await operations.saveSecureFileStream(
      SecureFileStreamRequest(
        stream: .value(bytes),
        fileExtension: 'bin',
        services: harness.fileServices(isWeb: false),
      ),
    );
    final restored = await operations.getSecureFile(
      fileMetadata: metadata,
      isWeb: false,
      secureStorage: harness.mockSecureStorage,
      getBox: harness.getBox,
    );
    final used = processCpuTime() - started;
    expect(restored, bytes);
    expect(metadata['chunkCount'], 4);
    expect(
      used,
      lessThan(const Duration(seconds: 5)),
      reason:
          'Eight MiB must use under five seconds of processor time, including encryption and disk I/O.',
    );
  });
}
