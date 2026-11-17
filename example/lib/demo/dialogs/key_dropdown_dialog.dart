import 'package:example/demo/demo_keys.dart';
import 'package:example/demo/dialogs/confirm_dialog.dart';
import 'package:example/design/spacing.dart';
import 'package:example/l10n/app_localizations.g.dart';
import 'package:material_ui/material_ui.dart';

class KeyDropdownDialog extends StatefulWidget {
  const KeyDropdownDialog({
    required this.title,
    required this.label,
    required this.keys,
    super.key,
  });

  final String title;
  final String label;
  final List<String> keys;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String label,
    required List<String> keys,
  }) => showDialog<String>(
    context: context,
    routeSettings: const RouteSettings(name: 'KeyDropdownDialog'),
    builder: (context) => KeyDropdownDialog(title: title, label: label, keys: keys),
  );

  @override
  State<KeyDropdownDialog> createState() => _KeyDropdownDialogState();
}

class _KeyDropdownDialogState extends State<KeyDropdownDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _selectedKey;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(String? value) {
    if (value == null) return;
    setState(() {
      _selectedKey = value;
      _controller.text = value;
    });
  }

  void _clearSelection(String value) {
    setState(() => _selectedKey = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bool hasKeys = widget.keys.isNotEmpty;
    return ConfirmDialog<String>(
      title: widget.title,
      content: Column(
        mainAxisSize: .min,
        spacing: Spacing.lg,
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: hasKeys ? l10n.selectFromKeys : l10n.noKeysAvailable,
            ),
            initialValue: _selectedKey,
            items: [
              if (hasKeys)
                for (final String key in widget.keys) DropdownMenuItem(value: key, child: Text(key))
              else
                DropdownMenuItem(child: Text(l10n.noKeysStored)),
            ],
            onChanged: hasKeys ? _select : null,
          ),
          Text(l10n.orSeparator, style: Theme.of(context).textTheme.titleSmall),
          TextField(
            key: DemoKeys.textInputField,
            controller: _controller,
            decoration: InputDecoration(labelText: widget.label),
            onChanged: _clearSelection,
          ),
        ],
      ),
      result: () => _controller.text,
    );
  }
}
