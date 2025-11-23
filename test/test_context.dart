// test/helpers.dart
// Common test setup, mocks, and utilities for vault storage tests.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

import 'mocks.dart';

class TestContext {
  late VaultStorageImpl vaultStorage;
  late MockFlutterSecureStorage mockSecureStorage;
  late MockUuid mockUuid;
  late MockBox<dynamic> mockSecureBox;
  late MockBox<dynamic> mockNormalBox;
  late MockLazyBox<dynamic> mockSecureFilesBox;
  late MockLazyBox<dynamic> mockNormalFilesBox;
  late MockFileOperations mockFileOperations;

  // Convenience getters for common naming patterns
  MockLazyBox<dynamic> get mockSecureFileStorageBox => mockSecureFilesBox;
  MockLazyBox<dynamic> get mockNormalFileStorageBox => mockNormalFilesBox;

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
    mockSecureBox = MockBox<dynamic>();
    mockNormalBox = MockBox<dynamic>();
    mockSecureFilesBox = MockLazyBox<dynamic>();
    mockNormalFilesBox = MockLazyBox<dynamic>();
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  }
}
