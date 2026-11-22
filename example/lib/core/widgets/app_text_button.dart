import 'package:material_ui/material_ui.dart';

class AppTextButton extends StatelessWidget {
  const AppTextButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(onPressed: onPressed, child: Text(label));
}
