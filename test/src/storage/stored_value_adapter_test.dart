import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';
import 'package:vault_storage/src/storage/stored_value_adapter.dart';

void main() {
  group('StoredValueAdapter', () {
    late StoredValueAdapter adapter;

    setUp(() {
      adapter = StoredValueAdapter();
    });

    test('typeId should be 200', () {
      expect(adapter.typeId, equals(200));
    });

    test('should round-trip a native string value', () {
      const original = StoredValue('hello', StorageStrategy.native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals('hello'));
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('should round-trip a native int value', () {
      const original = StoredValue(42, StorageStrategy.native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals(42));
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('should round-trip a native double value', () {
      const original = StoredValue(3.14, StorageStrategy.native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals(3.14));
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('should round-trip a native bool value', () {
      const original = StoredValue(true, StorageStrategy.native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals(true));
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('should round-trip a native list value', () {
      const original = StoredValue([1, 2, 3], StorageStrategy.native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals([1, 2, 3]));
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('should round-trip a native map value', () {
      const original = StoredValue({'key': 'value', 'count': 5}, StorageStrategy.native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals({'key': 'value', 'count': 5}));
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('should round-trip a json strategy value', () {
      const original = StoredValue('{"name":"test"}', StorageStrategy.json);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals('{"name":"test"}'));
      expect(restored.strategy, equals(StorageStrategy.json));
    });

    test('should round-trip a Uint8List value', () {
      final data = Uint8List.fromList([10, 20, 30, 40]);
      final original = StoredValue(data, StorageStrategy.native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals(data));
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('should round-trip a null value', () {
      const original = StoredValue(null, StorageStrategy.native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, isNull);
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('strategy index 0 maps to native', () {
      // Write with native strategy, verify readByte returns 0
      const original = StoredValue('x', StorageStrategy.native);
      final bytes = _serializeAdapter(adapter, original);
      // First byte should be 0 (native)
      expect(bytes[0], equals(0));
    });

    test('strategy index 1 maps to json', () {
      const original = StoredValue('x', StorageStrategy.json);
      final bytes = _serializeAdapter(adapter, original);
      // First byte should be 1 (json)
      expect(bytes[0], equals(1));
    });

    test('throws RangeError for invalid strategy index', () {
      // Manually craft bytes with an out-of-range strategy index
      final writer = BinaryWriterImpl(TypeRegistryImpl());
      writer.writeByte(99); // invalid strategy index
      writer.write('value');
      final bytes = writer.toBytes();

      expect(
        () => _deserializeAdapter(adapter, bytes),
        throwsA(isA<RangeError>()),
      );
    });
  });
}

/// Serialize a StoredValue using the adapter's write method via Hive's BinaryWriter.
Uint8List _serializeAdapter(StoredValueAdapter adapter, StoredValue value) {
  final writer = BinaryWriterImpl(TypeRegistryImpl());
  adapter.write(writer, value);
  return writer.toBytes();
}

/// Deserialize a StoredValue using the adapter's read method via Hive's BinaryReader.
StoredValue _deserializeAdapter(StoredValueAdapter adapter, Uint8List bytes) {
  final reader = BinaryReaderImpl(bytes, TypeRegistryImpl());
  return adapter.read(reader);
}
