import 'package:example/demo/demo_button.dart';
import 'package:example/demo/demo_keys.dart';
import 'package:example/demo/storage_kind.dart';
import 'package:example/design/spacing.dart';
import 'package:example/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class ClearSection extends StatelessWidget {
  const ClearSection({required this.enabled, required this.onClear, super.key});

  final bool enabled;
  final ValueChanged<StorageKind> onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: .stretch,
      spacing: Spacing.sm,
      children: [
        Text(l10n.sectionClear),
        DemoButton(
          key: DemoKeys.clearSecure,
          label: l10n.clearSecureStorage,
          enabled: enabled,
          onPressed: () => onClear(.secure),
        ),
        DemoButton(
          key: DemoKeys.clearNormal,
          label: l10n.clearNormalStorage,
          enabled: enabled,
          onPressed: () => onClear(.normal),
        ),
      ],
    );
  }
}
