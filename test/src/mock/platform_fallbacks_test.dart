import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/errors/storage_error.dart';
import 'package:vault_storage/src/mock/file_io_mock.dart' as files;
import 'package:vault_storage/src/mock/freerasp_mock.dart' as security;
import 'package:vault_storage/src/mock/path_provider_mock.dart' as paths;

void main() {
  test('browser filesystem fallbacks reject every native file operation', () async {
    final file = files.File('unsupported.bin');
    expect(file.path, 'unsupported.bin');
    await expectLater(file.exists(), throwsA(isA<UnsupportedPlatformError>()));
    await expectLater(file.readAsBytes(), throwsA(isA<UnsupportedPlatformError>()));
    await expectLater(file.writeAsBytes([1, 2]), throwsA(isA<UnsupportedPlatformError>()));
    await expectLater(file.delete(), throwsA(isA<UnsupportedPlatformError>()));
    expect(file.openWrite, throwsA(isA<UnsupportedPlatformError>()));
    await expectLater(file.open(), throwsA(isA<UnsupportedPlatformError>()));
    final sink = files.IOSink();
    expect(() => sink.add([1]), throwsA(isA<UnsupportedPlatformError>()));
    await expectLater(sink.close(), throwsA(isA<UnsupportedPlatformError>()));
    final reader = files.RandomAccessFile();
    await expectLater(reader.read(1), throwsA(isA<UnsupportedPlatformError>()));
    await expectLater(reader.close(), throwsA(isA<UnsupportedPlatformError>()));
    await expectLater(
      paths.getApplicationDocumentsDirectory(),
      throwsA(isA<UnsupportedPlatformError>()),
    );
  });

  test('unsupported security runtime starts without reporting a false threat', () async {
    final threats = <String>[];
    final callbacks = security.ThreatCallback(onJailbreak: () => threats.add('jailbreak'));
    const config = security.TalsecConfig(
      androidConfig: security.AndroidConfig(
        packageName: 'com.example.test',
        certificateHashes: [],
        supportedAlternativeStores: [],
      ),
      iosConfig: security.IOSConfig(appBundleIds: ['com.example.test'], appTeamId: 'EXAMPLE'),
      watcherMail: 'security@example.com',
      isProd: false,
    );
    security.Talsec.instance.attachListener(callbacks);
    await security.Talsec.instance.start(config);
    expect(threats, isEmpty);
  });
}
