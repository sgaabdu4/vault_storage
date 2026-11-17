import 'package:example/demo/demo_button.dart';
import 'package:example/demo/sections/section_content.dart';
import 'package:example/demo/sections/section_kind.dart';
import 'package:example/demo/sections/section_row.dart';
import 'package:example/demo/storage_kind.dart';
import 'package:example/design/spacing.dart';
import 'package:material_ui/material_ui.dart';

class StorageSection extends StatelessWidget {
  const StorageSection({
    required this.kind,
    required this.enabled,
    required this.onSave,
    required this.onGet,
    super.key,
  });

  final SectionKind kind;
  final bool enabled;
  final ValueChanged<StorageKind> onSave;
  final ValueChanged<bool?> onGet;

  @override
  Widget build(BuildContext context) {
    final SectionContent(:title, :rows) = .forKind(
      kind,
      .of(context),
      onSave: onSave,
      onGet: onGet,
    );
    return Column(
      crossAxisAlignment: .stretch,
      spacing: Spacing.sm,
      children: [
        Text(title),
        for (final SectionRow(:key, :label, :onPressed) in rows)
          DemoButton(key: key, label: label, enabled: enabled, onPressed: onPressed),
      ],
    );
  }
}
