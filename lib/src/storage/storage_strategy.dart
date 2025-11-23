import 'dart:typed_data';

/// Strategy for storing values in Hive boxes.
///
/// Determines the most efficient storage method based on the data type.
enum StorageStrategy {
  /// Store value directly using Hive's native binary serialization.
  ///
  /// Used for: Lists, Maps, primitives, and other types Hive can natively handle.
  /// This is the fastest method as it avoids JSON encoding/decoding overhead.
  native,

  /// Store value as JSON string.
  ///
  /// Used for: Custom objects that can't be stored natively.
  /// Falls back to JSON serialization for compatibility.
  json,
}

/// Wrapper for values stored in Hive with metadata about storage strategy.
///
/// This wrapper enables:
/// - Backward compatibility with string-based storage
/// - Automatic detection of optimal storage method
/// - Transparent migration from old to new format
class StoredValue {
  /// The actual value being stored
  final dynamic value;

  /// The strategy used to store this value
  final StorageStrategy strategy;

  /// Key for strategy in stored map
  static const String _strategyKey = '__VST_STRATEGY__';

  /// Key for value in stored map
  static const String _valueKey = '__VST_VALUE__';

  /// Creates a new stored value wrapper
  const StoredValue(this.value, this.strategy);

  /// Converts to a map suitable for Hive storage
  Map<String, dynamic> toHiveMap() => {
        _strategyKey: strategy.index,
        _valueKey: value,
      };

  /// Reconstructs a StoredValue from a Hive map
  static StoredValue fromHiveMap(Map<dynamic, dynamic> map) {
    final strategyIndex = map[_strategyKey] as int;
    final value = map[_valueKey];
    return StoredValue(value, StorageStrategy.values[strategyIndex]);
  }

  /// Checks if a value from Hive is wrapped with our metadata
  static bool isWrapped(dynamic value) {
    if (value is! Map) return false;
    return value.containsKey(_strategyKey) && value.containsKey(_valueKey);
  }
}

/// Helper functions for determining optimal storage strategy
class StorageStrategyHelper {
  StorageStrategyHelper._();

  /// Determines the optimal storage strategy for a given value
  static StorageStrategy determineStrategy(dynamic value) {
    // Check if it's natively storable by Hive (includes primitives)
    return _isNativelyStorable(value) ? StorageStrategy.native : StorageStrategy.json;
  }

  /// Checks if a value can be stored natively by Hive without JSON encoding
  static bool _isNativelyStorable(dynamic value) {
    // Handle null
    if (value == null) return true;

    // Primitives
    if (value is String || value is num || value is bool) return true;

    // Binary data
    if (value is Uint8List) return true;

    // Lists - check if all elements are natively storable
    if (value is List) {
      return value.every(_isNativelyStorable);
    }

    // Maps - check if all keys and values are natively storable
    if (value is Map) {
      return value.keys.every(_isNativelyStorable) && value.values.every(_isNativelyStorable);
    }

    // Everything else needs JSON encoding
    return false;
  }
}
