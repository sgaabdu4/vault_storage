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

import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vault_storage/vault_storage.dart';
import 'package:file_picker/file_picker.dart';

// Global storage instance
late IVaultStorage vaultStorage;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize vault storage
    vaultStorage = VaultStorage.create();
    final initResult = await vaultStorage.init();

    initResult.fold(
      (error) =>
          throw Exception('Failed to initialize storage: ${error.message}'),
      (_) => print('Storage initialized successfully'),
    );

    runApp(const MyApp());
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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _keyController = TextEditingController(text: 'my_secret_key');
  final _valueController = TextEditingController(text: 'my secret value');
  String? _retrievedValue;
  String? _errorMessage;
  String? _operationResult;
  Map<String, dynamic>? _fileMetadata;
  String? _uploadedFileName;

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

    // For web platforms, this will automatically trigger a download
    // For native platforms, it just returns the file bytes
    // You can optionally specify a custom filename:
    // await vaultStorage.getSecureFile(
    //   fileMetadata: _fileMetadata!,
    //   downloadFileName: 'my_custom_filename.txt',
    // );
    final result =
        await vaultStorage.getSecureFile(fileMetadata: _fileMetadata!);

    setState(() {
      result.fold(
        (error) => _errorMessage = 'File Get Error: ${error.message}',
        (fileBytes) {
          String fileName = _uploadedFileName ?? 'Unknown file';
          _operationResult =
              'File "$fileName" retrieved!\nSize: ${fileBytes.length} bytes';
        },
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

  // File Storage Operations - Secure Upload/Download
  Future<void> _secureFileUpload() async {
    _clearMessages();

    try {
      // Pick a file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true, // Important: This loads the file data into memory
      );

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.first;

        if (file.bytes != null) {
          // Get file extension from file name
          String extension = file.extension ?? 'bin';

          // Save the file securely
          final saveResult = await vaultStorage.saveSecureFile(
            fileBytes: file.bytes!,
            fileExtension: extension,
          );

          setState(() {
            saveResult.fold(
              (error) =>
                  _errorMessage = 'Secure Upload Error: ${error.message}',
              (metadata) {
                _fileMetadata = metadata;
                _uploadedFileName = file.name;
                _operationResult =
                    'File "${file.name}" uploaded and saved securely!\n'
                    'Size: ${file.bytes!.length} bytes\n'
                    'File ID: ${metadata['fileId']}';
              },
            );
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to read file data. Please try again.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'No file selected for upload.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'File picker error: $e';
      });
    }
  }

  Future<void> _secureFileDownload() async {
    if (_fileMetadata == null) {
      setState(() {
        _errorMessage = 'No file saved yet. Upload a file first.';
      });
      return;
    }

    _clearMessages();

    try {
      // Retrieve the file from secure storage
      final result =
          await vaultStorage.getSecureFile(fileMetadata: _fileMetadata!);

      result.fold(
        (error) {
          setState(() {
            _errorMessage = 'Secure Download Error: ${error.message}';
          });
        },
        (fileBytes) async {
          // Let user choose where to save the downloaded file
          String? outputFile = await FilePicker.platform.saveFile(
            dialogTitle: 'Save downloaded file',
            fileName: _uploadedFileName ?? 'downloaded_file',
          );

          if (outputFile != null) {
            try {
              // Write the file to the selected location
              final file = File(outputFile);
              await file.writeAsBytes(fileBytes);

              setState(() {
                String fileName = _uploadedFileName ?? 'Downloaded file';
                _operationResult = 'File "$fileName" downloaded successfully!\n'
                    'Size: ${fileBytes.length} bytes\n'
                    'Saved to: $outputFile';
              });
            } catch (e) {
              setState(() {
                _errorMessage = 'Failed to save file: $e';
              });
            }
          } else {
            setState(() {
              _errorMessage = 'Download cancelled - no save location selected.';
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Download error: $e';
      });
    }
  }

  // Storage Management Operations
  Future<void> _clearSecureBox() async {
    _clearMessages();
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
    final result =
        await vaultStorage.delete(BoxType.secure, _keyController.text);

    setState(() {
      result.fold(
        (error) => _errorMessage = 'Delete Error: ${error.message}',
        (_) => _operationResult = 'Key deleted!',
      );
    });
  }

  // Helper method to create buttons with optional styling
  Widget _buildButton(String text, VoidCallback onPressed,
      {Color? color, IconData? icon}) {
    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
        style: color != null
            ? ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              )
            : null,
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: color != null
          ? ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            )
          : null,
      child: Text(text),
    );
  }

  // Helper method to create button sections
  Widget _buildButtonSection(String title, List<Widget> buttons) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: buttons),
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
                          labelText: 'Key', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _valueController,
                      decoration: const InputDecoration(
                          labelText: 'Value', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Key-Value Operations
            _buildButtonSection('Key-Value Storage', [
              _buildButton('Save Encrypted Text', _saveSecureValue,
                  color: Colors.green),
              _buildButton('Save Plain Text', _saveNormalValue),
              _buildButton('Get Encrypted Text', _getSecureValue,
                  color: Colors.green),
              _buildButton('Get Plain Text', _getNormalValue),
            ]),
            const SizedBox(height: 16),

            // File Operations
            _buildButtonSection('File Storage', [
              _buildButton('Pick & Upload File', _secureFileUpload,
                  color: Colors.green, icon: Icons.upload_file),
              _buildButton('Download to Device', _secureFileDownload,
                  color: Colors.blue, icon: Icons.download),
              _buildButton('Create Test File', _saveSecureFile),
              _buildButton('View File Info', _getSecureFile),
              _buildButton('Delete File', _deleteSecureFile, color: Colors.red),
            ]),
            const SizedBox(height: 16),

            // Management Operations
            _buildButtonSection('Storage Management', [
              _buildButton('Delete Current Key', _deleteKey,
                  color: Colors.orange, icon: Icons.delete_outline),
              _buildButton('Clear All Encrypted Data', _clearSecureBox,
                  color: Colors.red, icon: Icons.delete_sweep),
            ]),

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
