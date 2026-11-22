import 'package:material_ui/material_ui.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({required this.title, required this.content, required this.actions, super.key})
    : _adaptive = false;

  const AppDialog.adaptive({
    required this.title,
    required this.content,
    required this.actions,
    super.key,
  }) : _adaptive = true;

  final String title;
  final Widget content;
  final List<Widget> actions;
  final bool _adaptive;

  @override
  Widget build(BuildContext context) => _adaptive
      ? AlertDialog.adaptive(title: Text(title), content: content, actions: actions)
      : AlertDialog(title: Text(title), content: content, actions: actions);
}
