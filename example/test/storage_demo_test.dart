import 'dart:io';

import 'package:example/main.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' show FlutterSecureStorage;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late FilePickerPlatform originalPicker;
  late DemoPicker picker;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    directory = await Directory.systemTemp.createTemp('vault-demo-test-');
    FlutterSecureStorage.setMockInitialValues({});
    originalPicker = FilePickerPlatform.instance;
    picker = DemoPicker();
    FilePickerPlatform.instance = picker;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => directory.path,
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    FilePickerPlatform.instance = originalPicker;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    for (var attempt = 0; attempt < 100; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save Normal'),
      );
      if (button.onPressed != null) return;
    }
    fail('Storage did not initialize');
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.widgetWithText(ElevatedButton, label);
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(button, 200);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, String result) async {
    await tester.tap(find.widgetWithText(TextButton, 'OK'));
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 100; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
      if (find.text(result).evaluate().isNotEmpty) return;
    }
    fail('Operation did not produce $result');
  }

  Future<void> runDemo(WidgetTester tester, Future<void> Function() journey) async {
    await tester.runAsync(() async {
      try {
        await start(tester);
        await journey();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await Hive.close();
        await directory.delete(recursive: true);
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('storage location displays the directory and copies its path', (tester) async {
    String? copiedPath;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedPath = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await runDemo(tester, () async {
      await tapButton(tester, '🔍 Show Storage Location');
      expect(find.text('Storage Location'), findsOneWidget);
      expect(find.textContaining(directory.path), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Copy Path'));
      await tester.pumpAndSettle();
      expect(copiedPath, directory.path);
      expect(find.text('Path copied to clipboard!'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();
      expect(find.text('Storage Location'), findsNothing);
    });
  });

  for (final kind in ['Normal', 'Secure']) {
    testWidgets('$kind files round-trip through the picker and public storage API', (tester) async {
      await runDemo(tester, () async {
        final file = File('${directory.path}/sample.txt');
        await file.writeAsString('sample file content');
        picker.files = [DemoPickedFile(file)];
        await tapButton(tester, 'Save $kind File');
        await tester.enterText(find.widgetWithText(TextField, 'File Key'), 'sample-file');
        await submit(tester, '$kind file "sample.txt" saved with key "sample-file"!');
        await tapButton(tester, 'Get $kind File');
        await tester.enterText(find.widgetWithText(TextField, 'File Key'), 'sample-file');
        await submit(tester, 'File content: sample file content');
        expect(find.text('File content: sample file content'), findsOneWidget);
      });
    });

    testWidgets('$kind storage can be cleared and picker cancellation stays safe', (tester) async {
      await runDemo(tester, () async {
        await tapButton(tester, 'Save $kind File');
        expect(find.text('No file selected'), findsOneWidget);
        await tapButton(tester, 'Save $kind');
        await tester.enterText(find.widgetWithText(TextField, 'Key'), 'to-clear');
        await tester.enterText(find.widgetWithText(TextField, 'Value'), 'sample');
        await submit(tester, '$kind value saved successfully!');
        await tapButton(tester, 'Clear $kind Storage');
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
          if (find.text('$kind storage cleared successfully!').evaluate().isNotEmpty) break;
        }
        expect(find.text('$kind storage cleared successfully!'), findsOneWidget);
        await tapButton(tester, 'Get (Auto-detect)');
        await tester.enterText(find.widgetWithText(TextField, 'Key'), 'to-clear');
        await submit(tester, 'Key not found');
        expect(find.text('Key not found'), findsOneWidget);
      });
    });

    testWidgets('$kind values can be saved, retrieved and deleted', (tester) async {
      await runDemo(tester, () async {
        await tapButton(tester, 'Save $kind');
        await tester.enterText(find.widgetWithText(TextField, 'Key'), 'sample-key');
        await tester.enterText(find.widgetWithText(TextField, 'Value'), 'sample-value');
        await submit(tester, '$kind value saved successfully!');
        expect(find.text('$kind value saved successfully!'), findsOneWidget);

        await tapButton(tester, 'Get $kind');
        await tester.enterText(find.widgetWithText(TextField, 'Key'), 'sample-key');
        await submit(tester, 'Value: sample-value');
        expect(find.text('Value: sample-value'), findsOneWidget);

        await tapButton(tester, 'Delete Value');
        await tester.enterText(find.widgetWithText(TextField, 'Key'), 'sample-key');
        await submit(tester, 'Value deleted successfully!');
        expect(find.text('Value deleted successfully!'), findsOneWidget);

        await tapButton(tester, 'Get (Auto-detect)');
        await tester.enterText(find.widgetWithText(TextField, 'Key'), 'sample-key');
        await submit(tester, 'Key not found');
        expect(find.text('Key not found'), findsOneWidget);
      });
    });
  }
}

class DemoPicker extends FilePickerPlatform {
  List<PlatformFile> files = [];

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => files;
}

final class DemoPickedFile extends PlatformFile {
  DemoPickedFile(this.file);
  final File file;

  @override
  String get name => file.uri.pathSegments.last;

  @override
  Uri get uri => file.uri;

  @override
  Future<Uint8List> readAsBytes() => file.readAsBytes();

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
