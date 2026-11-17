import 'package:example/design/spacing.dart';
import 'package:example/design/status_colors.dart';
import 'package:material_ui/material_ui.dart';

class OperationMessage extends StatelessWidget {
  const OperationMessage({required this.result, required this.error, super.key});

  final String? result;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final String? message = error ?? result;
    final StatusColors? colors = Theme.of(context).extension<StatusColors>();
    if (message == null || colors == null) return const SizedBox.shrink();
    return Padding(
      padding: const .all(Spacing.md),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: error != null ? colors.failure : colors.success),
      ),
    );
  }
}
