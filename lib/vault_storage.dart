/// A barrel file that exports the public-facing API of the vault storage.
///
/// This file is the single entry point for other parts of the application to
/// access the vault storage's features. It exports the essential interfaces,
/// models, enums, and errors, simplifying imports and decoupling
/// feature modules from the internal implementation details of the service.
library;

import 'src/interface/i_vault_storage.dart';
import 'src/vault_storage_impl.dart';

// Interfaces and Models
export 'src/interface/i_vault_storage.dart';
export 'src/errors/storage_error.dart';
export 'src/constants/config.dart';

/// Creates a new instance of [IVaultStorage].
///
/// This is the recommended way to create a vault storage instance.
/// The implementation details are hidden from the consumer.
///
/// Example:
/// ```dart
/// final storage = VaultStorage.create();
/// await storage.init();
///
/// // Key-value storage
/// await storage.saveSecure(key: 'auth_token', value: 'jwt123');
/// await storage.saveNormal(key: 'user_prefs', value: {'theme': 'dark'});
///
/// // Retrieval (checks normal first, then secure for performance)
/// final token = await storage.get<String>('auth_token');
/// final prefs = await storage.get<Map>('user_prefs');
///
/// // Specific storage type retrieval
/// final secureToken = await storage.get<String>('auth_token', isSecure: true);
/// final normalPrefs = await storage.get<Map>('user_prefs', isSecure: false);
///
/// // File storage
/// await storage.saveSecureFile(key: 'profile_pic', fileBytes: imageBytes);
/// await storage.saveNormalFile(key: 'cache_file', fileBytes: cacheBytes);
/// final fileContent = await storage.getFile('profile_pic');
/// ```
class VaultStorage {
  VaultStorage._();

  /// Creates a new vault storage instance.
  static IVaultStorage create() => VaultStorageImpl();
}
