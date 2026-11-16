import 'package:example/l10n/app_localizations.dart';
import 'package:vault_storage/vault_storage.dart';

String initializationFailure(AppLocalizations l10n, Object error) => switch (error) {
  JailbreakDetectedException() => l10n.failureJailbreak,
  TamperingDetectedException() => l10n.failureTampering,
  SecurityThreatException(:final threatType, :final message) => l10n.failureThreat(
    threatType,
    message,
  ),
  _ => l10n.failureInitialization('$error'),
};
