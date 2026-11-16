/// A utility class that holds constant values for storage keys.
class StorageKeys {
  StorageKeys._();

  /// The secure storage key that holds the master encryption key for the secure Hive box.
  static const secureKey = 'hive_encryption_key';

  // Box names
  static const secureBox = 'secure_box';

  /// The name of the Hive box used for storing non-sensitive, unencrypted key-value pairs.
  static const normalBox = 'normal_box';

  /// The name of the Hive box used for storing file data, such as images or documents.
  static const secureFilesBox = 'secure_files_box';

  /// The name of the Hive box used for storing non-sensitive file data without encryption.
  static const normalFilesBox = 'normal_files_box';
}
