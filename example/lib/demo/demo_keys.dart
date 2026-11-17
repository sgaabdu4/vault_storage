import 'package:example/demo/storage_kind.dart';
import 'package:material_ui/material_ui.dart';

abstract final class DemoKeys {
  static const Key saveSecure = ValueKey('save-secure');
  static const Key saveNormal = ValueKey('save-normal');
  static const Key getAuto = ValueKey('get-auto');
  static const Key getSecure = ValueKey('get-secure');
  static const Key getNormal = ValueKey('get-normal');
  static const Key saveSecureFile = ValueKey('save-secure-file');
  static const Key saveNormalFile = ValueKey('save-normal-file');
  static const Key getFile = ValueKey('get-file');
  static const Key getSecureFile = ValueKey('get-secure-file');
  static const Key getNormalFile = ValueKey('get-normal-file');
  static const Key deleteValue = ValueKey('delete-value');
  static const Key clearSecure = ValueKey('clear-secure');
  static const Key clearNormal = ValueKey('clear-normal');
  static const Key showStorageLocation = ValueKey('show-storage-location');
  static const Key dialogOk = ValueKey('dialog-ok');
  static const Key dialogCancel = ValueKey('dialog-cancel');
  static const Key copyPath = ValueKey('copy-path');
  static const Key closeDialog = ValueKey('close-dialog');
  static const Key keyField = ValueKey('key-field');
  static const Key valueField = ValueKey('value-field');
  static const Key textInputField = ValueKey('text-input-field');
  static const Key demoList = ValueKey('demo-list');

  static Key saveValue(StorageKind kind) => switch (kind) {
    .secure => saveSecure,
    .normal => saveNormal,
  };

  static Key getValue(StorageKind kind) => switch (kind) {
    .secure => getSecure,
    .normal => getNormal,
  };

  static Key saveFile(StorageKind kind) => switch (kind) {
    .secure => saveSecureFile,
    .normal => saveNormalFile,
  };

  static Key getStoredFile(StorageKind kind) => switch (kind) {
    .secure => getSecureFile,
    .normal => getNormalFile,
  };

  static Key clearStorage(StorageKind kind) => switch (kind) {
    .secure => clearSecure,
    .normal => clearNormal,
  };
}
