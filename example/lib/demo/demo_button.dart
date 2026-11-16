import 'package:example/design/spacing.dart';
import 'package:material_ui/material_ui.dart';

class DemoButton extends StatelessWidget {
  const DemoButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .symmetric(vertical: Spacing.xs),
    child: ElevatedButton(onPressed: enabled ? onPressed : null, child: Text(label)),
  );
}
