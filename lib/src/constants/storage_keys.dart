/// A utility class that holds constant values for storage keys.
///
/// This class centralizes the keys used throughout the vault storage to prevent typos
/// and provide a single source of truth. It includes keys for secure storage and box names.
class StorageKeys {
  StorageKeys._();

  /// The key used to store the master encryption key for the secure Hive box in
  /// `flutter_secure_storage`. This key is crucial for accessing all encrypted data.
  static const secureKey = 'hive_encryption_key';

  // Box names
  /// The name of the Hive box used for storing sensitive, encrypted key-value pairs.
  static const secureBox = 'secure_box';

  /// The name of the Hive box used for storing non-sensitive, unencrypted key-value pairs.
  static const normalBox = 'normal_box';

  /// The name of the Hive box used for storing file data, such as images or documents.
  static const secureFilesBox = 'secure_files_box';
}

// EXAMPLE: How a feature would define its own keys
// You would place this in your feature's constants file.

// class AuthFeatureKeys {
//   AuthFeatureKeys._();
//   static const authToken = 'auth_token';
//   static const userCredentials = 'user_credentials';
// }

