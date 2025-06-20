import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vault_storage/vault_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // In a real app, you would use a ProviderScope and override the vaultStorageProvider
  // to initialize it. For this example, we'll initialize it directly.
  final container = ProviderContainer();
  await container.read(vaultStorageProvider.future);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vault Storage Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key});

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  final _keyController = TextEditingController(text: 'my_secret_key');
  final _valueController = TextEditingController(text: 'my secret value');
  String? _retrievedValue;
  String? _errorMessage;

  Future<void> _saveValue() async {
    setState(() {
      _errorMessage = null;
      _retrievedValue = null;
    });
    final vaultStorage = await ref.read(vaultStorageProvider.future);
    final result = await vaultStorage.set(
      BoxType.secure,
      _keyController.text,
      _valueController.text,
    );
    result.fold(
      (error) => setState(() => _errorMessage = error.message),
      (_) => setState(() {}),
    );
  }

  Future<void> _getValue() async {
    setState(() {
      _errorMessage = null;
      _retrievedValue = null;
    });
    final vaultStorage = await ref.read(vaultStorageProvider.future);
    final result = await vaultStorage.get<String>(
      BoxType.secure,
      _keyController.text,
    );
    result.fold(
      (error) => setState(() => _errorMessage = error.message),
      (value) => setState(() => _retrievedValue = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault Storage Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(labelText: 'Key'),
            ),
            TextField(
              controller: _valueController,
              decoration: const InputDecoration(labelText: 'Value'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _saveValue,
                  child: const Text('Save to Secure Storage'),
                ),
                ElevatedButton(
                  onPressed: _getValue,
                  child: const Text('Get from Secure Storage'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_retrievedValue != null)
              Text('Retrieved Value: $_retrievedValue'),
            if (_errorMessage != null)
              Text('Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
