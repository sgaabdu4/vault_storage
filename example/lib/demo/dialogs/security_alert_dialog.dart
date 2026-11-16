import 'package:example/design/spacing.dart';
import 'package:example/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class SecurityAlertDialog extends StatelessWidget {
  const SecurityAlertDialog({required this.threats, super.key});

  final List<String> threats;

  static Future<void> show(BuildContext context, {required List<String> threats}) =>
      showAdaptiveDialog<void>(
        context: context,
        barrierDismissible: false,
        routeSettings: const RouteSettings(name: 'SecurityAlertDialog'),
        builder: (context) => SecurityAlertDialog(threats: threats),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog.adaptive(
      title: Text(l10n.securityAlertTitle),
      content: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        spacing: Spacing.sm,
        children: [
          Text(l10n.securityIssuesDetected, style: Theme.of(context).textTheme.titleSmall),
          Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            spacing: Spacing.xs,
            children: [for (final String threat in threats) Text(l10n.securityThreatItem(threat))],
          ),
          Text(l10n.securityFunctionalityLimited),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.ok))],
    );
  }
}
