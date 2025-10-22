import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vault_storage/vault_storage.dart';

/*
 * Vault Storage Demo - Platform Setup Requirements
 * 
 * This example demonstrates secure storage capabilities using vault_storage package.
 * Below are the platform-specific configurations required for each platform:
 * 
 * ============================================================================
 * 🍎 macOS Setup
 * ============================================================================
 * 
 * 1. ENTITLEMENTS (Required for Keychain & File Access):
 *    Add to macos/Runner/DebugProfile.entitlements:
 *    ```xml
 *    <key>com.apple.security.app-sandbox</key>
 *    <true/>
 *    <key>com.apple.security.cs.allow-jit</key>
 *    <true/>
 *    <key>com.apple.security.network.server</key>
 *    <true/>
 *    <key>com.apple.security.files.user-selected.read-write</key>
 *    <true/>
 *    <key>com.apple.security.files.downloads.read-write</key>
 *    <true/>
 *    <key>com.apple.security.temporary-exception.files.home-relative-path.read-write</key>
 *    <array>
 *      <string>/</string>
 *    </array>
 *    <key>keychain-access-groups</key>
 *    <array>
 *      <string>$(AppIdentifierPrefix)$(CFBundleIdentifier)</string>
 *    </array>
 *    ```
 * 
 *    Add to macos/Runner/Release.entitlements:
 *    ```xml
 *    <key>com.apple.security.app-sandbox</key>
 *    <true/>
 *    <key>com.apple.security.files.user-selected.read-write</key>
 *    <true/>
 *    <key>com.apple.security.files.downloads.read-write</key>
 *    <true/>
 *    <key>com.apple.security.temporary-exception.files.home-relative-path.read-write</key>
 *    <array>
 *      <string>/</string>
 *    </array>
 *    <key>keychain-access-groups</key>
 *    <array>
 *      <string>$(AppIdentifierPrefix)$(CFBundleIdentifier)</string>
 *    </array>
 *    ```
 * 
 * ============================================================================
 * 📱 iOS Setup
 * ============================================================================
 * 
 * 1. KEYCHAIN ACCESS:
 *    Add to ios/Runner/Runner.entitlements:
 *    ```xml
 *    <key>keychain-access-groups</key>
 *    <array>
 *      <string>$(AppIdentifierPrefix)$(CFBundleIdentifier)</string>
 *    </array>
 *    ```
 * 
 * 2. FILE ACCESS (if using file operations):
 *    Add to ios/Runner/Info.plist:
 *    ```xml
 *    <key>NSDocumentsFolderUsageDescription</key>
 *    <string>This app needs access to documents folder to save files securely.</string>
 *    <key>NSDownloadsFolderUsageDescription</key>
 *    <string>This app needs access to downloads folder to save files.</string>
 *    ```
 * 
 * ============================================================================
 * 🤖 Android Setup
 * ============================================================================
 * 
 * 1. PERMISSIONS:
 *    Add to android/app/src/main/AndroidManifest.xml:
 *    ```xml
 *    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
 *    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
 *    <uses-permission android:name="android.permission.INTERNET" />
 *    ```
 * 
 * 2. MINIMUM SDK:
 *    In android/app/build.gradle, ensure:
 *    ```gradle
 *    minSdkVersion 21  // Required for secure storage APIs
 *    ```
 * 
 * 3. PROGUARD (if using):
 *    Add to android/app/proguard-rules.pro:
 *    ```
 *    -keep class io.flutter.plugins.** { *; }
 *    -keep class androidx.biometric.** { *; }
 *    ```
 * 
 * ============================================================================
 * 🪟 Windows Setup
 * ============================================================================
 * 
 * 1. MINIMUM VERSION:
 *    In windows/runner/CMakeLists.txt, ensure:
 *    ```cmake
 *    set(CMAKE_CXX_STANDARD 17)
 *    ```
 * 
 * 2. SECURE STORAGE:
 *    Windows uses DPAPI (Data Protection API) to encrypt the master encryption key.
 *    The encrypted key is stored in a file: %APPDATA%\<app_name>\flutter_secure_storage.dat
 *    Your actual data is encrypted with AES-256-GCM and stored in Hive boxes.
 *    The DPAPI encryption is tied to your Windows user account for security.
 *    This provides better performance and scalability than Windows Credential Manager.
 * 
 * 3. FILE PERMISSIONS:
 *    For file operations, ensure app has write permissions to selected directories.
 *    This is handled automatically by the file_picker package.
 * 
 * ============================================================================
 * 🌐 Web Setup
 * ============================================================================
 * 
 * 1. LIMITATIONS:
 *    - Web platform uses browser's localStorage for storage
 *    - Security level is lower than native platforms
 *    - Large files may cause memory issues
 * 
 * 2. CORS (if accessing external resources):
 *    Add to web/index.html if needed:
 *    ```html
 *    <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self'">
 *    ```
 * 
 * 3. HTTPS REQUIREMENT:
 *    - Secure storage APIs require HTTPS in production
 *    - Use `flutter run -d web-server --web-hostname localhost --web-port 8080` for local testing
 * 
 * ============================================================================
 * 📦 Package Dependencies
 * ============================================================================
 * 
 * Add to pubspec.yaml:
 * ```yaml
 * dependencies:
 *   vault_storage: ^x.x.x  # Check latest version
 *   file_picker: ^8.0.0+1  # For file upload/download functionality
 * ```
 * 
 * ============================================================================
 * 🔧 Common Issues & Solutions
 * ============================================================================
 * 
 * 1. "Failed to initialize storage: Failed to create/decode secure key"
 *    - Missing keychain entitlements (macOS/iOS)
 *    - Run: flutter clean && flutter pub get && flutter run
 * 
 * 2. File picker not working:
 *    - Missing file access permissions
 *    - Check platform-specific file access setup above
 * 
 * 3. Build failures:
 *    - Ensure minimum SDK versions are met
 *    - Clean build: flutter clean && flutter pub get
 * 
 * 4. Web storage issues:
 *    - Check browser console for errors
 *    - Ensure HTTPS in production
 *    - Clear browser storage/cache
 * 
 * ============================================================================
 * 🚀 Quick Start Commands
 * ============================================================================
 * 
 * 1. Get dependencies: flutter pub get
 * 2. Run on macOS: flutter run -d macos
 * 3. Run on iOS: flutter run -d ios
 * 4. Run on Android: flutter run -d android
 * 5. Run on Windows: flutter run -d windows
 * 6. Run on Web: flutter run -d web
 * 
 * For any platform-specific issues, refer to the setup sections above.
 * 
 */
