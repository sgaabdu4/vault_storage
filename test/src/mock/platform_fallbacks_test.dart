import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/mock/file_io_mock.dart' as files;
import 'package:vault_storage/src/mock/freerasp_mock.dart' as security;
import 'package:vault_storage/src/mock/path_provider_mock.dart' as paths;

void main() {
  test('browser filesystem fallbacks reject every native file operation', () async {
    final file = files.File('unsupported.bin');
    expect(file.path, 'unsupported.bin');
    await expectLater(file.exists(), throwsUnsupportedError);
    await expectLater(file.readAsBytes(), throwsUnsupportedError);
    await expectLater(file.writeAsBytes([1, 2]), throwsUnsupportedError);
    await expectLater(file.delete(), throwsUnsupportedError);
    expect(file.openWrite, throwsUnsupportedError);
    await expectLater(file.open(), throwsUnsupportedError);
    final sink = files.IOSink();
    expect(() => sink.add([1]), throwsUnsupportedError);
    await expectLater(sink.close(), throwsUnsupportedError);
    final reader = files.RandomAccessFile();
    await expectLater(reader.read(1), throwsUnsupportedError);
    await expectLater(reader.close(), throwsUnsupportedError);
    await expectLater(paths.getApplicationDocumentsDirectory(), throwsUnsupportedError);
  });

  test('unsupported security runtime starts without reporting a false threat', () async {
    final threats = <String>[];
    final callbacks = security.ThreatCallback(onJailbreak: () => threats.add('jailbreak'));
    const config = security.TalsecConfig(
      androidConfig: security.AndroidConfig(
        packageName: 'com.example.test',
        signingCertHashes: [],
        supportedStores: [],
      ),
      iosConfig: security.IOSConfig(bundleIds: ['com.example.test'], teamId: 'EXAMPLE'),
      watcherMail: 'security@example.com',
      isProd: false,
    );
    security.Talsec.instance.attachListener(callbacks);
    await security.Talsec.instance.start(config);
    expect(threats, isEmpty);
  });
}
