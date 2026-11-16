import 'package:example/demo/demo_button.dart';
import 'package:example/demo/demo_keys.dart';
import 'package:example/demo/storage_kind.dart';
import 'package:example/design/spacing.dart';
import 'package:example/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class ValueSection extends StatelessWidget {
  const ValueSection({required this.enabled, required this.onSave, required this.onGet, super.key});

  final bool enabled;
  final ValueChanged<StorageKind> onSave;
  final ValueChanged<bool?> onGet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: .stretch,
      spacing: Spacing.sm,
      children: [
        Text(l10n.sectionKeyValue),
        DemoButton(
          key: DemoKeys.saveSecure,
          label: l10n.saveSecure,
          enabled: enabled,
          onPressed: () => onSave(.secure),
        ),
        DemoButton(
          key: DemoKeys.saveNormal,
          label: l10n.saveNormal,
          enabled: enabled,
          onPressed: () => onSave(.normal),
        ),
        DemoButton(
          key: DemoKeys.getAuto,
          label: l10n.getAuto,
          enabled: enabled,
          onPressed: () => onGet(null),
        ),
        DemoButton(
          key: DemoKeys.getSecure,
          label: l10n.getSecure,
          enabled: enabled,
          onPressed: () => onGet(true),
        ),
        DemoButton(
          key: DemoKeys.getNormal,
          label: l10n.getNormal,
          enabled: enabled,
          onPressed: () => onGet(false),
        ),
      ],
    );
  }
}
