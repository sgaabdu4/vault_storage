part of 'vault_storage_impl.dart';

extension VaultStorageImplSupport on VaultStorageImpl {
  Future<void> _doInit() async {
    try {
      // Initialize RASP protection first if enabled and on supported platforms
      if (_securityConfig?.enableRaspProtection == true) {
        // FreeRASP only supports Android and iOS
        if (_isSecuritySupportedOnCurrentPlatform()) {
          await _initializeRaspProtection(
            packageName: _securityConfig?.androidPackageName,
            signingCertHashes: _securityConfig?.androidSigningCertHashes,
            bundleId: _securityConfig?.iosBundleId,
            teamId: _securityConfig?.iosTeamId,
          );
        } else {
          // Log that security features are not available on this platform
          if (_securityConfig?.enableLogging == true) {
            debugPrint(
              'VaultStorage: FreeRASP security features are only available on Android and iOS. '
              'Current platform: ${defaultTargetPlatform.name}',
            );
          }
        }
      }

      await Hive.initFlutter(_storageDirectory);
      _registerAdapters();
      final key = await getOrCreateSecureKey();
      await openBoxes(key);

      // Open custom boxes if provided
      if (_customBoxConfigs != null && _customBoxConfigs.isNotEmpty) {
        await _openCustomBoxes(_customBoxConfigs, key);
      }

      isVaultStorageReady = true;
    } catch (e) {
      _initFuture = null;
      if (e is VaultStorageError) rethrow;
      throw VaultStorageInitializationError('Failed to initialize vault storage', e);
    }
  }

  /// Get value from a specific box (supports both Box and LazyBox)
  @visibleForTesting
  Future<T?> getFromBox<T>(BoxType boxType, String key) async {
    final box = boxes[boxType];
    return box == null ? null : await _getFromBoxBase<T>(box, key);
  }

  /// Get value from any BoxBase (handles Box and LazyBox, with legacy support)
  Future<T?> _getFromBoxBase<T>(BoxBase<dynamic> box, String key) async {
    if (!box.containsKey(key)) return null;

    // Get value (sync for Box, async for LazyBox)
    final stored = box is LazyBox<dynamic> ? await box.get(key) : (box as Box<dynamic>).get(key);
    if (stored == null) return null;

    // Legacy support - if it's a plain string, decode as JSON
    if (stored is String) {
      return stored.decodeJsonSafely<T>();
    }

    // v4.x format: TypeAdapter-deserialized StoredValue
    if (stored is StoredValue) {
      if (stored.strategy == StorageStrategy.native) return _coerceToType<T>(stored.value);
      return (stored.value as String).decodeJsonSafely<T>();
    }

    // v3.x format - check if it's a Map-wrapped StoredValue
    if (stored is Map && StoredValue.isWrapped(stored)) {
      final wrapper = StoredValue.fromHiveMap(stored);

      if (wrapper.strategy == StorageStrategy.native) {
        // Native storage - may need type coercion for primitives
        return _coerceToType<T>(wrapper.value);
      } else {
        // JSON strategy - decode the JSON string
        final jsonString = wrapper.value as String;
        return jsonString.decodeJsonSafely<T>();
      }
    }

    // Fallback for unexpected format or raw primitive values
    // Handle type coercion for primitives that may have been stored directly
    return _coerceToType<T>(stored);
  }

  /// Coerces a value to the expected type T
  ///
  /// Handles backward compatibility for values that may be stored as different types.
  /// Throws VaultStorageReadError on type mismatch to allow graceful error handling.
  T _coerceToType<T>(dynamic value) {
    // If value is already the correct type, return it
    if (value is T) return value;

    // Simple type conversions only - no complex migrations
    if (T == int && value is num) return value.toInt() as T;
    if (T == double && value is num) return value.toDouble() as T;
    if (T == String && value != null) return value.toString() as T;

    // Hive deserializes Maps as Map<dynamic, dynamic>; coerce to Map<String, dynamic>
    if (value is Map) {
      final coerced = <String, dynamic>{
        for (final entry in value.entries) entry.key.toString(): entry.value,
      };
      if (coerced is T) return coerced as T;
    }

    // Type mismatch - throw clear error
    throw VaultStorageReadError(
      'Type mismatch: Cannot convert stored value to type $T. '
      'Stored: "$value" (${value.runtimeType}), Expected: $T. '
      'Consider clearing this key if the data is corrupted.',
    );
  }

