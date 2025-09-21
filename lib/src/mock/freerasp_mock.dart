// Mock implementations for FreeRASP that are used on platforms where
// FreeRASP is not available (Web, Windows, Linux, macOS)

/// Mock configuration for Talsec/FreeRASP
class TalsecConfig {
  /// Creates a mock TalsecConfig
  const TalsecConfig({
    required this.androidConfig,
    required this.iosConfig,
    required this.watcherMail,
    required this.isProd,
  });

  /// Android configuration
  final AndroidConfig androidConfig;

  /// iOS configuration
  final IOSConfig iosConfig;

  /// Watcher email
  final String watcherMail;

  /// Production mode flag
  final bool isProd;
}

/// Mock Android configuration
class AndroidConfig {
  /// Creates a mock AndroidConfig
  const AndroidConfig({
    required this.packageName,
    required this.signingCertHashes,
    required this.supportedStores,
  });

  /// Package name
  final String packageName;

  /// Signing certificate hashes
  final List<String> signingCertHashes;

  /// Supported stores
  final List<String> supportedStores;
}

/// Mock iOS configuration
class IOSConfig {
  /// Creates a mock IOSConfig
  const IOSConfig({
    required this.bundleIds,
    required this.teamId,
  });

  /// Bundle IDs
  final List<String> bundleIds;

  /// Team ID
  final String teamId;
}

/// Mock threat callback
class ThreatCallback {
  /// Creates a mock ThreatCallback
  const ThreatCallback({
    this.onPrivilegedAccess,
    this.onAppIntegrity,
    this.onDebug,
    this.onHooks,
    this.onSimulator,
    this.onUnofficialStore,
    this.onScreenshot,
    this.onScreenRecording,
    this.onSystemVPN,
    this.onPasscode,
    this.onSecureHardwareNotAvailable,
    this.onDevMode,
    this.onADBEnabled,
    this.onMultiInstance,
    this.onJailbreak,
    this.onDebuggerAttached,
    this.onHooksDetected,
    this.onTampered,
    this.onEmulator,
    this.onDeviceBinding,
    this.onUntrustedInstaller,
    this.onScreenCaptureDetected,
    this.onObfuscationIssues,
    this.onMalware,
    this.onDeviceID,
    this.onPasscodeDisabled,
    this.onPasscodeChange,
    this.onBiometryChange,
  });

  /// Privileged access callback
  final void Function()? onPrivilegedAccess;

  /// App integrity callback
  final void Function()? onAppIntegrity;

  /// Debug callback
  final void Function()? onDebug;

  /// Hooks callback
  final void Function()? onHooks;

  /// Simulator callback
  final void Function()? onSimulator;

  /// Unofficial store callback
  final void Function()? onUnofficialStore;

  /// Screenshot callback
  final void Function()? onScreenshot;

  /// Screen recording callback
  final void Function()? onScreenRecording;

  /// System VPN callback
  final void Function()? onSystemVPN;

  /// Passcode callback
  final void Function()? onPasscode;

  /// Secure hardware not available callback
  final void Function()? onSecureHardwareNotAvailable;

  /// Developer mode callback
  final void Function()? onDevMode;

  /// ADB enabled callback
  final void Function()? onADBEnabled;

  /// Multi instance callback
  final void Function()? onMultiInstance;

  /// Jailbreak callback (legacy)
  final void Function()? onJailbreak;

  /// Debugger attached callback (legacy)
  final void Function()? onDebuggerAttached;

  /// Hooks detected callback (legacy)
  final void Function()? onHooksDetected;

  /// Tampered callback (legacy)
  final void Function()? onTampered;

  /// Emulator callback (legacy)
  final void Function()? onEmulator;

  /// Device binding callback (legacy)
  final void Function()? onDeviceBinding;

  /// Untrusted installer callback (legacy)
  final void Function()? onUntrustedInstaller;

  /// Screen capture detected callback (legacy)
  final void Function()? onScreenCaptureDetected;

  /// Obfuscation issues callback (legacy)
  final void Function()? onObfuscationIssues;

  /// Malware callback (legacy)
  final void Function()? onMalware;

  /// Device ID callback (legacy)
  final void Function()? onDeviceID;

  /// Passcode disabled callback (legacy)
  final void Function()? onPasscodeDisabled;

  /// Passcode change callback (legacy)
  final void Function()? onPasscodeChange;

  /// Biometry change callback (legacy)
  final void Function()? onBiometryChange;
}

/// Mock Talsec instance
class Talsec {
  /// Mock singleton instance
  static const Talsec instance = Talsec._();

  const Talsec._();

  /// Mock attach listener - does nothing on unsupported platforms
  void attachListener(ThreatCallback callback) {
    // No-op on unsupported platforms
  }

  /// Mock start - does nothing on unsupported platforms
  Future<void> start(TalsecConfig config) async {
    // No-op on unsupported platforms
  }
}
