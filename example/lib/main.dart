import 'dart:io';

import 'package:example/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vault_storage/vault_storage.dart';

void main() {
  runApp(const MyApp());
}

@visibleForTesting
String initializationFailure(AppLocalizations l10n, Object error) => switch (error) {
  JailbreakDetectedException() => l10n.failureJailbreak,
  TamperingDetectedException() => l10n.failureTampering,
  SecurityThreatException(:final threatType, :final message) => l10n.failureThreat(
    threatType,
    message,
  ),
  _ => l10n.failureInitialization('$error'),
};

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
  final List<String Function(AppLocalizations)> _securityThreats = [];

  // Collect all security threats first, then show one dialog
  Future<void> _checkSecurityAndInitialize() async {
    try {
      // Clear any previous threats
      _securityThreats.clear();

      vaultStorage = _createStorage();

      // Initialize storage - all config is in create(), so init() takes no params
      await vaultStorage.init();

      // Load existing keys
      final keys = await vaultStorage.keys();

      if (!mounted) return;
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializationError = e;
        _isInitialized = false;
      });
    }
  }

  IVaultStorage _createStorage() => VaultStorage.create(
    securityConfig: .production(
      watcherMail: 'security@example.com',
      iosBundleId: 'com.example.storageService.example',
      iosTeamId: 'YOUR_TEAM_ID',
      threatCallbacks: {
        .jailbreak: () => _securityThreats.add((l10n) => l10n.threatJailbreak),
        .tampering: () => _securityThreats.add((l10n) => l10n.threatTampering),
        .debugging: () => _securityThreats.add((l10n) => l10n.threatDebugging),
        .emulator: () => _securityThreats.add((l10n) => l10n.threatEmulator),
        .hooks: () => _securityThreats.add((l10n) => l10n.threatHooks),
        .unofficialStore: () => _securityThreats.add((l10n) => l10n.threatUnofficialStore),
        .screenshot: () => _securityThreats.add((l10n) => l10n.threatScreenshot),
        .screenRecording: () => _securityThreats.add((l10n) => l10n.threatScreenRecording),
        .systemVPN: () => _securityThreats.add((l10n) => l10n.threatSystemVpn),
        .passcode: () => _securityThreats.add((l10n) => l10n.threatPasscode),
        .secureHardware: () => _securityThreats.add((l10n) => l10n.threatSecureHardware),
        .developerMode: () => _securityThreats.add((l10n) => l10n.threatDeveloperMode),
        .adbEnabled: () => _securityThreats.add((l10n) => l10n.threatAdbEnabled),
        .multiInstance: () => _securityThreats.add((l10n) => l10n.threatMultiInstance),
      },
    ),
  );

  // Simple dialog showing all collected threats
  void _showSecurityDialog() {
    showAdaptiveDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog.adaptive(
        title: Text(AppLocalizations.of(context).securityAlertTitle),
        content: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            Text(
              AppLocalizations.of(context).securityIssuesDetected,
              style: const TextStyle(fontWeight: .bold),
            ),
            const SizedBox(height: 8),
            ..._securityThreats.map(
              (threat) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  AppLocalizations.of(context)
                      .securityThreatItem(threat(AppLocalizations.of(context))),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context).securityFunctionalityLimited),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).ok),
          ),
        ],
      ),
    );
  }

  // VaultStorage instance to be initialized in initState
  late final IVaultStorage vaultStorage;
  String? _operationResult;
  String? _errorMessage;
  Object? _initializationError;
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
    TextButton(
      onPressed: () => Navigator.pop(dialogContext),
      child: Text(AppLocalizations.of(dialogContext).cancel),
    ),
    TextButton(
      onPressed: () => Navigator.pop(dialogContext, value()),
      child: Text(AppLocalizations.of(dialogContext).ok),
    ),
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
          mainAxisSize: .min,
          children: [
            TextField(
              controller: keyController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context).fieldKey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valueController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context).fieldValue),
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
            mainAxisSize: .min,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: _availableKeys.isNotEmpty
                      ? AppLocalizations.of(context).selectFromKeys
                      : AppLocalizations.of(context).noKeysAvailable,
                ),
                initialValue: selectedKey,
                items: _availableKeys.isNotEmpty
                    ? _availableKeys
                          .map((key) => DropdownMenuItem(value: key, child: Text(key)))
                          .toList()
                    : [DropdownMenuItem(child: Text(AppLocalizations.of(context).noKeysStored))],
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
              Text(
                AppLocalizations.of(context).orSeparator,
                style: const TextStyle(fontWeight: .bold),
              ),
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
    final l10n = AppLocalizations.of(context);
    try {
      final result = await _getKeyValueInput(l10n.enterKeyAndValue);
      if (result == null || result['key']?.isEmpty == true || result['value']?.isEmpty == true) {
        setState(() => _operationResult = l10n.cancelled);
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
        _operationResult = l10n.valueSaved(isSecure ? 'secure' : 'normal');
        if (!_availableKeys.contains(key)) _availableKeys.add(key);
      });
    } catch (e) {
      setState(() => _errorMessage = l10n.saveError('$e'));
    }
  }

  Future<void> _getValue({bool? isSecure}) async {
    _clearMessages();
    final l10n = AppLocalizations.of(context);
    try {
      final key = await _getKeyWithDropdown(l10n.enterKeyToRetrieve, l10n.fieldKey);
      if (key?.isEmpty ?? true) {
        setState(() => _operationResult = l10n.cancelled);
        return;
      }

      final value = await vaultStorage.get<String>(key!, isSecure: isSecure);
      setState(() {
        _operationResult = value != null ? l10n.valueFound(value) : l10n.keyNotFound;
      });
    } catch (e) {
      setState(() => _errorMessage = l10n.getError('$e'));
    }
  }

  Future<void> _saveFile({required bool isSecure}) async {
    _clearMessages();
    final l10n = AppLocalizations.of(context);
    try {
      setState(() => _operationResult = l10n.openingFilePicker);

      final List<PlatformFile> result = await FilePicker.pickFiles();

      if (result.isEmpty) {
        setState(() => _operationResult = l10n.noFileSelected);
        return;
      }

      final file = result.first;
      final fileName = file.name;

      final fileKey = await _getInput(l10n.enterFileKey, l10n.fieldFileKey);
      if (fileKey?.isEmpty ?? true) {
        setState(() => _operationResult = l10n.cancelled);
        return;
      }

      setState(() => _operationResult = l10n.readingFile);
      final Uint8List bytes = await file.readAsBytes();

      setState(() => _operationResult = l10n.savingFile);

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
        _operationResult = l10n.fileSaved(isSecure ? 'secure' : 'normal', fileName, fileKey);
        _fileKey = fileKey;
        if (!_availableKeys.contains(fileKey)) _availableKeys.add(fileKey);
      });
    } catch (e) {
      setState(() => _errorMessage = l10n.fileSaveError('$e'));
    }
  }

  Future<void> _getFile({bool? isSecure}) async {
    _clearMessages();
    final l10n = AppLocalizations.of(context);
    final key = await _getKeyWithDropdown(l10n.enterFileKeyToRetrieve, l10n.fieldFileKey);
    if (key?.isEmpty ?? true) {
      setState(() => _operationResult = l10n.cancelled);
      return;
    }

    try {
      final fileBytes = await vaultStorage.getFile(key!, isSecure: isSecure);
      setState(() {
        if (fileBytes != null) {
          final content = String.fromCharCodes(fileBytes);
          _operationResult = l10n.fileContent(content);
          _fileKey = key;
        } else {
          _operationResult = l10n.fileNotFound;
        }
      });
    } catch (e) {
      setState(() => _errorMessage = l10n.fileGetError('$e'));
    }
  }

  Future<void> _delete() async {
    _clearMessages();
    final l10n = AppLocalizations.of(context);
    final key = await _getKeyWithDropdown(l10n.enterKeyToDelete, l10n.fieldKey);
    if (key?.isEmpty ?? true) {
      setState(() => _operationResult = l10n.cancelled);
      return;
    }

    try {
      await vaultStorage.delete(key!);
      setState(() {
        _operationResult = l10n.valueDeleted;
        _availableKeys.remove(key);
      });
    } catch (e) {
      setState(() => _errorMessage = l10n.deleteError('$e'));
    }
  }

  Future<void> _showStorageLocation() async {
    _clearMessages();
    final l10n = AppLocalizations.of(context);
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final encryptedFilePath =
          '${appSupportDir.path}${Platform.pathSeparator}flutter_secure_storage.dat';
      final fileExists = File(encryptedFilePath).existsSync();

      final message = l10n.storageLocationMessage(
        appSupportDir.path,
        encryptedFilePath,
        fileExists ? 'yes' : 'no',
      );

      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.storageLocationTitle),
            content: SingleChildScrollView(child: SelectableText(message)),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: appSupportDir.path));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(l10n.pathCopied)));
                  }
                },
                child: Text(l10n.copyPath),
              ),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.close)),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = l10n.storageLocationError('$e'));
    }
  }

  Future<void> _clearSecureStorage() async {
    _clearMessages();
    final l10n = AppLocalizations.of(context);
    try {
      await vaultStorage.clearSecure();
      // Refresh keys after clear
      final keys = await vaultStorage.keys();
      setState(() {
        _operationResult = l10n.secureCleared;
        _availableKeys
          ..clear()
          ..addAll(keys);
      });
    } catch (e) {
      setState(() {
        _errorMessage = l10n.clearError('$e');
      });
    }
  }

  Future<void> _clearNormalStorage() async {
    _clearMessages();
    final l10n = AppLocalizations.of(context);
    try {
      await vaultStorage.clearNormal();
      // Refresh keys after clear
      final keys = await vaultStorage.keys();
      setState(() {
        _operationResult = l10n.normalCleared;
        _availableKeys
          ..clear()
          ..addAll(keys);
      });
    } catch (e) {
      setState(() {
        _errorMessage = l10n.clearError('$e');
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
    final l10n = AppLocalizations.of(context);
    final initializationError = _initializationError;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Column(
        crossAxisAlignment: .stretch,
        children: [
          if (!_isInitialized) const _StorageInitialization(),
          _OperationMessage(
            result: _operationResult,
            error: initializationError == null
                ? _errorMessage
                : initializationFailure(l10n, initializationError),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12.0),
              children: [
                Text(l10n.sectionKeyValue),
                const SizedBox(height: 8),
                _buildButton(l10n.saveSecure, () => _saveValue(isSecure: true)),
                _buildButton(l10n.saveNormal, () => _saveValue(isSecure: false)),
                _buildButton(l10n.getAuto, () => _getValue()),
                _buildButton(l10n.getSecure, () => _getValue(isSecure: true)),
                _buildButton(l10n.getNormal, () => _getValue(isSecure: false)),
                const SizedBox(height: 16),
                Text(l10n.sectionFile),
                const SizedBox(height: 8),
                _buildButton(l10n.saveSecureFile, () => _saveFile(isSecure: true)),
                _buildButton(l10n.saveNormalFile, () => _saveFile(isSecure: false)),
                _buildButton(l10n.getFile, () => _getFile()),
                _buildButton(l10n.getSecureFile, () => _getFile(isSecure: true)),
                _buildButton(l10n.getNormalFile, () => _getFile(isSecure: false)),
                const SizedBox(height: 16),
                Text(l10n.sectionDelete),
                _buildButton(l10n.deleteValue, _delete),
                const SizedBox(height: 16),
                Text(l10n.sectionClear),
                _buildButton(l10n.clearSecureStorage, _clearSecureStorage),
                _buildButton(l10n.clearNormalStorage, _clearNormalStorage),
                const SizedBox(height: 16),
                Text(l10n.sectionDebug),
                _buildButton(l10n.showStorageLocation, _showStorageLocation),
                if (_availableKeys.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(l10n.sectionAvailableKeys),
                  ..._availableKeys.map((key) => Text(l10n.availableKeyItem(key))),
                ],
                if (_fileKey != null) ...[
                  const SizedBox(height: 16),
                  Text(l10n.sectionCurrentFileKey),
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

class _StorageInitialization extends StatelessWidget {
  const _StorageInitialization();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12.0),
    child: Row(
      children: [
        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text(AppLocalizations.of(context).initializingStorage),
      ],
    ),
  );
}

class _OperationMessage extends StatelessWidget {
  const _OperationMessage({required this.result, required this.error});

  final String? result;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final message = error ?? result;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(message, style: TextStyle(color: error != null ? Colors.red : Colors.green)),
    );
  }
}
