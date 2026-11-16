import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:vault_storage/src/errors/storage_error.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';
import 'package:vault_storage/src/storage/stored_value_adapter.dart';

void main() {
  group('StoredValueAdapter', () {
    late StoredValueAdapter adapter;

    setUp(() {
      adapter = StoredValueAdapter();
    });

    test('typeId should be 220', () {
      expect(adapter.typeId, equals(220));
    });

    test('should round-trip a native string value', () {
      const original = StoredValue('hello', .native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals('hello'));
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('should round-trip a native int value', () {
      const original = StoredValue(42, .native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals(42));
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('should round-trip a native double value', () {
      const original = StoredValue(3.14, .native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals(3.14));
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('should round-trip a native bool value', () {
      const original = StoredValue(true, .native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals(true));
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('should round-trip a native list value', () {
      const original = StoredValue([1, 2, 3], .native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals([1, 2, 3]));
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('should round-trip a native map value', () {
      const original = StoredValue({'key': 'value', 'count': 5}, .native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals({'key': 'value', 'count': 5}));
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('should round-trip a json strategy value', () {
      const original = StoredValue('{"name":"test"}', .json);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals('{"name":"test"}'));
      expect(restored.strategy, equals(StorageStrategy.json));
    });

    test('should round-trip a Uint8List value', () {
      final data = Uint8List.fromList([10, 20, 30, 40]);
      final original = StoredValue(data, .native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, equals(data));
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('should round-trip a null value', () {
      const original = StoredValue(null, .native);
      final bytes = _serializeAdapter(adapter, original);
      final restored = _deserializeAdapter(adapter, bytes);

      expect(restored.value, isNull);
      expect(restored.strategy, equals(StorageStrategy.native));
    });

    test('strategy index 0 maps to native', () {
      // Write with native strategy, verify readByte returns 0
      const original = StoredValue('x', .native);
      final encoded = _serializeAdapter(adapter, original);
      expect(encoded.strategyIndex, equals(0));
    });

    test('strategy index 1 maps to json', () {
      const original = StoredValue('x', .json);
      final encoded = _serializeAdapter(adapter, original);
      expect(encoded.strategyIndex, equals(1));
    });

    test('throws a serialization error for invalid strategy index', () {
      const encoded = (strategyIndex: 99, value: 'value');
      expect(
        () => _deserializeAdapter(adapter, encoded),
        throwsA(isA<VaultStorageSerializationError>()),
      );
    });
  });
}

({int strategyIndex, dynamic value}) _serializeAdapter(
  StoredValueAdapter adapter,
  StoredValue value,
) {
  final writer = _RecordingBinaryWriter();
  adapter.write(writer, value);
  return (strategyIndex: writer.strategyIndex, value: writer.value);
}

StoredValue _deserializeAdapter(
  StoredValueAdapter adapter,
  ({int strategyIndex, dynamic value}) encoded,
) {
  final reader = _RecordingBinaryReader(encoded);
  return adapter.read(reader);
}

class _RecordingBinaryWriter implements BinaryWriter {
  late int strategyIndex;
  dynamic value;

  @override
  void writeByte(int byte) => strategyIndex = byte;

  @override
  void write<T>(T value, {bool withTypeId = true}) => this.value = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingBinaryReader implements BinaryReader {
  _RecordingBinaryReader(this.encoded);

  final ({int strategyIndex, dynamic value}) encoded;

  @override
  int readByte() => encoded.strategyIndex;

  @override
  dynamic read([int? typeId]) => encoded.value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
