import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:vault_storage/vault_storage.dart';
import 'package:file_picker/file_picker.dart';

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
 * 2. DEPENDENCIES:
 *    Windows uses Windows Credential Manager for secure storage.
 *    No additional setup required for basic functionality.
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
  final vaultStorage = VaultStorage.create();
  String? _operationResult;
  String? _errorMessage;
  String? _fileKey;
  bool _isInitialized = false;
  final List<String> _availableKeys = [];

  @override
  void initState() {
    super.initState();
    _initializeStorage();
  }

  Future<void> _initializeStorage() async {
    try {
      await vaultStorage.init();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Initialization Error: $e';
      });
    }
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
                value: selectedKey,
                items: _availableKeys.isNotEmpty
                    ? _availableKeys
                        .map((key) => DropdownMenuItem(
                              value: key,
                              child: Text(key),
                            ))
                        .toList()
                    : [
                        const DropdownMenuItem(
                          value: null,
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
      if (result == null ||
          result['key']?.isEmpty == true ||
          result['value']?.isEmpty == true) {
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
        _operationResult =
            '${isSecure ? 'Secure' : 'Normal'} value saved successfully!';
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

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

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
      late Uint8List bytes;
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
    final key =
        await _getKeyWithDropdown('Enter File Key to Retrieve', 'File Key');
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

  Future<void> _clearSecureStorage() async {
    _clearMessages();
    try {
      await vaultStorage.clearSecure();
      setState(() {
        _operationResult = 'Secure storage cleared successfully!';
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
      setState(() {
        _operationResult = 'Normal storage cleared successfully!';
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
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isInitialized ? onPressed : null,
          child: Text(text),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    if (_operationResult == null && _errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_operationResult != null) ...[
              const Text(
                'Success:',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 8),
              Text(_operationResult!),
            ],
            if (_errorMessage != null) ...[
              const Text(
                'Error:',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!),
            ],
          ],
        ),
      ),
    );
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
            if (!_isInitialized)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Initializing storage...'),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Key-Value Operations
            const Text(
              'Key-Value Storage:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildButton('Save Secure', () => _saveValue(isSecure: true)),
            _buildButton('Save Normal', () => _saveValue(isSecure: false)),
            _buildButton('Get (Auto-detect)', () => _getValue()),
            _buildButton('Get Secure', () => _getValue(isSecure: true)),
            _buildButton('Get Normal', () => _getValue(isSecure: false)),

            const SizedBox(height: 24),

            // File Operations
            const Text(
              'File Storage:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildButton('Save Secure File', () => _saveFile(isSecure: true)),
            _buildButton('Save Normal File', () => _saveFile(isSecure: false)),
            _buildButton('Get File', () => _getFile()),
            _buildButton('Get Secure File', () => _getFile(isSecure: true)),
            _buildButton('Get Normal File', () => _getFile(isSecure: false)),

            const SizedBox(height: 24),

            // Delete Operations
            const Text(
              'Delete:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildButton('Delete Value', _delete),

            const SizedBox(height: 24),

            // Clear Operations
            const Text(
              'Clear Storage:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildButton('Clear Secure Storage', _clearSecureStorage),
            _buildButton('Clear Normal Storage', _clearNormalStorage),

            // Results
            _buildResultCard(),

            // Available Keys
            if (_availableKeys.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Available Keys:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        _availableKeys.map((key) => Text('• $key')).toList(),
                  ),
                ),
              ),
            ],

            // File Key Info
            if (_fileKey != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current File Key:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_fileKey!),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    vaultStorage.dispose();
    super.dispose();
  }
}
