import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vault_storage/src/interface/i_secure_key_store.dart';

/// The [ISecureKeyStore] that uses `flutter_secure_storage`.
final class FlutterSecureKeyStore implements ISecureKeyStore {
  const FlutterSecureKeyStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String? value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}
