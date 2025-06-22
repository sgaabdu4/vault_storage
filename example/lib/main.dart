import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vault_storage/vault_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the vault storage provider
  final container = ProviderContainer();

  try {
    await container.read(vaultStorageProvider.future);

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    print('Failed to initialize storage: $e');
    print('Stack trace: $stackTrace');

    // Show error app instead of crashing
    runApp(
      MaterialApp(
        title: 'Vault Storage Demo - Error',
        home: Scaffold(
          appBar: AppBar(title: const Text('Storage Initialization Error')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Failed to initialize vault storage:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    e.toString(),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This might be due to missing platform permissions or entitlements. '
                  'Please check the documentation for platform-specific setup requirements.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vault Storage Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
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
  String? _operationResult;
  Map<String, dynamic>? _fileMetadata;

  void _clearMessages() {
    setState(() {
      _errorMessage = null;
      _retrievedValue = null;
      _operationResult = null;
    });
  }

  // Key-Value Storage Operations
  Future<void> _saveSecureValue() async {
    _clearMessages();
    final vaultStorage = await ref.read(vaultStorageProvider.future);
    final result = await vaultStorage.set(
      BoxType.secure,
      _keyController.text,
      _valueController.text,
    );

    setState(() {
      result.fold(
        (error) => _errorMessage = 'Save Error: ${error.message}',
        (_) => _operationResult = 'Secure value saved successfully!',
      );
    });
  }

  Future<void> _saveNormalValue() async {
    _clearMessages();
    final vaultStorage = await ref.read(vaultStorageProvider.future);
    final result = await vaultStorage.set(
      BoxType.normal,
      _keyController.text,
      _valueController.text,
    );

    setState(() {
      result.fold(
        (error) => _errorMessage = 'Save Error: ${error.message}',
        (_) => _operationResult = 'Normal value saved successfully!',
      );
    });
  }

  Future<void> _getSecureValue() async {
    _clearMessages();
    final vaultStorage = await ref.read(vaultStorageProvider.future);
    final result = await vaultStorage.get<String>(
      BoxType.secure,
      _keyController.text,
    );

    setState(() {
      result.fold(
        (error) => _errorMessage = 'Get Error: ${error.message}',
        (value) => _retrievedValue = 'Secure: ${value ?? 'Key not found'}',
      );
    });
  }

  Future<void> _getNormalValue() async {
    _clearMessages();
    final vaultStorage = await ref.read(vaultStorageProvider.future);
    final result = await vaultStorage.get<String>(
      BoxType.normal,
      _keyController.text,
    );

    setState(() {
      result.fold(
        (error) => _errorMessage = 'Get Error: ${error.message}',
        (value) => _retrievedValue = 'Normal: ${value ?? 'Key not found'}',
      );
    });
  }

  // File Storage Operations
  Future<void> _saveSecureFile() async {
    _clearMessages();
    final vaultStorage = await ref.read(vaultStorageProvider.future);

    // Create sample file data (1KB of sequential bytes)
    final sampleData = Uint8List.fromList(
      List.generate(1024, (index) => index % 256),
    );

    final result = await vaultStorage.saveSecureFile(
      fileBytes: sampleData,
      fileExtension: 'dat',
    );

    setState(() {
      result.fold(
        (error) => _errorMessage = 'File Save Error: ${error.message}',
        (metadata) {
          _fileMetadata = metadata;
          _operationResult = 'Secure file saved! ID: ${metadata['fileId']}';
        },
      );
    });
  }

  Future<void> _getSecureFile() async {
    if (_fileMetadata == null) {
      setState(() {
        _errorMessage = 'No file saved yet. Save a file first.';
      });
      return;
    }

    _clearMessages();
    final vaultStorage = await ref.read(vaultStorageProvider.future);
    final result =
        await vaultStorage.getSecureFile(fileMetadata: _fileMetadata!);

    setState(() {
      result.fold(
        (error) => _errorMessage = 'File Get Error: ${error.message}',
        (fileBytes) => _operationResult =
            'File retrieved! Size: ${fileBytes.length} bytes',
      );
    });
  }

  Future<void> _deleteSecureFile() async {
    if (_fileMetadata == null) {
      setState(() {
        _errorMessage = 'No file saved yet. Save a file first.';
      });
      return;
    }

    _clearMessages();
    final vaultStorage = await ref.read(vaultStorageProvider.future);
    final result =
        await vaultStorage.deleteSecureFile(fileMetadata: _fileMetadata!);

    setState(() {
      result.fold(
        (error) => _errorMessage = 'File Delete Error: ${error.message}',
        (_) {
          _operationResult = 'File deleted successfully!';
          _fileMetadata = null;
        },
      );
    });
  }

  // Storage Management Operations
  Future<void> _clearSecureBox() async {
    _clearMessages();
    final vaultStorage = await ref.read(vaultStorageProvider.future);
    final result = await vaultStorage.clear(BoxType.secure);

    setState(() {
      result.fold(
        (error) => _errorMessage = 'Clear Error: ${error.message}',
        (_) => _operationResult = 'Secure box cleared!',
      );
    });
  }

  Future<void> _deleteKey() async {
    _clearMessages();
    final vaultStorage = await ref.read(vaultStorageProvider.future);
    final result =
        await vaultStorage.delete(BoxType.secure, _keyController.text);

    setState(() {
      result.fold(
        (error) => _errorMessage = 'Delete Error: ${error.message}',
        (_) => _operationResult = 'Key deleted!',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault Storage Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Input',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _keyController,
                      decoration: const InputDecoration(
                        labelText: 'Key',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _valueController,
                      decoration: const InputDecoration(
                        labelText: 'Value',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Key-Value Operations
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Key-Value Storage',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _saveSecureValue,
                          child: const Text('Save Secure'),
                        ),
                        ElevatedButton(
                          onPressed: _saveNormalValue,
                          child: const Text('Save Normal'),
                        ),
                        ElevatedButton(
                          onPressed: _getSecureValue,
                          child: const Text('Get Secure'),
                        ),
                        ElevatedButton(
                          onPressed: _getNormalValue,
                          child: const Text('Get Normal'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // File Operations
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('File Storage',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _saveSecureFile,
                          child: const Text('Save File'),
                        ),
                        ElevatedButton(
                          onPressed: _getSecureFile,
                          child: const Text('Get File'),
                        ),
                        ElevatedButton(
                          onPressed: _deleteSecureFile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete File'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Management Operations
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Storage Management',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _deleteKey,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete Key'),
                        ),
                        ElevatedButton(
                          onPressed: _clearSecureBox,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Clear Secure Box'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Results Section
            if (_retrievedValue != null ||
                _operationResult != null ||
                _errorMessage != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Results',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      if (_retrievedValue != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            border: Border.all(color: Colors.green),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Retrieved: $_retrievedValue',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (_operationResult != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            border: Border.all(color: Colors.blue),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _operationResult!,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            border: Border.all(color: Colors.red),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