  /// Set value in a specific box
  @visibleForTesting
  Future<void> setInBox<T>(BoxType boxType, String key, T value) async {
    final box = boxes[boxType];
    if (box == null) {
      throw VaultStorageInitializationError(
        'Box ${boxType.name} not opened. Ensure init() was called.',
      );
    }
    await _putInBoxBase(box, key, value);
  }

  /// Put value into any BoxBase (handles both Box and LazyBox)
  Future<void> _putInBoxBase<T>(BoxBase<dynamic> box, String key, T value) async {
    final strategy = StorageStrategyHelper.determineStrategy(value);

    final toStore = strategy == StorageStrategy.native
        ? StoredValue(value, strategy)
        : StoredValue(await value.encodeJsonSafely(), strategy);

    // Put into box (both Box and LazyBox have async put)
    await box.put(key, toStore);
  }

  /// Registers Hive TypeAdapters for vault_storage types.
  ///
  /// Guards each registration with [isAdapterRegistered] so it is safe to call
  /// multiple times (e.g., in tests that re-initialise storage).
  void _registerAdapters() {
    VaultStorageAdapterRegistry.ensureRegistered();
  }

  /// Get file metadata with optional storage type specification
  @visibleForTesting
  Future<Map<String, dynamic>?> getFileMetadata(String key, {bool? isSecure}) async {
    // Helper to get metadata from a specific box
    Future<Map<String, dynamic>?> getFromFileBox(BoxType boxType, bool isSecureFile) async {
      final box = boxes[boxType];
      if (box == null || !box.containsKey(key)) return null;

      try {
        // Route through _getFromBoxBase to handle all storage formats uniformly:
        //   v2.x  → plain JSON string
        //   v3.x  → Map-wrapped StoredValue
        //   v4.x  → TypeAdapter StoredValue
        final result = await _getFromBoxBase<Map<String, dynamic>>(box, key);
        if (result == null) return null;
        return <String, dynamic>{...result, 'isSecure': isSecureFile};
      } on VaultStorageError {
        rethrow;
      } catch (_) {
        return null;
      }
    }

    // If isSecure specified, check only that box
    if (isSecure == false) return getFromFileBox(BoxType.normalFiles, false);
    if (isSecure == true) return getFromFileBox(BoxType.secureFiles, true);

    // Otherwise, check both (normal first, then secure)
    return await getFromFileBox(BoxType.normalFiles, false) ??
        await getFromFileBox(BoxType.secureFiles, true);
  }

  /// Get a box from storage - returns the box directly
  @visibleForTesting
  BoxBase<dynamic> getInternalBox(BoxType type) {
    return boxes[type]!;
  }

  /// Clear all files (underlying content + metadata) within a specific files box.
  /// Best-effort: continues on per-item failures. Throws if box.clear() fails.
  @visibleForTesting
  Future<void> clearAllFilesInBox(BoxType boxType, {required bool isSecure}) async {
    final box = boxes[boxType];
    if (box == null) return;

    // Get all keys (both Box and LazyBox expose keys)
    final keyIterable = box.keys;

    for (final key in keyIterable.whereType<String>()) {
      try {
        final metadata = await getFileMetadata(key, isSecure: isSecure);
        if (metadata == null) continue;

        // Delete underlying file
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
      } catch (_) {
        // Ignore per-file errors; final clear() will drop metadata
      }
    }

    await box.clear();
  }

  // ==========================================
  // SECURITY METHODS (Android/iOS only)
  // ==========================================

