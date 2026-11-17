/// Callback function type for handling security threats
typedef SecurityThreatCallback = void Function();

/// Configuration for vault storage security features using FreeRASP
class VaultSecurityConfig {
  /// Whether to enable FreeRASP protection features
  final bool enableRaspProtection;

  /// Whether this is a production build
  final bool isProd;

  /// Email for security notifications and monitoring dashboard
  final String? watcherMail;

  /// Android package name (e.g., 'com.example.app')
  final String? androidPackageName;

  /// Android signing certificate hashes in Base64 format
  final List<String> androidSigningCertHashes;

  /// iOS bundle identifier (e.g., 'com.example.app')
  final String? iosBundleId;

  /// iOS team identifier from Apple Developer account
  final String? iosTeamId;

  /// Custom callbacks for different security threats
  final Map<SecurityThreat, SecurityThreatCallback> threatCallbacks;

  /// Whether to block vault operations when jailbreak is detected
  final bool blockOnJailbreak;

  /// Whether to block vault operations when debugging is detected
  final bool blockOnDebug;

  /// Whether to block vault operations when app tampering is detected
  final bool blockOnTampering;

  /// Whether to block vault operations when hooks are detected
  final bool blockOnHooks;

  /// Whether to block vault operations when emulator is detected
  final bool blockOnEmulator;

  /// Whether to block vault operations when unofficial store is detected
  final bool blockOnUnofficialStore;

  /// Whether to log security events for debugging
  final bool enableLogging;

  const VaultSecurityConfig({
    this.enableRaspProtection = false,
    this.isProd = true,
    this.watcherMail,
    this.androidPackageName,
    this.androidSigningCertHashes = const [],
    this.iosBundleId,
    this.iosTeamId,
    this.threatCallbacks = const {},
    this.blockOnJailbreak = true,
    this.blockOnDebug = false,
    this.blockOnTampering = true,
    this.blockOnHooks = true,
    this.blockOnEmulator = false,
    this.blockOnUnofficialStore = false,
    this.enableLogging = false,
  });

  /// Creates a development-friendly configuration for testing
  static VaultSecurityConfig development({
    String? watcherMail,
    String? androidPackageName,
    List<String> androidSigningCertHashes = const [],
    String? iosBundleId,
    String? iosTeamId,
    Map<SecurityThreat, SecurityThreatCallback> threatCallbacks = const {},
  }) {
    return VaultSecurityConfig(
      enableRaspProtection: true,
      isProd: false,
      watcherMail: watcherMail,
      androidPackageName: androidPackageName,
      androidSigningCertHashes: androidSigningCertHashes,
      iosBundleId: iosBundleId,
      iosTeamId: iosTeamId,
      threatCallbacks: threatCallbacks,
      blockOnJailbreak: false,
      blockOnTampering: false,
      blockOnHooks: false,
      enableLogging: true,
    );
  }

  /// Creates a production-ready configuration with strict security
  static VaultSecurityConfig production({
    required String watcherMail,
    String? androidPackageName, // Required for Android
    List<String> androidSigningCertHashes = const [], // Required for Android
    String? iosBundleId, // Required for iOS
    String? iosTeamId, // Required for iOS
    Map<SecurityThreat, SecurityThreatCallback> threatCallbacks = const {},
  }) {
    return VaultSecurityConfig(
      enableRaspProtection: true,
      watcherMail: watcherMail,
      androidPackageName: androidPackageName,
      androidSigningCertHashes: androidSigningCertHashes,
      iosBundleId: iosBundleId,
      iosTeamId: iosTeamId,
      threatCallbacks: threatCallbacks,
      blockOnDebug: true, // Block debugging in production
      blockOnUnofficialStore: true,
      // enableLogging defaults to false
    );
  }

  /// Copies this config with updated values
  VaultSecurityConfig copyWith({
    bool? enableRaspProtection,
    bool? isProd,
    String? watcherMail,
    String? androidPackageName,
    List<String>? androidSigningCertHashes,
    String? iosBundleId,
    String? iosTeamId,
    Map<SecurityThreat, SecurityThreatCallback>? threatCallbacks,
    bool? blockOnJailbreak,
    bool? blockOnDebug,
    bool? blockOnTampering,
    bool? blockOnHooks,
    bool? blockOnEmulator,
    bool? blockOnUnofficialStore,
    bool? enableLogging,
  }) {
    return VaultSecurityConfig(
      enableRaspProtection: enableRaspProtection ?? this.enableRaspProtection,
      isProd: isProd ?? this.isProd,
      watcherMail: watcherMail ?? this.watcherMail,
      androidPackageName: androidPackageName ?? this.androidPackageName,
      androidSigningCertHashes: androidSigningCertHashes ?? this.androidSigningCertHashes,
      iosBundleId: iosBundleId ?? this.iosBundleId,
      iosTeamId: iosTeamId ?? this.iosTeamId,
      threatCallbacks: threatCallbacks ?? this.threatCallbacks,
      blockOnJailbreak: blockOnJailbreak ?? this.blockOnJailbreak,
      blockOnDebug: blockOnDebug ?? this.blockOnDebug,
      blockOnTampering: blockOnTampering ?? this.blockOnTampering,
      blockOnHooks: blockOnHooks ?? this.blockOnHooks,
      blockOnEmulator: blockOnEmulator ?? this.blockOnEmulator,
      blockOnUnofficialStore: blockOnUnofficialStore ?? this.blockOnUnofficialStore,
      enableLogging: enableLogging ?? this.enableLogging,
    );
  }

  @override
  String toString() {
    final fields = [
      'enableRaspProtection: $enableRaspProtection',
      'isProd: $isProd',
      'watcherMail: ${watcherMail != null ? '***' : 'null'}',
      'blockOnJailbreak: $blockOnJailbreak',
      'blockOnDebug: $blockOnDebug',
      'blockOnTampering: $blockOnTampering',
      'blockOnHooks: $blockOnHooks',
      'blockOnEmulator: $blockOnEmulator',
      'blockOnUnofficialStore: $blockOnUnofficialStore',
      'enableLogging: $enableLogging',
    ];
    return 'VaultSecurityConfig(${fields.join(', ')})';
  }
}

/// Types of security threats that can be detected
enum SecurityThreat {
  /// Device is jailbroken or rooted
  jailbreak,

  /// App has been tampered with or repackaged
  tampering,

  /// Debugger is attached to the app
  debugging,

  /// Hooking frameworks detected (e.g., Frida)
  hooks,

  /// App is running on an emulator
  emulator,

  /// App was installed from unofficial store
  unofficialStore,

  /// Screenshot was taken
  screenshot,

  /// Screen recording detected
  screenRecording,

  /// System VPN detected
  systemVPN,

  /// Device passcode not set
  passcode,

  /// Secure hardware not available
  secureHardware,

  /// Developer mode enabled
  developerMode,

  /// ADB debugging enabled
  adbEnabled,

  /// Multiple instances of app running
  multiInstance,

  /// Automation tools detected
  automation,
}
