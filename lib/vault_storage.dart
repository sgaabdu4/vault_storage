/// A barrel file that exports the public-facing API of the vault storage.
library;

import 'package:vault_storage/src/entities/box_config.dart';
import 'package:vault_storage/src/interface/i_vault_storage.dart';
import 'package:vault_storage/src/security/vault_security_config.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

export 'src/constants/config.dart';
export 'src/entities/box_config.dart';
export 'src/errors/errors.dart';
// Interfaces and Models
export 'src/interface/i_vault_storage.dart';
// Security features
export 'src/security/security_exceptions.dart';
export 'src/security/vault_security_config.dart';

/// Creates a new instance of [IVaultStorage].
class VaultStorage {
  VaultStorage._();

  /// Creates a new vault storage instance.
  static IVaultStorage create({
    VaultSecurityConfig? securityConfig,
    List<BoxConfig>? customBoxes,
    String? storageDirectory,
  }) => VaultStorageImpl(
    securityConfig: securityConfig,
    customBoxes: customBoxes,
    storageDirectory: storageDirectory,
  );
}
