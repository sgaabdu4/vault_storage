import 'package:example/core/widgets/app_dropdown_field.dart';
import 'package:example/demo/demo_keys.dart';
import 'package:example/demo/storage_kind.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'demo_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DemoHarness demo;

  setUp(() async {
    demo = await DemoHarness.create();
  });

  tearDown(() => demo.restore());

  testWidgets('storage location displays the directory and copies its path', (tester) async {
    String? copiedPath;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call case MethodCall(
        method: 'Clipboard.setData',
        arguments: {'text': final String text},
      )) {
        copiedPath = text;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    addTearDown(() => demo.close(tester));
    await demo.start(tester);
    await demo.tapButton(tester, DemoKeys.showStorageLocation);
    expect(find.text('Storage Location'), findsOneWidget);
    expect(find.text(demo.directory.path), findsOneWidget);
    expect(find.textContaining(demo.directory.path), findsNWidgets(2));
    await demo.tapKey(tester, DemoKeys.copyPath);
    expect(copiedPath, demo.directory.path);
    expect(find.text('Path copied to clipboard!'), findsOneWidget);
    await demo.tapKey(tester, DemoKeys.closeDialog);
    expect(find.text('Storage Location'), findsNothing);
  });

  for (final label in ['Normal', 'Secure']) {
    final kind = StorageKind.values.byName(label.toLowerCase());

    testWidgets('$label files round-trip through the picker and public storage API', (
      tester,
    ) async {
      addTearDown(() => demo.close(tester));
      await demo.start(tester);
      await demo.pickFile(tester, 'sample.txt', 'sample file content');
      await demo.tapButton(tester, DemoKeys.saveFile(kind));
      await tester.enterText(find.byKey(DemoKeys.textInputField), 'sample-file');
      await demo.submit(tester, '$label file "sample.txt" saved with key "sample-file"!');
      await demo.tapButton(tester, DemoKeys.getStoredFile(kind));
      await tester.enterText(find.byKey(DemoKeys.textInputField), 'sample-file');
      await demo.submit(tester, 'File content: sample file content');
      expect(find.text('File content: sample file content'), findsOneWidget);
    });

    testWidgets('$label storage can be cleared and picker cancellation stays safe', (tester) async {
      addTearDown(() => demo.close(tester));
      await demo.start(tester);
      await demo.tapButton(tester, DemoKeys.saveFile(kind));
      expect(find.text('No file selected'), findsOneWidget);
      await demo.tapButton(tester, DemoKeys.saveValue(kind));
      await tester.enterText(find.byKey(DemoKeys.keyField), 'to-clear');
      await tester.enterText(find.byKey(DemoKeys.valueField), 'sample');
      await demo.submit(tester, '$label value saved successfully!');
      await demo.tapButton(tester, DemoKeys.clearStorage(kind));
      await demo.waitForText(tester, '$label storage cleared successfully!');
      expect(find.text('$label storage cleared successfully!'), findsOneWidget);
      await demo.tapButton(tester, DemoKeys.getAuto);
      await tester.enterText(find.byKey(DemoKeys.textInputField), 'to-clear');
      await demo.submit(tester, 'Key not found');
      expect(find.text('Key not found'), findsOneWidget);
    });

    testWidgets('$label values can be saved, retrieved and deleted', (tester) async {
      addTearDown(() => demo.close(tester));
      await demo.start(tester);
      await demo.tapButton(tester, DemoKeys.saveValue(kind));
      await tester.enterText(find.byKey(DemoKeys.keyField), 'sample-key');
      await tester.enterText(find.byKey(DemoKeys.valueField), 'sample-value');
      await demo.submit(tester, '$label value saved successfully!');
      expect(find.text('$label value saved successfully!'), findsOneWidget);

      await demo.tapButton(tester, DemoKeys.getValue(kind));
      await tester.enterText(find.byKey(DemoKeys.textInputField), 'sample-key');
      await demo.submit(tester, 'Value: sample-value');
      expect(find.text('Value: sample-value'), findsOneWidget);

      await demo.tapButton(tester, DemoKeys.deleteValue);
      await tester.enterText(find.byKey(DemoKeys.textInputField), 'sample-key');
      await demo.submit(tester, 'Value deleted successfully!');
      expect(find.text('Value deleted successfully!'), findsOneWidget);

      await demo.tapButton(tester, DemoKeys.getAuto);
      await tester.enterText(find.byKey(DemoKeys.textInputField), 'sample-key');
      await demo.submit(tester, 'Key not found');
      expect(find.text('Key not found'), findsOneWidget);
    });
  }

  testWidgets('selecting a stored key from the dropdown retrieves its value', (tester) async {
    addTearDown(() => demo.close(tester));
    await demo.start(tester);
    await demo.tapButton(tester, DemoKeys.saveValue(.normal));
    await tester.enterText(find.byKey(DemoKeys.keyField), 'dropdown-key');
    await tester.enterText(find.byKey(DemoKeys.valueField), 'dropdown-value');
    await demo.submit(tester, 'Normal value saved successfully!');

    await demo.tapButton(tester, DemoKeys.getValue(.normal));
    await tester.tap(find.byType(AppDropdownField));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final menuItem = find.byWidgetPredicate(
      (w) => w is DropdownMenuItem<String> && w.value == 'dropdown-key',
    );
    await tester.tap(find.ancestor(of: menuItem.last, matching: find.byType(InkWell)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await demo.submit(tester, 'Value: dropdown-value');
    expect(find.text('Value: dropdown-value'), findsOneWidget);
  });
}