  /// Initialize FreeRASP protection with the provided configuration
  ///
  /// This method is only called on Android and iOS platforms.
  /// On other platforms, security initialization is skipped automatically.
  Future<void> _initializeRaspProtection({
    String? packageName, // Keep internal param name for FreeRASP API
    List<String>? signingCertHashes, // Keep internal param name for FreeRASP API
    String? bundleId, // Keep internal param name for FreeRASP API
    String? teamId, // Keep internal param name for FreeRASP API
  }) async {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Initializing RASP protection...');
    }

    final talsecConfig = TalsecConfig(
      androidConfig: AndroidConfig(
        packageName: packageName ?? 'your.package.name',
        signingCertHashes: signingCertHashes ?? [],
        supportedStores: ['com.android.vending'], // Google Play Store
      ),
      iosConfig: IOSConfig(bundleIds: bundleId != null ? [bundleId] : [], teamId: teamId ?? ''),
      watcherMail: config.watcherMail ?? '',
      isProd: config.isProd,
    );

    final threatCallback = ThreatCallback(
      onPrivilegedAccess: () => _handleJailbreakDetection(),
      onAppIntegrity: () => _handleTamperingDetection(),
      onDebug: () => _handleDebugDetection(),
      onHooks: () => _handleHookingDetection(),
      onSimulator: () => _handleEmulatorDetection(),
      onUnofficialStore: () => _handleUnofficialStoreDetection(),
      onScreenshot: () => _handleScreenshotDetection(),
      onScreenRecording: () => _handleScreenRecordingDetection(),
      onSystemVPN: () => _handleSystemVPNDetection(),
      onPasscode: () => _handlePasscodeDetection(),
      onSecureHardwareNotAvailable: () => _handleSecureHardwareDetection(),
      onDevMode: () => _handleDeveloperModeDetection(),
      onADBEnabled: () => _handleADBDetection(),
      onMultiInstance: () => _handleMultiInstanceDetection(),
      onAutomation: () => _handleAutomationDetection(),
    );

    Talsec.instance.attachListener(threatCallback);
    await Talsec.instance.start(talsecConfig);

