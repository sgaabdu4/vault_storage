// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Vault Storage Demo';

  @override
  String get threatJailbreak => 'Jailbreak/Root detected - device may be compromised';

  @override
  String get threatTampering => 'App tampering detected - app integrity compromised';

  @override
  String get threatDebugging => 'Debug environment detected';

  @override
  String get threatEmulator => 'Running on emulator/simulator';

  @override
  String get threatHooks => 'Runtime manipulation detected (hooks/injection)';

  @override
  String get threatUnofficialStore => 'App installed from unofficial store';

  @override
  String get threatScreenshot => 'Screen capture detected';

  @override
  String get threatScreenRecording => 'Screen recording detected';

  @override
  String get threatSystemVpn => 'System VPN detected';

  @override
  String get threatPasscode => 'Device passcode not set';

  @override
  String get threatSecureHardware => 'Secure hardware not available';

  @override
  String get threatDeveloperMode => 'Developer mode enabled';

  @override
  String get threatAdbEnabled => 'ADB debugging enabled';

  @override
  String get threatMultiInstance => 'Multiple app instances detected';

  @override
  String get failureJailbreak =>
      'Security Warning: Jailbreak detected - app may have limited functionality';

  @override
  String get failureTampering =>
      'Security Error: App tampering detected - please reinstall from official source';

  @override
  String failureThreat(String threatType, String message) {
    return 'Security threat detected: $threatType - $message';
  }

  @override
  String failureInitialization(String error) {
    return 'Initialization Error: $error';
  }

  @override
  String get securityAlertTitle => 'Security Alert';

  @override
  String get securityIssuesDetected => 'Security issues detected:';

  @override
  String securityThreatItem(String threat) {
    return '• $threat';
  }

  @override
  String get securityFunctionalityLimited => 'App functionality may be limited.';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get fieldKey => 'Key';

  @override
  String get fieldValue => 'Value';

  @override
  String get fieldFileKey => 'File Key';

  @override
  String get selectFromKeys => 'Select from available keys';

  @override
  String get noKeysAvailable => 'No keys available';

  @override
  String get noKeysStored => 'No keys stored yet';

  @override
  String get orSeparator => 'OR';

  @override
  String get enterKeyAndValue => 'Enter Key and Value';

  @override
  String get enterKeyToRetrieve => 'Enter Key to Retrieve';

  @override
  String get enterFileKey => 'Enter File Key';

  @override
  String get enterFileKeyToRetrieve => 'Enter File Key to Retrieve';

  @override
  String get enterKeyToDelete => 'Enter Key to Delete';

  @override
  String get cancelled => 'Cancelled';

  @override
  String valueSaved(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {'secure': 'Secure', 'other': 'Normal'});
    return '$_temp0 value saved successfully!';
  }

  @override
  String saveError(String error) {
    return 'Save Error: $error';
  }

  @override
  String getError(String error) {
    return 'Get Error: $error';
  }

  @override
  String fileSaveError(String error) {
    return 'File Save Error: $error';
  }

  @override
  String fileGetError(String error) {
    return 'File Get Error: $error';
  }

  @override
  String deleteError(String error) {
    return 'Delete Error: $error';
  }

  @override
  String clearError(String error) {
    return 'Clear Error: $error';
  }

  @override
  String storageLocationError(String error) {
    return 'Error getting storage location: $error';
  }

  @override
  String valueFound(String value) {
    return 'Value: $value';
  }

  @override
  String get keyNotFound => 'Key not found';

  @override
  String get openingFilePicker => 'Opening file picker...';

  @override
  String get noFileSelected => 'No file selected';

  @override
  String get readingFile => 'Reading file...';

  @override
  String get savingFile => 'Saving file...';

  @override
  String fileSaved(String kind, String fileName, String key) {
    String _temp0 = intl.Intl.selectLogic(kind, {'secure': 'Secure', 'other': 'Normal'});
    return '$_temp0 file \"$fileName\" saved with key \"$key\"!';
  }

  @override
  String fileContent(String content) {
    return 'File content: $content';
  }

  @override
  String get fileNotFound => 'File not found';

  @override
  String get valueDeleted => 'Value deleted successfully!';

  @override
  String get secureCleared => 'Secure storage cleared successfully!';

  @override
  String get normalCleared => 'Normal storage cleared successfully!';

  @override
  String get storageLocationTitle => 'Storage Location';

  @override
  String get pathCopied => 'Path copied to clipboard!';

  @override
  String get copyPath => 'Copy Path';

  @override
  String get storageSupportDirectoryLabel => 'Application Support Directory';

  @override
  String get storageKeyFileLabel => 'Encrypted Key File';

  @override
  String get storageKeyFileFound => 'Key file found';

  @override
  String get storageKeyFileMissing => 'Key file not found';

  @override
  String get storageViewHeading => 'To view it in File Explorer:';

  @override
  String get storageViewStepRun => 'Press Win+R.';

  @override
  String get storageViewStepPaste => 'Paste the Application Support Directory path.';

  @override
  String get storageViewStepLook => 'Look for flutter_secure_storage.dat.';

  @override
  String get storageKeyFileEncrypted =>
      'This file holds your encryption key, encrypted with Windows DPAPI.';

  @override
  String get storageKeyFileKeyName => 'The key \'hive_encryption_key\' is stored inside this file.';

  @override
  String get storageKeyFileCreatedLater => 'The file is created when you first save secure data.';

  @override
  String get storageKeyFileSaveFirst => 'Try saving a secure value first.';

  @override
  String get saveSecure => 'Save Secure';

  @override
  String get saveNormal => 'Save Normal';

  @override
  String get getAuto => 'Get (Auto-detect)';

  @override
  String get getSecure => 'Get Secure';

  @override
  String get getNormal => 'Get Normal';

  @override
  String get saveSecureFile => 'Save Secure File';

  @override
  String get saveNormalFile => 'Save Normal File';

  @override
  String get getFile => 'Get File';

  @override
  String get getSecureFile => 'Get Secure File';

  @override
  String get getNormalFile => 'Get Normal File';

  @override
  String get deleteValue => 'Delete Value';

  @override
  String get clearSecureStorage => 'Clear Secure Storage';

  @override
  String get clearNormalStorage => 'Clear Normal Storage';

  @override
  String get showStorageLocation => '🔍 Show Storage Location';

  @override
  String get sectionKeyValue => 'Key-Value Storage:';

  @override
  String get sectionFile => 'File Storage:';

  @override
  String get sectionDelete => 'Delete:';

  @override
  String get sectionClear => 'Clear Storage:';

  @override
  String get sectionDebug => 'Debug:';

  @override
  String get sectionAvailableKeys => 'Available Keys:';

  @override
  String get sectionCurrentFileKey => 'Current File Key:';

  @override
  String get initializingStorage => 'Initializing storage...';

  @override
  String availableKeyItem(String key) {
    return '• $key';
  }
}
