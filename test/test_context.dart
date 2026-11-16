import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:vault_storage/src/entities/box_config.dart';
import 'package:vault_storage/src/entities/file_services.dart';
import 'package:vault_storage/src/enum/box_type.dart';
import 'package:vault_storage/src/security/vault_security_config.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

import 'mocks.dart';

class TestContext {
  final MockSecureKeyStore mockSecureStorage = MockSecureKeyStore();
  final MockIdGenerator mockUuid = MockIdGenerator();
  final MockBox<Object?> mockSecureBox = MockBox<Object?>();
  final MockBox<Object?> mockNormalBox = MockBox<Object?>();
  final MockLazyBox<Object?> mockSecureFilesBox = MockLazyBox<Object?>();
  final MockLazyBox<Object?> mockNormalFilesBox = MockLazyBox<Object?>();
  final MockFileOperations mockFileOperations = MockFileOperations();
  late final VaultStorageImpl vaultStorage = createStorage();

  VaultStorageImpl createStorage({
    VaultSecurityConfig? securityConfig,
    List<BoxConfig>? customBoxes,
    String? storageDirectory,
  }) => VaultStorageImpl(
    secureStorage: mockSecureStorage,
    uuid: mockUuid,
    fileOperations: mockFileOperations,
    securityConfig: securityConfig,
    customBoxes: customBoxes,
    storageDirectory: storageDirectory,
  );

  FileServices fileServices({required bool? isWeb}) =>
      FileServices(isWeb: isWeb, secureStorage: mockSecureStorage, uuid: mockUuid, getBox: getBox);

  // Convenience getters for common naming patterns
  MockLazyBox<Object?> get mockSecureFileStorageBox => mockSecureFilesBox;
  MockLazyBox<Object?> get mockNormalFileStorageBox => mockNormalFilesBox;

  // Get box function for FileOperations testing
  BoxBase<Object?> getBox(BoxType type) {
    switch (type) {
      case .secure:
        return mockSecureBox;
      case .normal:
        return mockNormalBox;
      case .secureFiles:
        return mockSecureFilesBox;
      case .normalFiles:
        return mockNormalFilesBox;
    }
  }

  void setUpCommon() {
    TestWidgetsFlutterBinding.ensureInitialized();

    vaultStorage.boxes.addAll({
      .secure: mockSecureBox,
      .normal: mockNormalBox,
      .secureFiles: mockSecureFilesBox,
      .normalFiles: mockNormalFilesBox,
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
