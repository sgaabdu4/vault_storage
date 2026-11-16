import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/vault_storage.dart';

import '../helpers/cpu_time.dart';

void main() {
  test('initialize and round-trip 100 preferences within five seconds of processor time', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final directory = await Directory.systemTemp.createTemp('vault-consumer-performance-');
    FlutterSecureStorage.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => directory.path,
    );
    final storage = VaultStorage.create();
    addTearDown(() async {
      await storage.dispose();
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      await directory.delete(recursive: true);
    });
    final started = processCpuTime();
    await storage.init();
    for (int index = 0; index < 100; index++) {
      await storage.saveNormal(key: 'preference-$index', value: 'value-$index');
    }
    for (int index = 0; index < 100; index++) {
      expect(await storage.get<String>('preference-$index'), 'value-$index');
    }
    final used = processCpuTime() - started;
    expect(
      used,
      lessThan(const Duration(seconds: 5)),
      reason: 'Consumer initialization and 200 local operations must use under five seconds of processor time.',
    );
  });
}
