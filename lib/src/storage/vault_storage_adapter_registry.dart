import 'package:hive_ce/hive_ce.dart';
import 'package:vault_storage/src/storage/stored_value_adapter.dart';

/// Registers Hive adapters owned by vault_storage.
abstract final class VaultStorageAdapterRegistry {
  static void ensureRegistered() {
    final adapter = StoredValueAdapter();
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
  }
}
