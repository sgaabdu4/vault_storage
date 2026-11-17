part of 'vault_storage_impl.dart';

const _corruptedKeyHint = 'Consider clearing this key if the data is corrupted.';

extension VaultStorageBoxAccess on VaultStorageImpl {
  /// Get value from a specific box (supports both Box and LazyBox)
  @visibleForTesting
  Future<T?> getFromBox<T>(BoxType boxType, String key) async {
    final box = boxes[boxType];
    return box == null ? null : await _getFromBoxBase<T>(box, key);
  }

  Future<T?> _getFromBoxBase<T>(BoxBase<Object?> box, String key) async {
    if (!box.containsKey(key)) return null;

    final stored = switch (box) {
      final LazyBox<Object?> lazy => await lazy.get(key),
      final Box<Object?> eager => eager.get(key),
      _ => null,
    };

    return switch (stored) {
      null => null,
      final String legacyJson => await legacyJson.decodeJsonSafely<T>(_config),
      final StoredValue value => await _decodeStored<T>(key, value),
      final Map<Object?, Object?> wrapped when StoredValue.isWrapped(wrapped) =>
        await _decodeStored<T>(key, .fromHiveMap(wrapped)),
      _ => _coerceToType<T>(key, stored),
    };
  }

  Future<T?> _decodeStored<T>(String key, StoredValue stored) async {
    if (stored.strategy == .native) return _coerceToType<T>(key, stored.value);
    return _jsonText(stored.value).decodeJsonSafely<T>(_config);
  }

  T _coerceToType<T>(String key, Object? value) {
    if (value is T) return value;

    final converted = switch (value) {
      final num number when T == int => number.toInt(),
      final num number when T == double => number.toDouble(),
      final Object object when T == String => object.toString(),
      final Map<Object?, Object?> map => _withStringKeys(map, deep: false),
      _ => null,
    };
    if (converted is T) return converted;

    throw _typeMismatch<T>(key, value);
  }

  VaultStorageReadError _typeMismatch<T>(String key, Object? value) {
    final subject =
        'Type mismatch for "$key": cannot convert the stored ${value.runtimeType} to $T.';
    return VaultStorageReadError('$subject $_corruptedKeyHint');
  }

  /// Set value in a specific box
  @visibleForTesting
  Future<void> setInBox<T>(BoxType boxType, String key, T value) async {
    await _putInBoxBase(_requireBox(boxType), key, value);
  }

  Future<void> _putInBoxBase<T>(BoxBase<Object?> box, String key, T value) async {
    final strategy = StorageStrategyHelper.determineStrategy(value);

    final toStore = strategy == .native
        ? StoredValue(value, strategy)
        : StoredValue(await value.encodeJsonSafely(_config), strategy);

    await box.put(key, toStore);
  }

  BoxBase<Object?> _requireBox(BoxType type) => switch (boxes[type]) {
    final BoxBase<Object?> box => box,
    null => throw VaultStorageInitializationError(
      'Box ${type.name} not opened. Ensure init() was called.',
    ),
  };

  BoxBase<Object?> _requireCustomBox(String name) => switch (customBoxes[name]) {
    final BoxBase<Object?> box => box,
    null => throw BoxNotFoundError('Box "$name" not found. Register it during init()'),
  };

  /// Get file metadata with optional storage type specification. Empty when no file is stored.
  @visibleForTesting
  Future<Map<String, dynamic>> getFileMetadata(String key, {bool? isSecure}) async {
    if (isSecure == false) return _fileBoxMetadata(.normalFiles, key, isSecure: false);
    if (isSecure == true) return _fileBoxMetadata(.secureFiles, key, isSecure: true);

    final normal = await _fileBoxMetadata(.normalFiles, key, isSecure: false);
    if (normal.isNotEmpty) return normal;
    return _fileBoxMetadata(.secureFiles, key, isSecure: true);
  }

  Future<Map<String, dynamic>> _fileBoxMetadata(
    BoxType boxType,
    String key, {
    required bool isSecure,
  }) async {
    final box = boxes[boxType];
    if (box == null || !box.containsKey(key)) return const <String, dynamic>{};

    try {
      final result = await _getFromBoxBase<Map<String, dynamic>>(box, key);
      return switch (result) {
        final Map<String, dynamic> stored => <String, dynamic>{
          ..._withStringKeys(stored, deep: true),
          StoredFileKeys.isSecure: isSecure,
        },
        null => const <String, dynamic>{},
      };
    } on VaultStorageError {
      rethrow;
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  /// Get a box from storage - returns the box directly
  @visibleForTesting
  BoxBase<Object?> getInternalBox(BoxType type) => _requireBox(type);

  /// Clear all files (underlying content + metadata) within a specific files box.
  @visibleForTesting
  Future<void> clearAllFilesInBox(BoxType boxType, {required bool isSecure}) async {
    final box = boxes[boxType];
    if (box == null) return;

    await inOrder(
      box.keys.whereType<String>(),
      (key) => _completes(() => _deleteFileContent(key, isSecure: isSecure)),
      reason: 'Files are deleted one at a time in key order, then the box is cleared',
    );

    await box.clear();
  }

  Future<void> _deleteFileContent(String key, {required bool isSecure}) async {
    final metadata = await getFileMetadata(key, isSecure: isSecure);
    if (metadata.isEmpty) return;

    if (isSecure) {
      await _fileOperations.deleteSecureFile(
        fileMetadata: metadata,
        isWeb: kIsWeb,
        secureStorage: _secureStorage,
        getBox: getInternalBox,
      );
    } else {
      await _fileOperations.deleteNormalFile(
        fileMetadata: metadata,
        isWeb: kIsWeb,
        getBox: getInternalBox,
      );
    }
  }
}

String _describe(Object? value) => switch (value) {
  null => 'null',
  final Object present => present.toString(),
};

Map<String, Object?> _withStringKeys(Map<Object?, Object?> map, {required bool deep}) =>
    <String, Object?>{
      for (final entry in map.entries)
        _describe(entry.key): deep ? _nestedWithStringKeys(entry.value) : entry.value,
    };

Object? _nestedWithStringKeys(Object? value) => switch (value) {
  final Map<Object?, Object?> map => _withStringKeys(map, deep: true),
  final List<Object?> list when list is! TypedData => [
    for (final item in list) _nestedWithStringKeys(item),
  ],
  _ => value,
};

Iterable<String> _stringKeys(BoxBase<Object?>? box) => switch (box) {
  final BoxBase<Object?> present => present.keys.whereType<String>(),
  null => const <String>[],
};

Future<bool> _completes(AsyncCallback action) async {
  try {
    await action();
    return true;
  } catch (_) {
    return false;
  }
}

String _jsonText(Object? value) => switch (value) {
  final String text => text,
  _ => throw const VaultStorageSerializationError('Stored JSON value is not text.'),
};
