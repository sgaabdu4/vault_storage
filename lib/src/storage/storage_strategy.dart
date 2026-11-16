import 'dart:typed_data';

import 'package:vault_storage/src/errors/storage_error.dart';

/// Strategy for storing values in Hive boxes.
enum StorageStrategy {
  /// Store value directly using Hive's native binary serialization.
  native,

  /// Store value as JSON string.
  json;

  /// Returns the strategy stored under [index], or null when no strategy has that index.
  static StorageStrategy? fromIndex(int index) =>
      values.where((strategy) => strategy.index == index).firstOrNull;
}

/// Wrapper for values stored in Hive with metadata about storage strategy.
class StoredValue {
  /// The actual value being stored
  final Object? value;

  /// The strategy used to store this value
  final StorageStrategy strategy;

  /// Key for strategy in stored map
  static const String _strategyKey = '__VST_STRATEGY__';

  /// Key for value in stored map
  static const String _valueKey = '__VST_VALUE__';

  static const int _wrappedEntryCount = 2;

  /// Creates a new stored value wrapper
  const StoredValue(this.value, this.strategy);

  /// Converts to a map suitable for Hive storage
  Map<String, Object?> toHiveMap() => {_strategyKey: strategy.index, _valueKey: value};

  /// Reconstructs a StoredValue from a Hive map
  static StoredValue fromHiveMap(Map<Object?, Object?> map) {
    final strategyIndex = switch (map[_strategyKey]) {
      final int index => index,
      _ => throw const VaultStorageSerializationError('Stored value has no strategy index.'),
    };
    final strategy = StorageStrategy.fromIndex(strategyIndex);
    if (strategy == null) {
      throw VaultStorageSerializationError('Invalid StorageStrategy index: $strategyIndex');
    }
    return StoredValue(map[_valueKey], strategy);
  }

  /// Checks if a value from Hive is wrapped with our metadata
  static bool isWrapped(Object? value) {
    if (value is! Map) return false;
    return value.length == _wrappedEntryCount &&
        value.containsKey(_strategyKey) &&
        value.containsKey(_valueKey);
  }
}

/// Helper functions for determining optimal storage strategy
abstract final class StorageStrategyHelper {
  /// Determines the optimal storage strategy for a given value
  static StorageStrategy determineStrategy(Object? value) {
    // Check if it's natively storable by Hive (includes primitives)
    return _isNativelyStorable(value) ? .native : .json;
  }

  /// Checks if a value can be stored natively by Hive without JSON encoding
  static bool _isNativelyStorable(Object? value) {
    final stack = [value];

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (!_isHivePrimitive(current)) {
        switch (current) {
          case List():
            stack.addAll(current);
          case Map():
            stack
              ..addAll(current.keys)
              ..addAll(current.values);
          default:
            return false;
        }
      }
    }

    return true;
  }

  static bool _isHivePrimitive(Object? value) =>
      value == null || value is String || value is num || value is bool || value is Uint8List;
}