    if (config.enableLogging) {
      debugPrint('VaultStorage: RASP protection initialized successfully');
    }
  }

  /// Check if FreeRASP security features are supported on the current platform
  bool _isSecuritySupportedOnCurrentPlatform() {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Validate that the environment is secure for vault operations
  void _validateSecureEnvironment() {
    final config = _securityConfig;
    if (config == null) return;

    // Only validate if security features are supported on this platform
    if (!_isSecuritySupportedOnCurrentPlatform()) {
      return;
    }

    if (!isSecureEnvironment) {
      if (config.blockOnJailbreak ||
          config.blockOnTampering ||
          config.blockOnHooks ||
          config.blockOnDebug ||
          config.blockOnEmulator ||
          config.blockOnUnofficialStore) {
        throw const SecurityThreatException(
          'Environment',
          'Vault operations blocked due to detected security threats',
        );
      }
    }
  }

  /// Handle jailbreak/root detection
  void _handleJailbreakDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Jailbreak/Root detected');
    }

    isSecureEnvironment = false;

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.jailbreak]?.call();

    if (config.blockOnJailbreak) {
      throw const JailbreakDetectedException();
    }
  }

  /// Handle app tampering detection
  void _handleTamperingDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: App tampering detected');
    }

    isSecureEnvironment = false;

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.tampering]?.call();

    if (config.blockOnTampering) {
      throw const TamperingDetectedException();
    }
  }

  /// Handle debug detection
  void _handleDebugDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Debugger detected');
    }

    isSecureEnvironment = false;

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.debugging]?.call();

    if (config.blockOnDebug) {
      throw const DebugDetectedException();
    }
  }

  /// Handle hooking framework detection
  void _handleHookingDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Hooking framework detected');
    }

    isSecureEnvironment = false;

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.hooks]?.call();

    if (config.blockOnHooks) {
      throw const HookingDetectedException();
    }
  }

  /// Handle emulator detection
  void _handleEmulatorDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Emulator detected');
    }

    isSecureEnvironment = false;

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.emulator]?.call();

    if (config.blockOnEmulator) {
      throw const EmulatorDetectedException();
    }
  }

  /// Handle unofficial store detection
  void _handleUnofficialStoreDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Unofficial store detected');
    }

    isSecureEnvironment = false;

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.unofficialStore]?.call();

    if (config.blockOnUnofficialStore) {
      throw const UnofficialStoreDetectedException();
    }
  }

  /// Handle screenshot detection
  void _handleScreenshotDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Screenshot detected');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.screenshot]?.call();
  }

  /// Handle screen recording detection
  void _handleScreenRecordingDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Screen recording detected');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.screenRecording]?.call();
  }

  /// Handle system VPN detection
  void _handleSystemVPNDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: System VPN detected');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.systemVPN]?.call();
  }

  /// Handle passcode detection
  void _handlePasscodeDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Device passcode not set');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.passcode]?.call();
  }

  /// Handle secure hardware detection
  void _handleSecureHardwareDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Secure hardware not available');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.secureHardware]?.call();
  }

  /// Handle developer mode detection
  void _handleDeveloperModeDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Developer mode enabled');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.developerMode]?.call();
  }

  /// Handle ADB detection
  void _handleADBDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: ADB debugging enabled');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.adbEnabled]?.call();
  }

  /// Handle multiple instance detection
  void _handleMultiInstanceDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Multiple app instances detected');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.multiInstance]?.call();
  }

  /// Handle automation detection
  void _handleAutomationDetection() {
    final config = _securityConfig!;

    if (config.enableLogging) {
      debugPrint('VaultStorage: Automation tools detected');
    }

    // Call user-defined callback if provided
    config.threatCallbacks?[SecurityThreat.automation]?.call();
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
    } catch (e) {
      throw VaultStorageInitializationError('Failed to get/create secure key', e);
    }
  }

  /// Custom compaction strategy - more aggressive for storage service
  /// 10% deletion ratio threshold (vs default 15%), 30 deleted entries minimum (vs 60)
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

      // Open key-value storage boxes (normal boxes for fast access)
      boxes[BoxType.secure] = await Hive.openBox<dynamic>(
        StorageKeys.secureBox,
        encryptionCipher: cipher,
        compactionStrategy: _vaultCompactionStrategy,
      );
      boxes[BoxType.normal] = await Hive.openBox<dynamic>(
        StorageKeys.normalBox,
        compactionStrategy: _vaultCompactionStrategy,
      );

      // Open file storage boxes (lazy boxes for better memory usage)
      boxes[BoxType.secureFiles] = await Hive.openLazyBox<dynamic>(
        StorageKeys.secureFilesBox,
        encryptionCipher: cipher,
        compactionStrategy: _vaultCompactionStrategy,
      );
      boxes[BoxType.normalFiles] = await Hive.openLazyBox<dynamic>(
        StorageKeys.normalFilesBox,
        compactionStrategy: _vaultCompactionStrategy,
      );
    } catch (e) {
      throw VaultStorageInitializationError('Failed to open storage boxes', e);
    }
  }

  /// Open custom boxes defined by user
  Future<void> _openCustomBoxes(List<BoxConfig> configs, List<int> encryptionKey) async {
    try {
      VaultStorageImpl.validateCustomBoxConfigs(configs);

      for (final config in configs) {
        final cipher = config.encrypted ? HiveAesCipher(encryptionKey) : null;

        if (config.lazy) {
          customBoxes[config.name] = await Hive.openLazyBox<dynamic>(
            config.name,
            encryptionCipher: cipher,
            compactionStrategy: _vaultCompactionStrategy,
          );
        } else {
          customBoxes[config.name] = await Hive.openBox<dynamic>(
            config.name,
            encryptionCipher: cipher,
            compactionStrategy: _vaultCompactionStrategy,
          );
        }
      }
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageInitializationError('Failed to open custom boxes', e);
    }
  }
}
