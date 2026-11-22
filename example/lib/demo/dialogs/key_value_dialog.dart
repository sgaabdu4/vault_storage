import 'package:example/core/widgets/app_text_field.dart';
import 'package:example/demo/demo_keys.dart';
import 'package:example/demo/dialogs/confirm_dialog.dart';
import 'package:example/design/spacing.dart';
import 'package:example/l10n/app_localizations.g.dart';
import 'package:material_ui/material_ui.dart';

typedef KeyValueEntry = ({String key, String value});

class KeyValueDialog extends StatefulWidget {
  const KeyValueDialog({required this.title, super.key});

  final String title;

  static Future<KeyValueEntry?> show(BuildContext context, {required String title}) =>
      showDialog<KeyValueEntry>(
        context: context,
        routeSettings: const RouteSettings(name: 'KeyValueDialog'),
        builder: (context) => KeyValueDialog(title: title),
      );

  @override
  State<KeyValueDialog> createState() => _KeyValueDialogState();
}

class _KeyValueDialogState extends State<KeyValueDialog> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConfirmDialog<KeyValueEntry>(
      title: widget.title,
      content: Column(
        mainAxisSize: .min,
        spacing: Spacing.lg,
        children: [
          AppTextField(
            key: DemoKeys.keyField,
            controller: _keyController,
            labelText: l10n.fieldKey,
          ),
          AppTextField(
            key: DemoKeys.valueField,
            controller: _valueController,
            labelText: l10n.fieldValue,
          ),
        ],
      ),
      result: () => (key: _keyController.text, value: _valueController.text),
    );
  }
}
