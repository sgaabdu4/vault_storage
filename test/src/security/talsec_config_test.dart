import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

import '../../mocks.dart';
import '../../test_context.dart';

void main() {
  late TestContext testContext;
  late VaultStorageImpl storage;

  setUpAll(() {
    MocksHelper.registerFallbackValues();
  });

  setUp(() {
    testContext = TestContext();
    testContext.setUpCommon();
    storage = VaultStorageImpl(
      secureStorage: testContext.mockSecureStorage,
      uuid: testContext.mockUuid,
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    testContext.tearDownCommon();
  });

  test('androidConfigFor passes the given package name and certificate hashes', () {
    final certificateHash = base64Encode(List<int>.filled(32, 0));

    final config = storage.androidConfigFor(
      packageName: 'com.example.app',
      signingCertHashes: [certificateHash],
    );

    expect(config.packageName, 'com.example.app');
    expect(config.certificateHashes, [certificateHash]);
    expect(config.supportedAlternativeStores, ['com.android.vending']);
  });

  test('androidConfigFor fills the placeholder package name when none is given', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    final config = storage.androidConfigFor();

    expect(config.packageName, 'your.package.name');
    expect(config.certificateHashes, isEmpty);
  });

  test('iosConfigFor passes the given bundle id and team id', () {
    final config = storage.iosConfigFor(bundleId: 'com.example.ios', teamId: 'TEAM');

    expect(config.appBundleIds, ['com.example.ios']);
    expect(config.appTeamId, 'TEAM');
  });

  test('iosConfigFor leaves the bundle ids and team id empty when none are given', () {
    final config = storage.iosConfigFor();

    expect(config.appBundleIds, isEmpty);
    expect(config.appTeamId, isEmpty);
  });
}
