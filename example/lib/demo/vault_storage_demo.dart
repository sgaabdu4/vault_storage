import 'dart:async';
import 'dart:io';

import 'package:example/demo/demo_button.dart';
import 'package:example/demo/demo_keys.dart';
import 'package:example/demo/demo_storage.dart';
import 'package:example/demo/dialogs/key_dropdown_dialog.dart';
import 'package:example/demo/dialogs/key_input_dialog.dart';
import 'package:example/demo/dialogs/key_value_dialog.dart';
import 'package:example/demo/dialogs/security_alert_dialog.dart';
import 'package:example/demo/dialogs/storage_location_dialog.dart';
import 'package:example/demo/operation_message.dart';
import 'package:example/demo/sections/clear_section.dart';
import 'package:example/demo/sections/file_section.dart';
import 'package:example/demo/sections/value_section.dart';
import 'package:example/demo/storage_initialization.dart';
import 'package:example/demo/storage_kind.dart';
import 'package:example/design/spacing.dart';
import 'package:example/initialization_failure.dart';
import 'package:example/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vault_storage/vault_storage.dart';

class VaultStorageDemo extends StatefulWidget {
  const VaultStorageDemo({super.key});

  @override
  State<VaultStorageDemo> createState() => _VaultStorageDemoState();
}

