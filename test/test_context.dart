// test/helpers.dart
// Common test setup, mocks, and utilities for vault storage tests.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'mocks.mocks.dart';

class TestContext {
  late VaultStorageImpl vaultStorage;
  late MockFlutterSecureStorage mockSecureStorage;
  late MockUuid mockUuid;
  late MockBox<String> mockSecureBox;
  late MockBox<String> mockNormalBox;
  late MockBox<String> mockSecureFilesBox;
  late MockBox<String> mockNormalFilesBox;

  void setUpCommon() {
    TestWidgetsFlutterBinding.ensureInitialized();

    mockSecureStorage = MockFlutterSecureStorage();
    mockUuid = MockUuid();
    mockSecureBox = MockBox<String>();
    mockNormalBox = MockBox<String>();
    mockSecureFilesBox = MockBox<String>();
    mockNormalFilesBox = MockBox<String>();

    vaultStorage = VaultStorageImpl(
      secureStorage: mockSecureStorage,
      uuid: mockUuid,
    );

    vaultStorage.storageBoxes.addAll({
      BoxType.secure: mockSecureBox,
      BoxType.normal: mockNormalBox,
      BoxType.secureFiles: mockSecureFilesBox,
      BoxType.normalFiles: mockNormalFilesBox,
    });
    vaultStorage.isVaultStorageReady = true;

    _setupPathProviderMock();
  }

  void tearDownCommon() {
    _tearDownPathProviderMock();
  }

  void _setupPathProviderMock() {
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
  }

  void _tearDownPathProviderMock() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  }
}
