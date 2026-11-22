import 'package:example/core/widgets/app_text_field.dart';
import 'package:example/demo/demo_keys.dart';
import 'package:example/demo/dialogs/confirm_dialog.dart';
import 'package:material_ui/material_ui.dart';

class KeyInputDialog extends StatefulWidget {
  const KeyInputDialog({required this.title, required this.label, super.key});

  final String title;
  final String label;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String label,
  }) => showDialog<String>(
    context: context,
    routeSettings: const RouteSettings(name: 'KeyInputDialog'),
    builder: (context) => KeyInputDialog(title: title, label: label),
  );

  @override
  State<KeyInputDialog> createState() => _KeyInputDialogState();
}

class _KeyInputDialogState extends State<KeyInputDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConfirmDialog<String>(
    title: widget.title,
    content: AppTextField(
      key: DemoKeys.textInputField,
      controller: _controller,
      labelText: widget.label,
    ),
    result: () => _controller.text,
  );
}
