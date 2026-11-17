import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:vault_storage/src/errors/storage_error.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';

/// TypeAdapter for [StoredValue], replacing the old Map wrapper format.
class StoredValueAdapter extends TypeAdapter<StoredValue> {
  static const int storedValueTypeId = 220;

  @override
  final int typeId = storedValueTypeId;

  @override
  StoredValue read(BinaryReader reader) {
    final strategyIndex = reader.readByte();
    final strategy = StorageStrategy.fromIndex(strategyIndex);
    if (strategy == null) {
      throw VaultStorageSerializationError('Invalid StorageStrategy index: $strategyIndex');
    }
    return StoredValue(reader.read(), strategy);
  }

  @override
  void write(BinaryWriter writer, StoredValue obj) {
    writer.writeByte(obj.strategy.index);
    writer.write(obj.value);
  }
}
