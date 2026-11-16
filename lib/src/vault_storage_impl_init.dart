part of 'vault_storage_impl.dart';

extension VaultStorageInitialization on VaultStorageImpl {
  Future<void> _doInit() async {
    try {
      final config = _securityConfig;
      if (config != null && config.enableRaspProtection) {
        await _startRaspProtection(config);
      }

      await Hive.initFlutter(_storageDirectory);
      _registerAdapters();
      final key = await getOrCreateSecureKey();
      await openBoxes(key);

      if (_customBoxConfigs.isNotEmpty) {
        await _openCustomBoxes(_customBoxConfigs, key);
      }

      isVaultStorageReady = true;
    } catch (e, stackTrace) {
      _initFuture = null;
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageInitializationError('Failed to initialize vault storage', e),
        stackTrace,
      );
    }
  }

  @visibleForTesting
  Future<List<int>> getOrCreateSecureKey() async {
    try {
      final encodedKey = await _secureStorage.read(key: StorageKeys.secureKey);

      if (encodedKey == null) {
        final key = Hive.generateSecureKey();
        await _secureStorage.write(
          key: StorageKeys.secureKey,
          value: await key.encodeBase64Safely(context: 'master encryption key'),
        );
        return key;
      }

      return await encodedKey.decodeBase64Safely(context: 'secure storage key');
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(
        VaultStorageInitializationError('Failed to get/create secure key', e),
        stackTrace,
      );
    }
  }

  /// Custom compaction strategy - more aggressive for storage service
  bool _vaultCompactionStrategy(int entries, int deletedEntries) {
    if (entries == 0) return false;
    const deletedRatio = 0.10;
    const deletedThreshold = 30;
    return deletedEntries > deletedThreshold && deletedEntries / entries > deletedRatio;
  }

  @visibleForTesting
  Future<void> openBoxes(List<int> encryptionKey) async {
    try {
      final cipher = HiveAesCipher(encryptionKey);

      boxes[BoxType.secure] = await Hive.openBox<Object?>(
        StorageKeys.secureBox,
        encryptionCipher: cipher,
        compactionStrategy: _vaultCompactionStrategy,
      );
      boxes[BoxType.normal] = await Hive.openBox<Object?>(
        StorageKeys.normalBox,
        compactionStrategy: _vaultCompactionStrategy,
      );

      boxes[BoxType.secureFiles] = await Hive.openLazyBox<Object?>(
        StorageKeys.secureFilesBox,
        encryptionCipher: cipher,
        compactionStrategy: _vaultCompactionStrategy,
      );
      boxes[BoxType.normalFiles] = await Hive.openLazyBox<Object?>(
        StorageKeys.normalFilesBox,
        compactionStrategy: _vaultCompactionStrategy,
      );
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(
        VaultStorageInitializationError('Failed to open storage boxes', e),
        stackTrace,
      );
    }
  }

  /// Open custom boxes defined by user
  Future<void> _openCustomBoxes(List<BoxConfig> configs, List<int> encryptionKey) async {
    try {
      VaultStorageImpl.validateCustomBoxConfigs(configs);

      await inOrder(configs, (config) async {
        final BoxConfig(:name, :encrypted, :lazy) = config;
        final cipher = encrypted ? HiveAesCipher(encryptionKey) : null;

        if (lazy) {
          customBoxes[name] = await Hive.openLazyBox<Object?>(
            name,
            encryptionCipher: cipher,
            compactionStrategy: _vaultCompactionStrategy,
          );
        } else {
          customBoxes[name] = await Hive.openBox<Object?>(
            name,
            encryptionCipher: cipher,
            compactionStrategy: _vaultCompactionStrategy,
          );
        }
      }, reason: 'Boxes are opened in config order because it sets the lookup order');
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageInitializationError('Failed to open custom boxes', e),
        stackTrace,
      );
    }
  }
}

bool _registerAdapters() {
  VaultStorageAdapterRegistry.ensureRegistered();
  return Hive.isAdapterRegistered(StoredValueAdapter.storedValueTypeId);
}
