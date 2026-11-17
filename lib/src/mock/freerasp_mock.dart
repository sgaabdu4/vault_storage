// Mock implementations for FreeRASP on platforms where it is unavailable.

import 'package:flutter/foundation.dart';

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
    required this.certificateHashes,
    required this.supportedAlternativeStores,
  });

  /// Package name
  final String packageName;

  /// Signing certificate hashes
  final List<String> certificateHashes;

  /// Supported stores
  final List<String> supportedAlternativeStores;
}

/// Mock iOS configuration
class IOSConfig {
  /// Creates a mock IOSConfig
  const IOSConfig({required this.appBundleIds, required this.appTeamId});

  /// Bundle IDs
  final List<String> appBundleIds;

  /// Team ID
  final String appTeamId;
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
    this.onAdbEnabled,
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
    this.onAutomation,
  });

  /// Privileged access callback
  final VoidCallback? onPrivilegedAccess;

  /// App integrity callback
  final VoidCallback? onAppIntegrity;

  /// Debug callback
  final VoidCallback? onDebug;

  /// Hooks callback
  final VoidCallback? onHooks;

  /// Simulator callback
  final VoidCallback? onSimulator;

  /// Unofficial store callback
  final VoidCallback? onUnofficialStore;

  /// Screenshot callback
  final VoidCallback? onScreenshot;

  /// Screen recording callback
  final VoidCallback? onScreenRecording;

  /// System VPN callback
  final VoidCallback? onSystemVPN;

  /// Passcode callback
  final VoidCallback? onPasscode;

  /// Secure hardware not available callback
  final VoidCallback? onSecureHardwareNotAvailable;

  /// Developer mode callback
  final VoidCallback? onDevMode;

  /// ADB enabled callback
  final VoidCallback? onAdbEnabled;

  /// Multi instance callback
  final VoidCallback? onMultiInstance;

  /// Jailbreak callback (legacy)
  final VoidCallback? onJailbreak;

  /// Debugger attached callback (legacy)
  final VoidCallback? onDebuggerAttached;

  /// Hooks detected callback (legacy)
  final VoidCallback? onHooksDetected;

  /// Tampered callback (legacy)
  final VoidCallback? onTampered;

  /// Emulator callback (legacy)
  final VoidCallback? onEmulator;

  /// Device binding callback (legacy)
  final VoidCallback? onDeviceBinding;

  /// Untrusted installer callback (legacy)
  final VoidCallback? onUntrustedInstaller;

  /// Screen capture detected callback (legacy)
  final VoidCallback? onScreenCaptureDetected;

  /// Obfuscation issues callback (legacy)
  final VoidCallback? onObfuscationIssues;

  /// Malware callback (legacy)
  final VoidCallback? onMalware;

  /// Device ID callback (legacy)
  final VoidCallback? onDeviceID;

  /// Passcode disabled callback (legacy)
  final VoidCallback? onPasscodeDisabled;

  /// Passcode change callback (legacy)
  final VoidCallback? onPasscodeChange;

  /// Biometry change callback (legacy)
  final VoidCallback? onBiometryChange;

  /// Automation callback
  final VoidCallback? onAutomation;
}

/// Mock Talsec instance
class Talsec {
  /// Mock singleton instance
  static const Talsec instance = ._();

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
