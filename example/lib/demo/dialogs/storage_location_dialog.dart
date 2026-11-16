import 'package:example/demo/demo_keys.dart';
import 'package:example/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class StorageLocationDialog extends StatelessWidget {
  const StorageLocationDialog({required this.message, required this.path, super.key});

  final String message;
  final String path;

  static Future<void> show(BuildContext context, {required String message, required String path}) =>
      showDialog<void>(
        context: context,
        routeSettings: const RouteSettings(name: 'StorageLocationDialog'),
        builder: (context) => StorageLocationDialog(message: message, path: path),
      );

  Future<void> _copyPath(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: path));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.pathCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.storageLocationTitle),
      content: SingleChildScrollView(child: SelectableText(message)),
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
