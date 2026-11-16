/// Keeps the encryption keys in the platform's secure storage.
abstract interface class ISecureKeyStore {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String? value});

  Future<void> delete({required String key});
}
