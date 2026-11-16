/// A barrel file that exports the public-facing API of the vault storage.
library;

import 'package:vault_storage/src/entities/box_config.dart';
import 'package:vault_storage/src/interface/i_vault_storage.dart';
import 'package:vault_storage/src/security/vault_security_config.dart';
import 'package:vault_storage/src/storage/file_operations.dart';
import 'package:vault_storage/src/storage/flutter_secure_key_store.dart';
import 'package:vault_storage/src/storage/uuid_id_generator.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

export 'src/constants/vault_storage_config.dart';
export 'src/entities/box_config.dart';
export 'src/errors/errors.dart';
// Interfaces and Models
export 'src/interface/i_vault_storage.dart';
// Security features
export 'src/security/security_exceptions.dart';
export 'src/security/vault_security_config.dart';

/// Creates a new instance of [IVaultStorage].
abstract final class VaultStorage {
  /// Creates a new vault storage instance.
  static IVaultStorage create({
    VaultSecurityConfig? securityConfig,
    List<BoxConfig>? customBoxes,
    String? storageDirectory,
  }) => VaultStorageImpl(
    secureStorage: const FlutterSecureKeyStore(),
    uuid: const UuidIdGenerator(),
    fileOperations: FileOperations(),
    securityConfig: securityConfig,
    customBoxes: customBoxes,
    storageDirectory: storageDirectory,
  );
}
