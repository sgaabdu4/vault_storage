import 'package:example/design/spacing.dart';
import 'package:example/l10n/app_localizations.g.dart';
import 'package:material_ui/material_ui.dart';

class StorageInitialization extends StatelessWidget {
  const StorageInitialization({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .all(Spacing.md),
    child: Row(
      spacing: Spacing.sm,
      children: [
        const SizedBox.square(
          dimension: Sizes.spinner,
          child: CircularProgressIndicator(strokeWidth: Sizes.spinnerStroke),
        ),
        Text(AppLocalizations.of(context).initializingStorage),
      ],
    ),
  );
}
