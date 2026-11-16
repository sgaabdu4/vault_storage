import 'package:example/demo/demo_button.dart';
import 'package:example/demo/demo_keys.dart';
import 'package:example/demo/storage_kind.dart';
import 'package:example/design/spacing.dart';
import 'package:example/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class FileSection extends StatelessWidget {
  const FileSection({required this.enabled, required this.onSave, required this.onGet, super.key});

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
        Text(l10n.sectionFile),
        DemoButton(
          key: DemoKeys.saveSecureFile,
          label: l10n.saveSecureFile,
          enabled: enabled,
          onPressed: () => onSave(.secure),
        ),
        DemoButton(
          key: DemoKeys.saveNormalFile,
          label: l10n.saveNormalFile,
          enabled: enabled,
          onPressed: () => onSave(.normal),
        ),
        DemoButton(
          key: DemoKeys.getFile,
          label: l10n.getFile,
          enabled: enabled,
          onPressed: () => onGet(null),
        ),
        DemoButton(
          key: DemoKeys.getSecureFile,
          label: l10n.getSecureFile,
          enabled: enabled,
          onPressed: () => onGet(true),
        ),
        DemoButton(
          key: DemoKeys.getNormalFile,
          label: l10n.getNormalFile,
          enabled: enabled,
          onPressed: () => onGet(false),
        ),
      ],
    );
  }
}
