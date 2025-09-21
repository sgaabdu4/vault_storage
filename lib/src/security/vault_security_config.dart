/// Callback function type for handling security threats
///
/// These callbacks are only invoked on Android and iOS platforms where
/// FreeRASP can detect security threats. On other platforms, callbacks
/// will never be called as threats cannot be detected.
typedef SecurityThreatCallback = void Function();

/// Configuration for vault storage security features using FreeRASP
///
/// This configuration allows users to enable and customize jailbreak protection
/// and other security features for their vault storage.
///
/// **Important**: FreeRASP security features are only available on Android and iOS.
/// On other platforms (macOS, Windows, Linux, Web), the security configuration
/// will be ignored and vault storage will work normally without security monitoring.
///
/// Example:
/// ```dart
/// final securityConfig = VaultSecurityConfig(
///   enableRaspProtection: true,
///   isProd: false, // Development mode
///   watcherMail: 'security@myapp.com',
///   blockOnJailbreak: true,
///   threatCallbacks: {
///     SecurityThreat.jailbreak: () => print('Jailbreak detected!'),
///     SecurityThreat.tampering: () => exit(0),
///   },
/// );
/// ```
class VaultSecurityConfig {
  /// Whether to enable FreeRASP protection features
  final bool enableRaspProtection;

  /// Whether this is a production build
  /// - true: Enables all security features
  /// - false: Development mode with reduced security checks
  final bool isProd;

  /// Email for security notifications and monitoring
  final String? watcherMail;

  /// Custom callbacks for different security threats
  final Map<SecurityThreat, SecurityThreatCallback>? threatCallbacks;

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
    this.threatCallbacks,
    this.blockOnJailbreak = true,
    this.blockOnDebug = false,
    this.blockOnTampering = true,
    this.blockOnHooks = true,
    this.blockOnEmulator = false,
    this.blockOnUnofficialStore = false,
    this.enableLogging = false,
  });

  /// Creates a development-friendly configuration
  ///
  /// This configuration is suitable for development and testing:
  /// - Production mode disabled
  /// - Most blocking features disabled
  /// - Logging enabled
  ///
  /// **Note**: Security features only work on Android and iOS platforms.
  /// On other platforms, this configuration will be ignored.
  static VaultSecurityConfig development({
    String? watcherMail,
    Map<SecurityThreat, SecurityThreatCallback>? threatCallbacks,
  }) {
    return VaultSecurityConfig(
      enableRaspProtection: true,
      isProd: false,
      watcherMail: watcherMail,
      threatCallbacks: threatCallbacks,
      blockOnJailbreak: false,
      blockOnTampering: false,
      blockOnHooks: false,
      enableLogging: true,
    );
  }

  /// Creates a production-ready configuration
  ///
  /// This configuration provides maximum security for production:
  /// - Production mode enabled
  /// - All critical security features enabled
  /// - Blocks on major threats
  ///
  /// **Note**: Security features only work on Android and iOS platforms.
  /// On other platforms, this configuration will be ignored.
  static VaultSecurityConfig production({
    required String watcherMail,
    Map<SecurityThreat, SecurityThreatCallback>? threatCallbacks,
  }) {
    return VaultSecurityConfig(
      enableRaspProtection: true,
      watcherMail: watcherMail,
      threatCallbacks: threatCallbacks,
      blockOnDebug: true,
      blockOnUnofficialStore: true,
    );
  }

  /// Copies this config with updated values
  VaultSecurityConfig copyWith({
    bool? enableRaspProtection,
    bool? isProd,
    String? watcherMail,
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
    return 'VaultSecurityConfig('
        'enableRaspProtection: $enableRaspProtection, '
        'isProd: $isProd, '
        'watcherMail: ${watcherMail != null ? '***' : 'null'}, '
        'blockOnJailbreak: $blockOnJailbreak, '
        'blockOnDebug: $blockOnDebug, '
        'blockOnTampering: $blockOnTampering, '
        'blockOnHooks: $blockOnHooks, '
        'blockOnEmulator: $blockOnEmulator, '
        'blockOnUnofficialStore: $blockOnUnofficialStore, '
        'enableLogging: $enableLogging'
        ')';
  }
}

/// Types of security threats that can be detected
///
/// These threats are only detectable on Android and iOS platforms where
/// FreeRASP can monitor device and app security. On other platforms,
/// these threats will never be detected or reported.
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
}
