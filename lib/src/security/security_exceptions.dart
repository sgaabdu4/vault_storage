/// Exception thrown when a security threat is detected and vault operations are blocked
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
    final causeStr = switch (cause) {
      final Object cause => ' (caused by: $cause)',
      null => '',
    };
    return 'SecurityThreatException: $threatType - $message$causeStr';
  }
}

/// Exception thrown when jailbreak/root access is detected
class JailbreakDetectedException extends SecurityThreatException {
  const JailbreakDetectedException([Object? cause])
    : super(
        'Jailbreak',
        'Device is jailbroken or rooted. Vault operations are blocked for security.',
        cause,
      );
}

/// Exception thrown when app tampering is detected
class TamperingDetectedException extends SecurityThreatException {
  const TamperingDetectedException([Object? cause])
    : super(
        'Tampering',
        'App tampering detected. Vault operations are blocked for security.',
        cause,
      );
}

/// Exception thrown when debugging is detected
class DebugDetectedException extends SecurityThreatException {
  const DebugDetectedException([Object? cause])
    : super('Debug', 'Debugger detected. Vault operations are blocked in production mode.', cause);
}

/// Exception thrown when hooking frameworks are detected
class HookingDetectedException extends SecurityThreatException {
  const HookingDetectedException([Object? cause])
    : super(
        'Hooks',
        'Hooking framework detected. Vault operations are blocked for security.',
        cause,
      );
}

/// Exception thrown when emulator is detected
class EmulatorDetectedException extends SecurityThreatException {
  const EmulatorDetectedException([Object? cause])
    : super(
        'Emulator',
        'Emulator detected. Vault operations are blocked in production mode.',
        cause,
      );
}

/// Exception thrown when unofficial store installation is detected
class UnofficialStoreDetectedException extends SecurityThreatException {
  const UnofficialStoreDetectedException([Object? cause])
    : super(
        'Unofficial Store',
        'App installed from unofficial store. Vault operations are blocked for security.',
        cause,
      );
}
