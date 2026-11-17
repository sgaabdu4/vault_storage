import 'package:example/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';

import 'app/demo_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DemoHarness demo;

  setUp(() async {
    demo = await DemoHarness.create();
  });

  tearDown(() => demo.restore());

  testWidgets('main starts the demo app with its storage ready', (tester) async {
    addTearDown(() => demo.close(tester));
    await demo.startMain(tester, app.main);
    expect(find.text('Vault Storage Demo'), findsOneWidget);
  });
}