void main() {
  runApp(const MyApp());
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
      setState(() {
        _errorMessage = 'Security Warning: Jailbreak detected - app may have limited functionality';
        _isInitialized = false;
      });
    } on TamperingDetectedException {
      setState(() {
        _errorMessage =
            'Security Error: App tampering detected - please reinstall from official source';
        _isInitialized = false;
      });
    } on SecurityThreatException catch (e) {
      setState(() {
        _errorMessage = 'Security threat detected: ${e.threatType} - ${e.message}';
        _isInitialized = false;
      });
    } catch (e) {
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
            const Text(
              'Security issues detected:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._securityThreats.map((threat) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $threat'),
                )),
            const SizedBox(height: 8),
            const Text('App functionality may be limited.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, {
              'key': keyController.text,
              'value': valueController.text,
            }),
            child: const Text('OK'),
          ),
        ],
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
                        .map((key) => DropdownMenuItem(
                              value: key,
                              child: Text(key),
                            ))
                        .toList()
                    : [
                        const DropdownMenuItem(
                          child: Text('No keys stored yet'),
                        ),
                      ],
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('OK'),
            ),
          ],
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

      final FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result == null) {
        setState(() => _operationResult = 'No file selected');
        return;
      }

      final file = result.files.first;
      final fileName = file.name;

      final fileKey = await _getInput('Enter File Key', 'File Key');
      if (fileKey?.isEmpty ?? true) {
        setState(() => _operationResult = 'Cancelled');
        return;
      }

      setState(() => _operationResult = 'Reading file...');
      final Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = Uint8List.fromList(await File(file.path!).readAsBytes());
      } else {
        throw Exception('Cannot read file');
      }

      setState(() => _operationResult = 'Saving file...');

      if (isSecure) {
        await vaultStorage.saveSecureFile(
            key: fileKey!, fileBytes: bytes, originalFileName: fileName);
      } else {
        await vaultStorage.saveNormalFile(
            key: fileKey!, fileBytes: bytes, originalFileName: fileName);
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
      final encryptedFilePath = '${appSupportDir.path}${Platform.pathSeparator}flutter_secure_storage.dat';
      final fileExists = await File(encryptedFilePath).exists();
      
      final message = '''
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
            content: SingleChildScrollView(
              child: SelectableText(message),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: appSupportDir.path));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Path copied to clipboard!')),
                    );
                  }
                },
                child: const Text('Copy Path'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
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
      child: ElevatedButton(
        onPressed: _isInitialized ? onPressed : null,
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault Storage Demo'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isInitialized)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
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
                style: TextStyle(
                  color: _errorMessage != null ? Colors.red : Colors.green,
                ),
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
    vaultStorage.dispose();
    super.dispose();
  }
}
