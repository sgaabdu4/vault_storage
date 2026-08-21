import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vault_storage/vault_storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vault Storage Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const VaultStorageDemo(),
    );
  }
}

class VaultStorageDemo extends StatefulWidget {
  const VaultStorageDemo({super.key});

  @override
  State<VaultStorageDemo> createState() => _VaultStorageDemoState();
}

class _VaultStorageDemoState extends State<VaultStorageDemo> {
  // Simple list to collect security threats during initialization
  final List<String> _securityThreats = [];

  // Collect all security threats first, then show one dialog
  Future<void> _checkSecurityAndInitialize() async {
    try {
      // Clear any previous threats
      _securityThreats.clear();

      // Create VaultStorage with optional features:
      // - customBoxes: Organize data into separate logical containers
      // - storageDirectory: Set custom subdirectory for Hive storage
      // - securityConfig: Configure runtime security with FreeRASP (Android/iOS only)
      //
      // Example with all features:
      // vaultStorage = VaultStorage.create(
      //   customBoxes: [
      //     BoxConfig(name: 'themes', encrypted: false),
      //     BoxConfig(name: 'auth', encrypted: true),
      //   ],
      //   storageDirectory: 'my_app_data',
      //   securityConfig: VaultSecurityConfig.production(
      //     watcherMail: 'security@example.com',
      //     androidPackageName: 'com.example.app',           // Android
      //     androidSigningCertHashes: ['your_cert_hash'],    // Android
      //     iosBundleId: 'com.example.app',                  // iOS
      //     iosTeamId: 'YOUR_TEAM_ID',                       // iOS
      //     threatCallbacks: { ... },
      //   ),
      // );

      // Create VaultStorage with security features for production
      // Note: Security features only work on Android and iOS platforms
      vaultStorage = VaultStorage.create(
        securityConfig: VaultSecurityConfig.production(
          watcherMail: 'security@example.com',
          // Platform identifiers for FreeRASP security
          iosBundleId: 'com.example.storageService.example', // iOS
          iosTeamId: 'YOUR_TEAM_ID', // iOS
          // androidPackageName: 'com.example.storage_service',   // Android
          // androidSigningCertHashes: ['your_cert_hash'],        // Android
          threatCallbacks: {
            SecurityThreat.jailbreak: () =>
                _securityThreats.add('Jailbreak/Root detected - device may be compromised'),
            SecurityThreat.tampering: () =>
                _securityThreats.add('App tampering detected - app integrity compromised'),
            SecurityThreat.debugging: () => _securityThreats.add('Debug environment detected'),
            SecurityThreat.emulator: () => _securityThreats.add('Running on emulator/simulator'),
            SecurityThreat.hooks: () =>
                _securityThreats.add('Runtime manipulation detected (hooks/injection)'),
            SecurityThreat.unofficialStore: () =>
                _securityThreats.add('App installed from unofficial store'),
            SecurityThreat.screenshot: () => _securityThreats.add('Screen capture detected'),
            SecurityThreat.screenRecording: () => _securityThreats.add('Screen recording detected'),
            SecurityThreat.systemVPN: () => _securityThreats.add('System VPN detected'),
            SecurityThreat.passcode: () => _securityThreats.add('Device passcode not set'),
            SecurityThreat.secureHardware: () =>
                _securityThreats.add('Secure hardware not available'),
            SecurityThreat.developerMode: () => _securityThreats.add('Developer mode enabled'),
            SecurityThreat.adbEnabled: () => _securityThreats.add('ADB debugging enabled'),
            SecurityThreat.multiInstance: () =>
                _securityThreats.add('Multiple app instances detected'),
          },
        ),
      );

      // Initialize storage - all config is in create(), so init() takes no params
      await vaultStorage.init();

      // Load existing keys
      final keys = await vaultStorage.keys();

      // Update UI
      setState(() {
        _isInitialized = true;
        _availableKeys
          ..clear()
          ..addAll(keys);
      });

      // Show security dialog ONCE if any threats were detected
      if (_securityThreats.isNotEmpty && mounted) {
        _showSecurityDialog();
      }
    } on JailbreakDetectedException {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Security Warning: Jailbreak detected - app may have limited functionality';
        _isInitialized = false;
      });
    } on TamperingDetectedException {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Security Error: App tampering detected - please reinstall from official source';
        _isInitialized = false;
      });
    } on SecurityThreatException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Security threat detected: ${e.threatType} - ${e.message}';
        _isInitialized = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Initialization Error: $e';
      });
    }
  }

  // Simple dialog showing all collected threats
  void _showSecurityDialog() {
    showAdaptiveDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Security Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Security issues detected:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._securityThreats.map(
              (threat) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $threat'),
              ),
            ),
            const SizedBox(height: 8),
            const Text('App functionality may be limited.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  // VaultStorage instance to be initialized in initState
  late final IVaultStorage vaultStorage;
  String? _operationResult;
  String? _errorMessage;
  String? _fileKey;
  bool _isInitialized = false;
  final List<String> _availableKeys = [];

  @override
  void initState() {
    super.initState();
    _checkSecurityAndInitialize();
  }

  void _clearMessages() {
    setState(() {
      _operationResult = null;
      _errorMessage = null;
    });
  }

  List<Widget> _dialogActions<T>(BuildContext dialogContext, T Function() value) => [
    TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
    TextButton(onPressed: () => Navigator.pop(dialogContext, value()), child: const Text('OK')),
  ];

  Future<String?> _getInput(String title, String label) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
        ),
        actions: _dialogActions(context, () => controller.text),
      ),
    );
  }

  Future<Map<String, String>?> _getKeyValueInput(String title) async {
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              decoration: const InputDecoration(labelText: 'Key'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(labelText: 'Value'),
            ),
          ],
        ),
        actions: _dialogActions(
          context,
          () => {'key': keyController.text, 'value': valueController.text},
        ),
      ),
    );
  }

  Future<String?> _getKeyWithDropdown(String title, String label) async {
    final controller = TextEditingController();
    String? selectedKey;

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: _availableKeys.isNotEmpty
                      ? 'Select from available keys'
                      : 'No keys available',
                ),
                initialValue: selectedKey,
                items: _availableKeys.isNotEmpty
                    ? _availableKeys
                          .map((key) => DropdownMenuItem(value: key, child: Text(key)))
                          .toList()
                    : [const DropdownMenuItem(child: Text('No keys stored yet'))],
                onChanged: _availableKeys.isNotEmpty
                    ? (value) {
                        setState(() {
                          selectedKey = value;
                          controller.text = value ?? '';
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 16),
              const Text('OR', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(labelText: label),
                onChanged: (value) {
                  setState(() {
                    selectedKey = null;
                  });
                },
              ),
            ],
          ),
          actions: _dialogActions(context, () => controller.text),
        ),
      ),
    );
  }

  // Consolidated operations
  Future<void> _saveValue({required bool isSecure}) async {
    _clearMessages();
    try {
      final result = await _getKeyValueInput('Enter Key and Value');
      if (result == null || result['key']?.isEmpty == true || result['value']?.isEmpty == true) {
        setState(() => _operationResult = 'Cancelled');
        return;
      }

      final key = result['key']!;
      final value = result['value']!;

      if (isSecure) {
        await vaultStorage.saveSecure(key: key, value: value);
      } else {
        await vaultStorage.saveNormal(key: key, value: value);
      }

      setState(() {
        _operationResult = '${isSecure ? 'Secure' : 'Normal'} value saved successfully!';
        if (!_availableKeys.contains(key)) _availableKeys.add(key);
      });
    } catch (e) {
      setState(() => _errorMessage = 'Save Error: $e');
    }
  }

  Future<void> _getValue({bool? isSecure}) async {
    _clearMessages();
    try {
      final key = await _getKeyWithDropdown('Enter Key to Retrieve', 'Key');
      if (key?.isEmpty ?? true) {
        setState(() => _operationResult = 'Cancelled');
        return;
      }

      final value = await vaultStorage.get<String>(key!, isSecure: isSecure);
      setState(() {
        _operationResult = value != null ? 'Value: $value' : 'Key not found';
      });
    } catch (e) {
      setState(() => _errorMessage = 'Get Error: $e');
    }
  }

  Future<void> _saveFile({required bool isSecure}) async {
    _clearMessages();
    try {
      setState(() => _operationResult = 'Opening file picker...');

      final List<PlatformFile> result = await FilePicker.pickFiles();

      if (result.isEmpty) {
        setState(() => _operationResult = 'No file selected');
        return;
      }

      final file = result.first;
      final fileName = file.name;

      final fileKey = await _getInput('Enter File Key', 'File Key');
      if (fileKey?.isEmpty ?? true) {
        setState(() => _operationResult = 'Cancelled');
        return;
      }

      setState(() => _operationResult = 'Reading file...');
      final Uint8List bytes = await file.readAsBytes();

      setState(() => _operationResult = 'Saving file...');

      if (isSecure) {
        await vaultStorage.saveSecureFile(
          key: fileKey!,
          fileBytes: bytes,
          originalFileName: fileName,
        );
      } else {
        await vaultStorage.saveNormalFile(
          key: fileKey!,
          fileBytes: bytes,
          originalFileName: fileName,
        );
      }

      setState(() {
        _operationResult =
            '${isSecure ? 'Secure' : 'Normal'} file "$fileName" saved with key "$fileKey"!';
        _fileKey = fileKey;
        if (!_availableKeys.contains(fileKey)) _availableKeys.add(fileKey);
      });
    } catch (e) {
      setState(() => _errorMessage = 'File Save Error: $e');
    }
  }

  Future<void> _getFile({bool? isSecure}) async {
    _clearMessages();
    final key = await _getKeyWithDropdown('Enter File Key to Retrieve', 'File Key');
    if (key?.isEmpty ?? true) {
      setState(() => _operationResult = 'Cancelled');
      return;
    }

    try {
      final fileBytes = await vaultStorage.getFile(key!, isSecure: isSecure);
      setState(() {
        if (fileBytes != null) {
          final content = String.fromCharCodes(fileBytes);
          _operationResult = 'File content: $content';
          _fileKey = key;
        } else {
          _operationResult = 'File not found';
        }
      });
    } catch (e) {
      setState(() => _errorMessage = 'File Get Error: $e');
    }
  }

  Future<void> _delete() async {
    _clearMessages();
    final key = await _getKeyWithDropdown('Enter Key to Delete', 'Key');
    if (key?.isEmpty ?? true) {
      setState(() => _operationResult = 'Cancelled');
      return;
    }

    try {
      await vaultStorage.delete(key!);
      setState(() {
        _operationResult = 'Value deleted successfully!';
        _availableKeys.remove(key);
      });
    } catch (e) {
      setState(() => _errorMessage = 'Delete Error: $e');
    }
  }

  Future<void> _showStorageLocation() async {
    _clearMessages();
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final encryptedFilePath =
          '${appSupportDir.path}${Platform.pathSeparator}flutter_secure_storage.dat';
      final fileExists = File(encryptedFilePath).existsSync();

      final message =
          '''
Storage Location Information:

📁 Application Support Directory:
${appSupportDir.path}

🔐 Encrypted Key File:
$encryptedFilePath

File exists: ${fileExists ? '✅ YES' : '❌ NO'}

${fileExists ? '''
To view in File Explorer:
1. Press Win+R
2. Paste: ${appSupportDir.path}
3. Look for: flutter_secure_storage.dat

This file contains your encryption key encrypted with Windows DPAPI.
The key 'hive_encryption_key' is stored inside this file.
''' : '''
The file will be created when you first save secure data.
Try saving a secure value first.
'''}
      ''';

      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Storage Location'),
            content: SingleChildScrollView(child: SelectableText(message)),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: appSupportDir.path));
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Path copied to clipboard!')));
                  }
                },
                child: const Text('Copy Path'),
              ),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error getting storage location: $e');
    }
  }

  Future<void> _clearSecureStorage() async {
    _clearMessages();
    try {
      await vaultStorage.clearSecure();
      // Refresh keys after clear
      final keys = await vaultStorage.keys();
      setState(() {
        _operationResult = 'Secure storage cleared successfully!';
        _availableKeys
          ..clear()
          ..addAll(keys);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Clear Error: $e';
      });
    }
  }

  Future<void> _clearNormalStorage() async {
    _clearMessages();
    try {
      await vaultStorage.clearNormal();
      // Refresh keys after clear
      final keys = await vaultStorage.keys();
      setState(() {
        _operationResult = 'Normal storage cleared successfully!';
        _availableKeys
          ..clear()
          ..addAll(keys);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Clear Error: $e';
      });
    }
  }

  Widget _buildButton(String text, VoidCallback? onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ElevatedButton(onPressed: _isInitialized ? onPressed : null, child: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vault Storage Demo')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isInitialized)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Initializing storage...'),
                ],
              ),
            ),
          if (_operationResult != null || _errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                _errorMessage ?? _operationResult!,
                style: TextStyle(color: _errorMessage != null ? Colors.red : Colors.green),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12.0),
              children: [
                const Text('Key-Value Storage:'),
                const SizedBox(height: 8),
                _buildButton('Save Secure', () => _saveValue(isSecure: true)),
                _buildButton('Save Normal', () => _saveValue(isSecure: false)),
                _buildButton('Get (Auto-detect)', () => _getValue()),
                _buildButton('Get Secure', () => _getValue(isSecure: true)),
                _buildButton('Get Normal', () => _getValue(isSecure: false)),
                const SizedBox(height: 16),
                const Text('File Storage:'),
                const SizedBox(height: 8),
                _buildButton('Save Secure File', () => _saveFile(isSecure: true)),
                _buildButton('Save Normal File', () => _saveFile(isSecure: false)),
                _buildButton('Get File', () => _getFile()),
                _buildButton('Get Secure File', () => _getFile(isSecure: true)),
                _buildButton('Get Normal File', () => _getFile(isSecure: false)),
                const SizedBox(height: 16),
                const Text('Delete:'),
                _buildButton('Delete Value', _delete),
                const SizedBox(height: 16),
                const Text('Clear Storage:'),
                _buildButton('Clear Secure Storage', _clearSecureStorage),
                _buildButton('Clear Normal Storage', _clearNormalStorage),
                const SizedBox(height: 16),
                const Text('Debug:'),
                _buildButton('🔍 Show Storage Location', _showStorageLocation),
                if (_availableKeys.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Available Keys:'),
                  ..._availableKeys.map((key) => Text('• $key')),
                ],
                if (_fileKey != null) ...[
                  const SizedBox(height: 16),
                  const Text('Current File Key:'),
                  Text(_fileKey!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    try {
      vaultStorage.dispose();
    } catch (_) {
      // Ignore errors if vaultStorage was never initialized
    }
    super.dispose();
  }
}
