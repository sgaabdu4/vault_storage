// test/helpers.dart
// Common test setup, mocks, and utilities for vault storage tests.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';

import 'mocks.dart';

class TestContext {
  late VaultStorageImpl vaultStorage;
  late MockFlutterSecureStorage mockSecureStorage;
  late MockUuid mockUuid;
  late MockBox<String> mockSecureBox;
  late MockBox<String> mockNormalBox;
  late MockLazyBox<String> mockSecureFilesBox;
  late MockLazyBox<String> mockNormalFilesBox;
  late MockFileOperations mockFileOperations;

  // Convenience getters for common naming patterns
  MockLazyBox<String> get mockSecureFileStorageBox => mockSecureFilesBox;
  MockLazyBox<String> get mockNormalFileStorageBox => mockNormalFilesBox;

  // Get box function for FileOperations testing
  BoxBase<dynamic> getBox(BoxType type) {
    switch (type) {
      case BoxType.secure:
        return mockSecureBox;
      case BoxType.normal:
        return mockNormalBox;
      case BoxType.secureFiles:
        return mockSecureFilesBox;
      case BoxType.normalFiles:
        return mockNormalFilesBox;
    }
  }

  void setUpCommon() {
    TestWidgetsFlutterBinding.ensureInitialized();

    mockSecureStorage = MockFlutterSecureStorage();
    mockUuid = MockUuid();
    mockSecureBox = MockBox<String>();
    mockNormalBox = MockBox<String>();
    mockSecureFilesBox = MockLazyBox<String>();
    mockNormalFilesBox = MockLazyBox<String>();
    mockFileOperations = MockFileOperations();

    vaultStorage = VaultStorageImpl(
      secureStorage: mockSecureStorage,
      uuid: mockUuid,
      fileOperations: mockFileOperations,
    );

    vaultStorage.boxes.addAll({
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