class _VaultStorageDemoState extends State<VaultStorageDemo> {
  final List<ThreatLabel> _securityThreats = [];
  final List<String> _availableKeys = [];
  late final IVaultStorage _vaultStorage;
  String? _operationResult;
  String? _errorMessage;
  Object? _initializationError;
  String? _fileKey;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _vaultStorage = createDemoStorage(_securityThreats.add);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    unawaited(_vaultStorage.dispose());
    super.dispose();
  }

  void _update(VoidCallback change) {
    if (!context.mounted) return;
    setState(change);
  }

  void _clearMessages() => _update(() {
    _operationResult = null;
    _errorMessage = null;
  });

  void _replaceKeys(List<String> keys) {
    _availableKeys
      ..clear()
      ..addAll(keys);
  }

  void _rememberKey(String key) {
    if (!_availableKeys.contains(key)) _availableKeys.add(key);
  }

  Future<void> _initialize() async {
    final BuildContext screen = context;
    final List<String> keys;
    try {
      await _vaultStorage.init();
      keys = await _vaultStorage.keys();
    } catch (e) {
      _update(() {
        _initializationError = e;
        _isInitialized = false;
      });
      return;
    }
    if (!screen.mounted) return;
    setState(() {
      _isInitialized = true;
      _replaceKeys(keys);
    });
    if (_securityThreats.isEmpty) return;
    final l10n = AppLocalizations.of(screen);
    await SecurityAlertDialog.show(
      screen,
      threats: [for (final ThreatLabel threat in _securityThreats) threat(l10n)],
    );
  }

  Future<void> _saveValue(StorageKind kind) async {
    _clearMessages();
    final l10n = AppLocalizations.of(context);
    try {
      final KeyValueEntry? entry = await KeyValueDialog.show(context, title: l10n.enterKeyAndValue);
      if (entry == null || entry.key.isEmpty || entry.value.isEmpty) {
        _update(() => _operationResult = l10n.cancelled);
        return;
      }
      await switch (kind) {
        .secure => _vaultStorage.saveSecure(key: entry.key, value: entry.value),
        .normal => _vaultStorage.saveNormal(key: entry.key, value: entry.value),
      };
      _update(() {
        _operationResult = l10n.valueSaved(kind.name);
        _rememberKey(entry.key);
      });
    } catch (e) {
      _update(() => _errorMessage = l10n.saveError('$e'));
    }
  }

  Future<void> _getValue({bool? isSecure}) async {
    _clearMessages();
    final l10n = AppLocalizations.of(context);
    try {
      final String? key = await KeyDropdownDialog.show(
        context,
        title: l10n.enterKeyToRetrieve,
        label: l10n.fieldKey,
        keys: _availableKeys,
      );
      if (key == null || key.isEmpty) {
        _update(() => _operationResult = l10n.cancelled);
        return;
      }
      final String? value = await _vaultStorage.get<String>(key, isSecure: isSecure);
      _update(() => _operationResult = value != null ? l10n.valueFound(value) : l10n.keyNotFound);
    } catch (e) {
      _update(() => _errorMessage = l10n.getError('$e'));
    }
  }

  Future<void> _saveFile(StorageKind kind) async {
    _clearMessages();
    final BuildContext screen = context;
    final l10n = AppLocalizations.of(screen);
    try {
      _update(() => _operationResult = l10n.openingFilePicker);
      final List<PlatformFile> picked = await FilePicker.pickFiles();
      if (picked.isEmpty) {
        _update(() => _operationResult = l10n.noFileSelected);
        return;
      }
      final PlatformFile file = picked.first;
      if (!screen.mounted) return;
      final String? fileKey = await KeyInputDialog.show(
        screen,
        title: l10n.enterFileKey,
        label: l10n.fieldFileKey,
      );
      if (fileKey == null || fileKey.isEmpty) {
        _update(() => _operationResult = l10n.cancelled);
        return;
      }
      _update(() => _operationResult = l10n.readingFile);
      final Uint8List bytes = await file.readAsBytes();
      _update(() => _operationResult = l10n.savingFile);
      await switch (kind) {
        .secure => _vaultStorage.saveSecureFile(
          key: fileKey,
          fileBytes: bytes,
          originalFileName: file.name,
        ),
        .normal => _vaultStorage.saveNormalFile(
          key: fileKey,
          fileBytes: bytes,
          originalFileName: file.name,
        ),
      };
      _update(() {
        _operationResult = l10n.fileSaved(kind.name, file.name, fileKey);
        _fileKey = fileKey;
        _rememberKey(fileKey);
      });
    } catch (e) {
      _update(() => _errorMessage = l10n.fileSaveError('$e'));
    }
  }

  Future<void> _getFile({bool? isSecure}) async {
    _clearMessages();
    final l10n = AppLocalizations.of(context);
    final String? key = await KeyDropdownDialog.show(
      context,
      title: l10n.enterFileKeyToRetrieve,
      label: l10n.fieldFileKey,
      keys: _availableKeys,
    );
    if (key == null || key.isEmpty) {
      _update(() => _operationResult = l10n.cancelled);
      return;
    }
    try {
      final Uint8List? fileBytes = await _vaultStorage.getFile(key, isSecure: isSecure);
      _update(() {
        if (fileBytes == null) {
          _operationResult = l10n.fileNotFound;
          return;
        }
        _operationResult = l10n.fileContent(.fromCharCodes(fileBytes));
        _fileKey = key;
      });
    } catch (e) {
      _update(() => _errorMessage = l10n.fileGetError('$e'));
    }
  }

  Future<void> _delete() async {
    _clearMessages();
    final l10n = AppLocalizations.of(context);
    final String? key = await KeyDropdownDialog.show(
      context,
      title: l10n.enterKeyToDelete,
      label: l10n.fieldKey,
      keys: _availableKeys,
    );
    if (key == null || key.isEmpty) {
      _update(() => _operationResult = l10n.cancelled);
      return;
    }
    try {
      await _vaultStorage.delete(key);
      _update(() {
        _operationResult = l10n.valueDeleted;
        _availableKeys.remove(key);
      });
    } catch (e) {
      _update(() => _errorMessage = l10n.deleteError('$e'));
    }
  }

  Future<void> _showStorageLocation() async {
    _clearMessages();
    final BuildContext screen = context;
    final l10n = AppLocalizations.of(screen);
    try {
      final Directory supportDirectory = await getApplicationSupportDirectory();
      final String keyFilePath =
          '${supportDirectory.path}${Platform.pathSeparator}${DemoStorageConfig.keyFileName}';
      final KeyFilePresence presence = File(keyFilePath).existsSync() ? .yes : .no;
      if (!screen.mounted) return;
      await StorageLocationDialog.show(
        screen,
        message: l10n.storageLocationMessage(supportDirectory.path, keyFilePath, presence.name),
        path: supportDirectory.path,
      );
    } catch (e) {
      _update(() => _errorMessage = l10n.storageLocationError('$e'));
    }
  }

  Future<void> _clearStorage(StorageKind kind) async {
    _clearMessages();
    final l10n = AppLocalizations.of(context);
    try {
      await switch (kind) {
        .secure => _vaultStorage.clearSecure(),
        .normal => _vaultStorage.clearNormal(),
      };
      final List<String> keys = await _vaultStorage.keys();
      _update(() {
        _operationResult = switch (kind) {
          .secure => l10n.secureCleared,
          .normal => l10n.normalCleared,
        };
        _replaceKeys(keys);
      });
    } catch (e) {
      _update(() => _errorMessage = l10n.clearError('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Object? initializationError = _initializationError;
    final String? fileKey = _fileKey;
    final bool ready = _isInitialized;
    final List<Widget> rows = [
      ValueSection(
        enabled: ready,
        onSave: _saveValue,
        onGet: (isSecure) => _getValue(isSecure: isSecure),
      ),
      const SizedBox(height: Spacing.lg),
      FileSection(
        enabled: ready,
        onSave: _saveFile,
        onGet: (isSecure) => _getFile(isSecure: isSecure),
      ),
      const SizedBox(height: Spacing.lg),
      Text(l10n.sectionDelete),
      DemoButton(
        key: DemoKeys.deleteValue,
        label: l10n.deleteValue,
        enabled: ready,
        onPressed: _delete,
      ),
      const SizedBox(height: Spacing.lg),
      ClearSection(enabled: ready, onClear: _clearStorage),
      const SizedBox(height: Spacing.lg),
      Text(l10n.sectionDebug),
      DemoButton(
        key: DemoKeys.showStorageLocation,
        label: l10n.showStorageLocation,
        enabled: ready,
        onPressed: _showStorageLocation,
      ),
      if (_availableKeys.isNotEmpty) ...[
        const SizedBox(height: Spacing.lg),
        Text(l10n.sectionAvailableKeys),
        for (final String key in _availableKeys) Text(l10n.availableKeyItem(key)),
      ],
      if (fileKey != null) ...[
        const SizedBox(height: Spacing.lg),
        Text(l10n.sectionCurrentFileKey),
        Text(fileKey),
      ],
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Column(
        crossAxisAlignment: .stretch,
        children: [
          if (!ready) const StorageInitialization(),
          OperationMessage(
            result: _operationResult,
            error: initializationError == null
                ? _errorMessage
                : initializationFailure(l10n, initializationError),
          ),
          Expanded(
            child: ListView.builder(
              key: DemoKeys.demoList,
              padding: const .all(Spacing.md),
              itemCount: rows.length,
              itemBuilder: (context, index) => rows[index],
            ),
          ),
        ],
      ),
    );
  }
}
