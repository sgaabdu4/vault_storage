part of 'vault_storage_impl.dart';

const _placeholderPackageName = 'your.package.name';
const _googlePlayStore = 'com.android.vending';
const _raspUnsupportedMessage =
    'VaultStorage: FreeRASP security features are only available on Android and iOS. Current platform:';

extension VaultStorageSecurity on VaultStorageImpl {
  /// Builds the FreeRASP Android configuration
  @visibleForTesting
  AndroidConfig androidConfigFor({String? packageName, List<String>? signingCertHashes}) {
    return AndroidConfig(
      packageName: switch (packageName) {
        final name? => name,
        null => _placeholderPackageName,
      },
      certificateHashes: switch (signingCertHashes) {
        final hashes? => hashes,
        null => <String>[],
      },
      supportedAlternativeStores: [_googlePlayStore],
    );
  }

  /// Builds the FreeRASP iOS configuration
  @visibleForTesting
  IOSConfig iosConfigFor({String? bundleId, String? teamId}) {
    return IOSConfig(
      appBundleIds: switch (bundleId) {
        final id? => [id],
        null => <String>[],
      },
      appTeamId: switch (teamId) {
        final team? => team,
        null => '',
      },
    );
  }

  TalsecConfig _talsecConfig(VaultSecurityConfig config) {
    final VaultSecurityConfig(
      :androidPackageName,
      :androidSigningCertHashes,
      :iosBundleId,
      :iosTeamId,
      :watcherMail,
      :isProd,
    ) = config;
    return TalsecConfig(
      androidConfig: androidConfigFor(
        packageName: androidPackageName,
        signingCertHashes: androidSigningCertHashes,
      ),
      iosConfig: iosConfigFor(bundleId: iosBundleId, teamId: iosTeamId),
      watcherMail: switch (watcherMail) {
        final mail? => mail,
        null => '',
      },
      isProd: isProd,
    );
  }

  @visibleForTesting
  ThreatCallback threatCallback() {
    return ThreatCallback(
      onPrivilegedAccess: () => _handleThreat(.jailbreak, 'Jailbreak/Root detected'),
      onAppIntegrity: () => _handleThreat(.tampering, 'App tampering detected'),
      onDebug: () => _handleThreat(.debugging, 'Debugger detected'),
      onHooks: () => _handleThreat(.hooks, 'Hooking framework detected'),
      onSimulator: () => _handleThreat(.emulator, 'Emulator detected'),
      onUnofficialStore: () => _handleThreat(.unofficialStore, 'Unofficial store detected'),
      onScreenshot: () => _handleThreat(.screenshot, 'Screenshot detected'),
      onScreenRecording: () => _handleThreat(.screenRecording, 'Screen recording detected'),
      onSystemVPN: () => _handleThreat(.systemVPN, 'System VPN detected'),
      onPasscode: () => _handleThreat(.passcode, 'Device passcode not set'),
      onSecureHardwareNotAvailable: () =>
          _handleThreat(.secureHardware, 'Secure hardware not available'),
      onDevMode: () => _handleThreat(.developerMode, 'Developer mode enabled'),
      onAdbEnabled: () => _handleThreat(.adbEnabled, 'ADB debugging enabled'),
      onMultiInstance: () => _handleThreat(.multiInstance, 'Multiple app instances detected'),
      onAutomation: () => _handleThreat(.automation, 'Automation tools detected'),
    );
  }

  /// Initialize FreeRASP protection when the platform supports it
  @visibleForTesting
  Future<void> startRaspProtection(VaultSecurityConfig config) async {
    final enableLogging = config.enableLogging;
    if (!_isSecuritySupportedOnCurrentPlatform()) {
      if (enableLogging) debugPrint('$_raspUnsupportedMessage ${defaultTargetPlatform.name}');
      return;
    }

    if (enableLogging) debugPrint('VaultStorage: Initializing RASP protection...');

    Talsec.instance.attachListener(threatCallback());
    await Talsec.instance.start(_talsecConfig(config));

    if (enableLogging) debugPrint('VaultStorage: RASP protection initialized successfully');
  }

  /// Check if FreeRASP security features are supported on the current platform
  bool _isSecuritySupportedOnCurrentPlatform() {
    return defaultTargetPlatform == .android || defaultTargetPlatform == .iOS;
  }

  /// Validate that the environment is secure for vault operations
  void _validateSecureEnvironment() {
    final config = _securityConfig;
    if (config == null || isSecureEnvironment || !_isSecuritySupportedOnCurrentPlatform()) return;

    if (SecurityThreat.values.any((threat) => _blocksThreat(threat, config))) {
      throw const SecurityThreatException(
        'Environment',
        'Vault operations blocked due to detected security threats',
      );
    }
  }

  void _handleThreat(SecurityThreat threat, String description) {
    final config = _securityConfig;
    if (config == null) return;
    final VaultSecurityConfig(:enableLogging, :threatCallbacks) = config;

    if (enableLogging) debugPrint('VaultStorage: $description');

    final environmentThreat = _environmentThreat(threat);
    if (environmentThreat != null) isSecureEnvironment = false;

    threatCallbacks?[threat]?.call();

    if (environmentThreat != null && _blocksThreat(threat, config)) throw environmentThreat;
  }

  SecurityThreatException? _environmentThreat(SecurityThreat threat) => switch (threat) {
    .jailbreak => const JailbreakDetectedException(),
    .tampering => const TamperingDetectedException(),
    .debugging => const DebugDetectedException(),
    .hooks => const HookingDetectedException(),
    .emulator => const EmulatorDetectedException(),
    .unofficialStore => const UnofficialStoreDetectedException(),
    _ => null,
  };

  bool _blocksThreat(SecurityThreat threat, VaultSecurityConfig config) {
    final VaultSecurityConfig(
      :blockOnJailbreak,
      :blockOnTampering,
      :blockOnDebug,
      :blockOnHooks,
      :blockOnEmulator,
      :blockOnUnofficialStore,
    ) = config;
    return switch (threat) {
      .jailbreak => blockOnJailbreak,
      .tampering => blockOnTampering,
      .debugging => blockOnDebug,
      .hooks => blockOnHooks,
      .emulator => blockOnEmulator,
      .unofficialStore => blockOnUnofficialStore,
      _ => false,
    };
  }
}
