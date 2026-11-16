import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/security/vault_security_config.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

import '../../mocks.dart';
import '../../test_context.dart';

void main() {
  late TestContext testContext;

  setUpAll(() {
    MocksHelper.registerFallbackValues();
  });

  setUp(() {
    testContext = TestContext();
    testContext.setUpCommon();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    testContext.tearDownCommon();
  });

  VaultStorageImpl storageWith(VaultSecurityConfig? config) {
    return VaultStorageImpl(
      secureStorage: testContext.mockSecureStorage,
      uuid: testContext.mockUuid,
      securityConfig: config,
    );
  }

  test('talsecConfigFor passes the given identifiers and the security settings', () {
    final certificateHash = base64Encode(Uint8List(32));
    final storage = storageWith(
      const VaultSecurityConfig(isProd: true, watcherMail: 'security@example.com'),
    );

    final config = storage.talsecConfigFor(
      packageName: 'com.example.app',
      signingCertHashes: [certificateHash],
      bundleId: 'com.example.ios',
      teamId: 'TEAM',
    );

    expect(config.androidConfig?.packageName, 'com.example.app');
    expect(config.androidConfig?.certificateHashes, [certificateHash]);
    expect(config.androidConfig?.supportedAlternativeStores, ['com.android.vending']);
    expect(config.iosConfig?.appBundleIds, ['com.example.ios']);
    expect(config.iosConfig?.appTeamId, 'TEAM');
    expect(config.watcherMail, 'security@example.com');
    expect(config.isProd, isTrue);
  });

  test('talsecConfigFor fills placeholders when no identifiers are given', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    final config = storageWith(null).talsecConfigFor();

    expect(config.androidConfig?.packageName, 'your.package.name');
    expect(config.androidConfig?.certificateHashes, isEmpty);
    expect(config.iosConfig?.appBundleIds, isEmpty);
    expect(config.iosConfig?.appTeamId, isEmpty);
    expect(config.watcherMail, isEmpty);
    expect(config.isProd, isFalse);
  });
}
