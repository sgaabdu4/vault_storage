import 'package:material_ui/material_ui.dart';

class AppElevatedButton extends StatelessWidget {
  const AppElevatedButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton(onPressed: onPressed, child: Text(label));
}
