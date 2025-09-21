/// A barrel file that exports the public-facing API of the vault storage.
///
/// This file is the single entry point for other parts of the application to
/// access the vault storage's features. It exports the essential interfaces,
/// models, enums, and errors, simplifying imports and decoupling
/// feature modules from the internal implementation details of the service.
library;

import 'package:vault_storage/src/interface/i_vault_storage.dart';
import 'package:vault_storage/src/security/vault_security_config.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

export 'src/constants/config.dart';
export 'src/errors/storage_error.dart';
// Interfaces and Models
export 'src/interface/i_vault_storage.dart';
// Security features
export 'src/security/security_exceptions.dart';
export 'src/security/vault_security_config.dart';

/// Creates a new instance of [IVaultStorage].
///
/// This is the recommended way to create a vault storage instance.
/// The implementation details are hidden from the consumer.
///
/// [securityConfig] - Optional security configuration for jailbreak protection
/// and other security features using FreeRASP. If null, no security features
/// are enabled.
///
/// **Important**: Security features are only available on Android and iOS.
/// On other platforms (macOS, Windows, Linux, Web), the security configuration
/// will be safely ignored and vault storage will work normally.
///
/// Example:
/// ```dart
/// // Basic usage without security
/// final storage = VaultStorage.create();
/// await storage.init();
///
/// // With security features enabled (Android/iOS only)
/// final secureStorage = VaultStorage.create(
///   securityConfig: VaultSecurityConfig.production(
///     watcherMail: 'security@myapp.com',
///     threatCallbacks: {
///       SecurityThreat.jailbreak: () => print('Jailbreak detected!'),
///     },
///   ),
/// );
/// await secureStorage.init(
///   packageName: 'com.mycompany.myapp',   // Android only
///   signingCertHashes: ['your_cert_hash'], // Android only
///   bundleId: 'com.mycompany.myapp',      // iOS only
///   teamId: 'YOUR_TEAM_ID',               // iOS only
/// );
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
  ///
  /// [securityConfig] - Optional security configuration for enabling
  /// jailbreak protection and other security features. Only effective on
  /// Android and iOS platforms.
  static IVaultStorage create({VaultSecurityConfig? securityConfig}) =>
      VaultStorageImpl(securityConfig: securityConfig);
}
