import 'package:hive_ce/hive_ce.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';

/// TypeAdapter for [StoredValue], replacing the old Map wrapper format.
///
/// Binary format per stored entry (after the Hive frame header):
///   - 1 byte : strategy index (0 = native, 1 = json)
///   - N bytes: Hive-native encoding of the actual value
///
/// This reduces per-entry overhead from ~36 bytes (Map wrapper with two
/// string keys) to 2 bytes, and eliminates a Map allocation on every read/write.
///
/// **Backward compatibility**: Data written in the old Map-wrapper format
/// (v3.x) is still read correctly via [StoredValue.isWrapped]. Only new
/// writes use this adapter. Downgrading from v4.x to v3.x after new data has
/// been written is **not supported**.
class StoredValueAdapter extends TypeAdapter<StoredValue> {
  @override
  final int typeId = 200;

  @override
  StoredValue read(BinaryReader reader) {
    final strategyIndex = reader.readByte();
    if (strategyIndex >= StorageStrategy.values.length) {
      throw RangeError('Invalid StorageStrategy index: $strategyIndex');
    }
    final value = reader.read();
    return StoredValue(value, StorageStrategy.values[strategyIndex]);
  }

  @override
  void write(BinaryWriter writer, StoredValue obj) {
    writer.writeByte(obj.strategy.index);
    writer.write(obj.value);
  }
}
