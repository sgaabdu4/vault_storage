import 'package:example/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:vault_storage/vault_storage.dart';

typedef ThreatLabel = String Function(AppLocalizations l10n);

abstract final class DemoStorageConfig {
  static const String watcherMail = 'security@example.com';
  static const String iosBundleId = 'com.example.storageService.example';
  static const String iosTeamId = 'YOUR_TEAM_ID';
  static const String keyFileName = 'flutter_secure_storage.dat';
}

IVaultStorage createDemoStorage(ValueChanged<ThreatLabel> onThreat) => VaultStorage.create(
  securityConfig: .production(
    watcherMail: DemoStorageConfig.watcherMail,
    iosBundleId: DemoStorageConfig.iosBundleId,
    iosTeamId: DemoStorageConfig.iosTeamId,
    threatCallbacks: {
      .jailbreak: () => onThreat((l10n) => l10n.threatJailbreak),
      .tampering: () => onThreat((l10n) => l10n.threatTampering),
      .debugging: () => onThreat((l10n) => l10n.threatDebugging),
      .emulator: () => onThreat((l10n) => l10n.threatEmulator),
      .hooks: () => onThreat((l10n) => l10n.threatHooks),
      .unofficialStore: () => onThreat((l10n) => l10n.threatUnofficialStore),
      .screenshot: () => onThreat((l10n) => l10n.threatScreenshot),
      .screenRecording: () => onThreat((l10n) => l10n.threatScreenRecording),
      .systemVPN: () => onThreat((l10n) => l10n.threatSystemVpn),
      .passcode: () => onThreat((l10n) => l10n.threatPasscode),
      .secureHardware: () => onThreat((l10n) => l10n.threatSecureHardware),
      .developerMode: () => onThreat((l10n) => l10n.threatDeveloperMode),
      .adbEnabled: () => onThreat((l10n) => l10n.threatAdbEnabled),
      .multiInstance: () => onThreat((l10n) => l10n.threatMultiInstance),
    },
  ),
);

enum KeyFilePresence { yes, no }
