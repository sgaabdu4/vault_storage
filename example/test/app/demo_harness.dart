import 'dart:io';

import 'package:example/app/my_app.dart';
import 'package:example/demo/demo_button.dart';
import 'package:example/demo/demo_keys.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' show FlutterSecureStorage;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:material_ui/material_ui.dart';

import 'demo_picked_file.dart';
import 'demo_picker.dart';

const Duration _settleTime = Duration(milliseconds: 600);
const Duration _pollInterval = Duration(milliseconds: 10);
const int _pollAttempts = 100;
const double _scrollStep = 200;
const Offset _scrollToTop = Offset(0, 2000);

final class DemoHarness {
  DemoHarness._(this.directory, this._originalPicker, this.picker);

  static const MethodChannel _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

  final Directory directory;
  final DemoPicker picker;
  final FilePickerPlatform _originalPicker;

  static Future<DemoHarness> create() async {
    debugDefaultTargetPlatformOverride = .linux;
    final Directory directory = await Directory.systemTemp.createTemp('vault-demo-test-');
    FlutterSecureStorage.setMockInitialValues({});
    final harness = DemoHarness._(directory, .instance, DemoPicker());
    FilePickerPlatform.instance = harness.picker;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProvider,
      (_) async => directory.path,
    );
    return harness;
  }

  void restore() {
    debugDefaultTargetPlatformOverride = null;
    FilePickerPlatform.instance = _originalPicker;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProvider,
      null,
    );
  }

  Future<void> start(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const MyApp());
      await _awaitReady(tester);
    });
  }

  Future<void> startMain(WidgetTester tester, VoidCallback entry) async {
    await tester.runAsync(() async {
      entry();
      await tester.pump();
      await _awaitReady(tester);
    });
  }

  Future<void> _awaitReady(WidgetTester tester) async {
    for (int attempt = 0; attempt < _pollAttempts; attempt++) {
      await Future<void>.delayed(_pollInterval);
      await tester.pump();
      if (tester.widget<DemoButton>(find.byKey(DemoKeys.saveNormal)).enabled) return;
    }
    fail('Storage did not initialize');
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(_settleTime);
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.runAsync(() async {
      await tester.tap(find.byKey(key));
      await settle(tester);
    });
  }

  Future<void> tapButton(WidgetTester tester, Key key) async {
    final Finder button = find.byKey(key);
    await tester.runAsync(() async {
      await tester.drag(find.byKey(DemoKeys.demoList), _scrollToTop);
      await settle(tester);
      await tester.scrollUntilVisible(button, _scrollStep);
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await settle(tester);
    });
  }

  Future<void> waitForText(WidgetTester tester, String text) async {
    await tester.runAsync(() async {
      for (int attempt = 0; attempt < _pollAttempts; attempt++) {
        await Future<void>.delayed(_pollInterval);
        await tester.pump();
        if (find.text(text).evaluate().isNotEmpty) return;
      }
      fail('Operation did not produce $text');
    });
  }

  Future<void> submit(WidgetTester tester, String result) async {
    await tapKey(tester, DemoKeys.dialogOk);
    await waitForText(tester, result);
  }

  Future<void> pickFile(WidgetTester tester, String name, String content) async {
    await tester.runAsync(() async {
      final File file = File('${directory.path}/$name');
      await file.writeAsString(content);
      picker.files = [DemoPickedFile(file)];
    });
  }

  Future<void> close(WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = null;
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await Hive.close();
      await directory.delete(recursive: true);
    });
  }
}
