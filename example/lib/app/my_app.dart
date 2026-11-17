import 'package:example/demo/vault_storage_demo.dart';
import 'package:example/design/app_theme.dart';
import 'package:example/l10n/app_localizations.g.dart';
import 'package:material_ui/material_ui.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(),
      home: const VaultStorageDemo(),
    );
  }
}
