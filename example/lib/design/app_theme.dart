import 'package:example/design/status_colors.dart';
import 'package:material_ui/material_ui.dart';

ThemeData buildAppTheme() => ThemeData(
  primarySwatch: Colors.blue,
  useMaterial3: true,
  extensions: const [StatusColors(success: Colors.green, failure: Colors.red)],
);
