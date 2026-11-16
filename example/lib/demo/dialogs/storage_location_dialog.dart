import 'package:example/demo/demo_keys.dart';
import 'package:example/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class StorageLocationDialog extends StatelessWidget {
  const StorageLocationDialog({
    required this.directoryPath,
    required this.keyFilePath,
    required this.keyFileExists,
    super.key,
  });

  final String directoryPath;
  final String keyFilePath;
  final bool keyFileExists;

  static Future<void> show(
    BuildContext context, {
    required String directoryPath,
    required String keyFilePath,
    required bool keyFileExists,
  }) => showDialog<void>(
    context: context,
    routeSettings: const RouteSettings(name: 'StorageLocationDialog'),
    builder: (context) => StorageLocationDialog(
      directoryPath: directoryPath,
      keyFilePath: keyFilePath,
      keyFileExists: keyFileExists,
    ),
  );

  Future<void> _copyPath(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: directoryPath));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.pathCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final List<Widget> lines = [
      Text(l10n.storageSupportDirectoryLabel),
      SelectableText(directoryPath),
      Text(l10n.storageKeyFileLabel),
      SelectableText(keyFilePath),
      Text(keyFileExists ? l10n.storageKeyFileFound : l10n.storageKeyFileMissing),
      if (keyFileExists) ...[
        Text(l10n.storageViewHeading),
        Text(l10n.storageViewStepRun),
        Text(l10n.storageViewStepPaste),
        Text(l10n.storageViewStepLook),
        Text(l10n.storageKeyFileEncrypted),
        Text(l10n.storageKeyFileKeyName),
      ] else ...[
        Text(l10n.storageKeyFileCreatedLater),
        Text(l10n.storageKeyFileSaveFirst),
      ],
    ];
    return AlertDialog(
      title: Text(l10n.storageLocationTitle),
      content: SingleChildScrollView(child: ListBody(children: lines)),
      actions: [
        TextButton(
          key: DemoKeys.copyPath,
          onPressed: () => _copyPath(context),
          child: Text(l10n.copyPath),
        ),
        TextButton(
          key: DemoKeys.closeDialog,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
