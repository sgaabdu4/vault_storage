import 'package:material_ui/material_ui.dart';

class AppDropdownField extends StatelessWidget {
  const AppDropdownField({
    required this.labelText,
    required this.items,
    required this.onChanged,
    this.initialValue,
    super.key,
  });

  final String labelText;
  final String? initialValue;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    decoration: InputDecoration(labelText: labelText),
    initialValue: initialValue,
    items: items,
    onChanged: onChanged,
  );
}
