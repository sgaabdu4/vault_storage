class StorageKeys {
  StorageKeys._();

  // Key for storing the Hive encryption key in flutter_secure_storage.
  static const secureKey = 'hive_encryption_key';

  // Box names
  static const secureBox = 'secure_box';
  static const normalBox = 'normal_box';
}

// EXAMPLE: How a feature would define its own keys
// You would place this in your feature's constants file.
/*
class AuthFeatureKeys {
  AuthFeatureKeys._();
  static const authToken = 'auth_token';
  static const userCredentials = 'user_credentials';
}
*/
