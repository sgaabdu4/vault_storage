import 'package:example/demo/demo_keys.dart';
import 'package:example/demo/sections/section_kind.dart';
import 'package:example/demo/sections/section_row.dart';
import 'package:example/demo/storage_kind.dart';
import 'package:example/l10n/app_localizations.g.dart';
import 'package:material_ui/material_ui.dart';

class SectionContent {
  const SectionContent({required this.title, required this.rows});

  static SectionContent forKind(
    SectionKind kind,
    AppLocalizations l10n, {
    required ValueChanged<StorageKind> onSave,
    required ValueChanged<bool?> onGet,
  }) => switch (kind) {
    .value => SectionContent(
      title: l10n.sectionKeyValue,
      rows: [
        SectionRow(
          key: DemoKeys.saveSecure,
          label: l10n.saveSecure,
          onPressed: () => onSave(.secure),
        ),
        SectionRow(
          key: DemoKeys.saveNormal,
          label: l10n.saveNormal,
          onPressed: () => onSave(.normal),
        ),
        SectionRow(key: DemoKeys.getAuto, label: l10n.getAuto, onPressed: () => onGet(null)),
        SectionRow(key: DemoKeys.getSecure, label: l10n.getSecure, onPressed: () => onGet(true)),
        SectionRow(key: DemoKeys.getNormal, label: l10n.getNormal, onPressed: () => onGet(false)),
      ],
    ),
    .file => SectionContent(
      title: l10n.sectionFile,
      rows: [
        SectionRow(
          key: DemoKeys.saveSecureFile,
          label: l10n.saveSecureFile,
          onPressed: () => onSave(.secure),
        ),
        SectionRow(
          key: DemoKeys.saveNormalFile,
          label: l10n.saveNormalFile,
          onPressed: () => onSave(.normal),
        ),
        SectionRow(key: DemoKeys.getFile, label: l10n.getFile, onPressed: () => onGet(null)),
        SectionRow(
          key: DemoKeys.getSecureFile,
          label: l10n.getSecureFile,
          onPressed: () => onGet(true),
        ),
        SectionRow(
          key: DemoKeys.getNormalFile,
          label: l10n.getNormalFile,
          onPressed: () => onGet(false),
        ),
      ],
    ),
  };

  final String title;
  final List<SectionRow> rows;
}
