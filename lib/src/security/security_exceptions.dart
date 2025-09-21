/// Exception thrown when a security threat is detected and vault operations are blocked
///
/// These exceptions are only thrown on Android and iOS platforms where
/// FreeRASP security monitoring is active. On other platforms, security
/// threats cannot be detected and these exceptions will never be thrown.
class SecurityThreatException implements Exception {
  /// The type of security threat that was detected
  final String threatType;

  /// Detailed message about the security threat
  final String message;

  /// The underlying cause of the exception, if any
  final Object? cause;

  const SecurityThreatException(this.threatType, this.message, [this.cause]);

  @override
  String toString() {
    final causeStr = cause != null ? ' (caused by: $cause)' : '';
    return 'SecurityThreatException: $threatType - $message$causeStr';
  }
}

/// Exception thrown when jailbreak/root access is detected
///
/// Only thrown on Android and iOS platforms where FreeRASP can detect
/// privileged access. Never thrown on other platforms.
class JailbreakDetectedException extends SecurityThreatException {
  const JailbreakDetectedException([Object? cause])
      : super('Jailbreak',
            'Device is jailbroken or rooted. Vault operations are blocked for security.', cause);
}

/// Exception thrown when app tampering is detected
///
/// Only thrown on Android and iOS platforms where FreeRASP can detect
/// app modifications. Never thrown on other platforms.
class TamperingDetectedException extends SecurityThreatException {
  const TamperingDetectedException([Object? cause])
      : super('Tampering', 'App tampering detected. Vault operations are blocked for security.',
            cause);
}

/// Exception thrown when debugging is detected
///
/// Only thrown on Android and iOS platforms where FreeRASP can detect
/// debugger attachment. Never thrown on other platforms.
class DebugDetectedException extends SecurityThreatException {
  const DebugDetectedException([Object? cause])
      : super(
            'Debug', 'Debugger detected. Vault operations are blocked in production mode.', cause);
}

/// Exception thrown when hooking frameworks are detected
///
/// Only thrown on Android and iOS platforms where FreeRASP can detect
/// runtime manipulation frameworks. Never thrown on other platforms.
class HookingDetectedException extends SecurityThreatException {
  const HookingDetectedException([Object? cause])
      : super('Hooks', 'Hooking framework detected. Vault operations are blocked for security.',
            cause);
}

/// Exception thrown when emulator is detected
///
/// Only thrown on Android and iOS platforms where FreeRASP can detect
/// virtual device environments. Never thrown on other platforms.
class EmulatorDetectedException extends SecurityThreatException {
  const EmulatorDetectedException([Object? cause])
      : super('Emulator', 'Emulator detected. Vault operations are blocked in production mode.',
            cause);
}

/// Exception thrown when unofficial store installation is detected
///
/// Only thrown on Android and iOS platforms where FreeRASP can detect
/// non-official app store installations. Never thrown on other platforms.
class UnofficialStoreDetectedException extends SecurityThreatException {
  const UnofficialStoreDetectedException([Object? cause])
      : super(
            'Unofficial Store',
            'App installed from unofficial store. Vault operations are blocked for security.',
            cause);
}
