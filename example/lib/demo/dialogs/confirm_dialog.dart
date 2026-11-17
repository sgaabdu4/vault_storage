import 'package:example/demo/demo_keys.dart';
import 'package:example/l10n/app_localizations.g.dart';
import 'package:material_ui/material_ui.dart';

class ConfirmDialog<T> extends StatelessWidget {
  const ConfirmDialog({
    required this.title,
    required this.content,
    required this.result,
    super.key,
  });

  final String title;
  final Widget content;
  final ValueGetter<T> result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(title),
      content: content,
      actions: [
        TextButton(
          key: DemoKeys.dialogCancel,
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: DemoKeys.dialogOk,
          onPressed: () => Navigator.pop(context, result()),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
