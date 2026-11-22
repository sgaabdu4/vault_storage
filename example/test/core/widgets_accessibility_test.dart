import 'package:example/core/widgets/app_dialog.dart';
import 'package:example/core/widgets/app_dropdown_field.dart';
import 'package:example/core/widgets/app_elevated_button.dart';
import 'package:example/core/widgets/app_text_button.dart';
import 'package:example/core/widgets/app_text_field.dart';
import 'package:example/demo/demo_button.dart';
import 'package:example/demo/dialogs/confirm_dialog.dart';
import 'package:example/demo/dialogs/key_dropdown_dialog.dart';
import 'package:example/demo/dialogs/key_input_dialog.dart';
import 'package:example/demo/dialogs/key_value_dialog.dart';
import 'package:example/demo/dialogs/security_alert_dialog.dart';
import 'package:example/demo/dialogs/storage_location_dialog.dart';
import 'package:example/design/app_theme.dart';
import 'package:example/l10n/app_localizations.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(Widget child, {TargetPlatform? platform}) => MaterialApp(
  theme: platform == null ? buildAppTheme() : buildAppTheme().copyWith(platform: platform),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

Future<void> _expectGuidelines(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  try {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  } finally {
    handle.dispose();
  }
}

void main() {
  testWidgets('shared controls meet contrast and tap-target guidelines', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        SingleChildScrollView(
          child: Column(
            mainAxisSize: .min,
            children: [
              AppElevatedButton(label: 'Save', onPressed: () {}),
              AppTextButton(label: 'Cancel', onPressed: () {}),
              DemoButton(label: 'Run demo', enabled: true, onPressed: () {}),
              AppTextField(controller: controller, labelText: 'Key'),
              AppDropdownField(
                labelText: 'Stored key',
                items: const [DropdownMenuItem(value: 'alpha', child: Text('alpha'))],
                onChanged: (_) {},
              ),
              AppDialog(
                title: 'Confirm',
                content: const Text('Proceed'),
                actions: [AppTextButton(label: 'OK', onPressed: () {})],
              ),
            ],
          ),
        ),
      ),
    );
    await _expectGuidelines(tester);
  });

  testWidgets('demo dialogs meet contrast and tap-target guidelines', (tester) async {
    final dialogs = <Widget>[
      ConfirmDialog<String>(title: 'Confirm', content: const Text('Details'), result: () => 'ok'),
      const KeyDropdownDialog(title: 'Pick key', label: 'Key', keys: ['alpha']),
      const KeyInputDialog(title: 'Enter key', label: 'Key'),
      const KeyValueDialog(title: 'Save pair'),
      const SecurityAlertDialog(threats: ['Root detected']),
      const StorageLocationDialog(
        directoryPath: '/tmp/vault',
        keyFilePath: '/tmp/vault/key',
        keyFileExists: true,
      ),
    ];
    for (final dialog in dialogs) {
      await tester.pumpWidget(_app(dialog));
      await _expectGuidelines(tester);
    }
  });

  testWidgets('adaptive security alert meets iOS guidelines through its route', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => AppElevatedButton(
            label: 'Show alert',
            onPressed: () => SecurityAlertDialog.show(context, threats: const ['Root detected']),
          ),
        ),
        platform: .iOS,
      ),
    );
    await tester.tap(find.byType(AppElevatedButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _expectGuidelines(tester);
  });
}
