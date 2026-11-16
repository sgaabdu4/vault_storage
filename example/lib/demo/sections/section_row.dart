import 'package:material_ui/material_ui.dart';

class SectionRow {
  const SectionRow({required this.key, required this.label, required this.onPressed});

  final Key key;
  final String label;
  final VoidCallback onPressed;
}
