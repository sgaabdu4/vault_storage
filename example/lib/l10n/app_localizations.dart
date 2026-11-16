import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault Storage Demo'**
  String get appTitle;

  /// No description provided for @threatJailbreak.
  ///
  /// In en, this message translates to:
  /// **'Jailbreak/Root detected - device may be compromised'**
  String get threatJailbreak;

  /// No description provided for @threatTampering.
  ///
  /// In en, this message translates to:
  /// **'App tampering detected - app integrity compromised'**
  String get threatTampering;

  /// No description provided for @threatDebugging.
  ///
  /// In en, this message translates to:
  /// **'Debug environment detected'**
  String get threatDebugging;

  /// No description provided for @threatEmulator.
  ///
  /// In en, this message translates to:
  /// **'Running on emulator/simulator'**
  String get threatEmulator;

  /// No description provided for @threatHooks.
  ///
  /// In en, this message translates to:
  /// **'Runtime manipulation detected (hooks/injection)'**
  String get threatHooks;

  /// No description provided for @threatUnofficialStore.
  ///
  /// In en, this message translates to:
  /// **'App installed from unofficial store'**
  String get threatUnofficialStore;

  /// No description provided for @threatScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Screen capture detected'**
  String get threatScreenshot;

  /// No description provided for @threatScreenRecording.
  ///
  /// In en, this message translates to:
  /// **'Screen recording detected'**
  String get threatScreenRecording;

  /// No description provided for @threatSystemVpn.
  ///
  /// In en, this message translates to:
  /// **'System VPN detected'**
  String get threatSystemVpn;

  /// No description provided for @threatPasscode.
  ///
  /// In en, this message translates to:
  /// **'Device passcode not set'**
  String get threatPasscode;

  /// No description provided for @threatSecureHardware.
  ///
  /// In en, this message translates to:
  /// **'Secure hardware not available'**
  String get threatSecureHardware;

  /// No description provided for @threatDeveloperMode.
  ///
  /// In en, this message translates to:
  /// **'Developer mode enabled'**
  String get threatDeveloperMode;

  /// No description provided for @threatAdbEnabled.
  ///
  /// In en, this message translates to:
  /// **'ADB debugging enabled'**
  String get threatAdbEnabled;

  /// No description provided for @threatMultiInstance.
  ///
  /// In en, this message translates to:
  /// **'Multiple app instances detected'**
  String get threatMultiInstance;

  /// No description provided for @failureJailbreak.
  ///
  /// In en, this message translates to:
  /// **'Security Warning: Jailbreak detected - app may have limited functionality'**
  String get failureJailbreak;

  /// No description provided for @failureTampering.
  ///
  /// In en, this message translates to:
  /// **'Security Error: App tampering detected - please reinstall from official source'**
  String get failureTampering;

  /// No description provided for @failureThreat.
  ///
  /// In en, this message translates to:
  /// **'Security threat detected: {threatType} - {message}'**
  String failureThreat(String threatType, String message);

  /// No description provided for @failureInitialization.
  ///
  /// In en, this message translates to:
  /// **'Initialization Error: {error}'**
  String failureInitialization(String error);

  /// No description provided for @securityAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'Security Alert'**
  String get securityAlertTitle;

  /// No description provided for @securityIssuesDetected.
  ///
  /// In en, this message translates to:
  /// **'Security issues detected:'**
  String get securityIssuesDetected;

  /// No description provided for @securityThreatItem.
  ///
  /// In en, this message translates to:
  /// **'• {threat}'**
  String securityThreatItem(String threat);

  /// No description provided for @securityFunctionalityLimited.
  ///
  /// In en, this message translates to:
  /// **'App functionality may be limited.'**
  String get securityFunctionalityLimited;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @fieldKey.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get fieldKey;

  /// No description provided for @fieldValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get fieldValue;

  /// No description provided for @fieldFileKey.
  ///
  /// In en, this message translates to:
  /// **'File Key'**
  String get fieldFileKey;

  /// No description provided for @selectFromKeys.
  ///
  /// In en, this message translates to:
  /// **'Select from available keys'**
  String get selectFromKeys;

  /// No description provided for @noKeysAvailable.
  ///
  /// In en, this message translates to:
  /// **'No keys available'**
  String get noKeysAvailable;

  /// No description provided for @noKeysStored.
  ///
  /// In en, this message translates to:
  /// **'No keys stored yet'**
  String get noKeysStored;

  /// No description provided for @orSeparator.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orSeparator;

  /// No description provided for @enterKeyAndValue.
  ///
  /// In en, this message translates to:
  /// **'Enter Key and Value'**
  String get enterKeyAndValue;

  /// No description provided for @enterKeyToRetrieve.
  ///
  /// In en, this message translates to:
  /// **'Enter Key to Retrieve'**
  String get enterKeyToRetrieve;

  /// No description provided for @enterFileKey.
  ///
  /// In en, this message translates to:
  /// **'Enter File Key'**
  String get enterFileKey;

  /// No description provided for @enterFileKeyToRetrieve.
  ///
  /// In en, this message translates to:
  /// **'Enter File Key to Retrieve'**
  String get enterFileKeyToRetrieve;

  /// No description provided for @enterKeyToDelete.
  ///
  /// In en, this message translates to:
  /// **'Enter Key to Delete'**
  String get enterKeyToDelete;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @valueSaved.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, secure{Secure} other{Normal}} value saved successfully!'**
  String valueSaved(String kind);

  /// No description provided for @saveError.
  ///
  /// In en, this message translates to:
  /// **'Save Error: {error}'**
  String saveError(String error);

  /// No description provided for @getError.
  ///
  /// In en, this message translates to:
  /// **'Get Error: {error}'**
  String getError(String error);

  /// No description provided for @fileSaveError.
  ///
  /// In en, this message translates to:
  /// **'File Save Error: {error}'**
  String fileSaveError(String error);

  /// No description provided for @fileGetError.
  ///
  /// In en, this message translates to:
  /// **'File Get Error: {error}'**
  String fileGetError(String error);

  /// No description provided for @deleteError.
  ///
  /// In en, this message translates to:
  /// **'Delete Error: {error}'**
  String deleteError(String error);

  /// No description provided for @clearError.
  ///
  /// In en, this message translates to:
  /// **'Clear Error: {error}'**
  String clearError(String error);

  /// No description provided for @storageLocationError.
  ///
  /// In en, this message translates to:
  /// **'Error getting storage location: {error}'**
  String storageLocationError(String error);

  /// No description provided for @valueFound.
  ///
  /// In en, this message translates to:
  /// **'Value: {value}'**
  String valueFound(String value);

  /// No description provided for @keyNotFound.
  ///
  /// In en, this message translates to:
  /// **'Key not found'**
  String get keyNotFound;

  /// No description provided for @openingFilePicker.
  ///
  /// In en, this message translates to:
  /// **'Opening file picker...'**
  String get openingFilePicker;

  /// No description provided for @noFileSelected.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get noFileSelected;

  /// No description provided for @readingFile.
  ///
  /// In en, this message translates to:
  /// **'Reading file...'**
  String get readingFile;

  /// No description provided for @savingFile.
  ///
  /// In en, this message translates to:
  /// **'Saving file...'**
  String get savingFile;

  /// No description provided for @fileSaved.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, secure{Secure} other{Normal}} file \"{fileName}\" saved with key \"{key}\"!'**
  String fileSaved(String kind, String fileName, String key);

  /// No description provided for @fileContent.
  ///
  /// In en, this message translates to:
  /// **'File content: {content}'**
  String fileContent(String content);

  /// No description provided for @fileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get fileNotFound;

  /// No description provided for @valueDeleted.
  ///
  /// In en, this message translates to:
  /// **'Value deleted successfully!'**
  String get valueDeleted;

  /// No description provided for @secureCleared.
  ///
  /// In en, this message translates to:
  /// **'Secure storage cleared successfully!'**
  String get secureCleared;

  /// No description provided for @normalCleared.
  ///
  /// In en, this message translates to:
  /// **'Normal storage cleared successfully!'**
  String get normalCleared;

  /// No description provided for @storageLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage Location'**
  String get storageLocationTitle;

  /// No description provided for @pathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied to clipboard!'**
  String get pathCopied;

  /// No description provided for @copyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy Path'**
  String get copyPath;

  /// No description provided for @storageSupportDirectoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Application Support Directory'**
  String get storageSupportDirectoryLabel;

  /// No description provided for @storageKeyFileLabel.
  ///
  /// In en, this message translates to:
  /// **'Encrypted Key File'**
  String get storageKeyFileLabel;

  /// No description provided for @storageKeyFileFound.
  ///
  /// In en, this message translates to:
  /// **'Key file found'**
  String get storageKeyFileFound;

  /// No description provided for @storageKeyFileMissing.
  ///
  /// In en, this message translates to:
  /// **'Key file not found'**
  String get storageKeyFileMissing;

  /// No description provided for @storageViewHeading.
  ///
  /// In en, this message translates to:
  /// **'To view it in File Explorer:'**
  String get storageViewHeading;

  /// No description provided for @storageViewStepRun.
  ///
  /// In en, this message translates to:
  /// **'Press Win+R.'**
  String get storageViewStepRun;

  /// No description provided for @storageViewStepPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste the Application Support Directory path.'**
  String get storageViewStepPaste;

  /// No description provided for @storageViewStepLook.
  ///
  /// In en, this message translates to:
  /// **'Look for flutter_secure_storage.dat.'**
  String get storageViewStepLook;

  /// No description provided for @storageKeyFileEncrypted.
  ///
  /// In en, this message translates to:
  /// **'This file holds your encryption key, encrypted with Windows DPAPI.'**
  String get storageKeyFileEncrypted;

  /// No description provided for @storageKeyFileKeyName.
  ///
  /// In en, this message translates to:
  /// **'The key \'\'hive_encryption_key\'\' is stored inside this file.'**
  String get storageKeyFileKeyName;

  /// No description provided for @storageKeyFileCreatedLater.
  ///
  /// In en, this message translates to:
  /// **'The file is created when you first save secure data.'**
  String get storageKeyFileCreatedLater;

  /// No description provided for @storageKeyFileSaveFirst.
  ///
  /// In en, this message translates to:
  /// **'Try saving a secure value first.'**
  String get storageKeyFileSaveFirst;

  /// No description provided for @saveSecure.
  ///
  /// In en, this message translates to:
  /// **'Save Secure'**
  String get saveSecure;

  /// No description provided for @saveNormal.
  ///
  /// In en, this message translates to:
  /// **'Save Normal'**
  String get saveNormal;

  /// No description provided for @getAuto.
  ///
  /// In en, this message translates to:
  /// **'Get (Auto-detect)'**
  String get getAuto;

  /// No description provided for @getSecure.
  ///
  /// In en, this message translates to:
  /// **'Get Secure'**
  String get getSecure;

  /// No description provided for @getNormal.
  ///
  /// In en, this message translates to:
  /// **'Get Normal'**
  String get getNormal;

  /// No description provided for @saveSecureFile.
  ///
  /// In en, this message translates to:
  /// **'Save Secure File'**
  String get saveSecureFile;

  /// No description provided for @saveNormalFile.
  ///
  /// In en, this message translates to:
  /// **'Save Normal File'**
  String get saveNormalFile;

  /// No description provided for @getFile.
  ///
  /// In en, this message translates to:
  /// **'Get File'**
  String get getFile;

  /// No description provided for @getSecureFile.
  ///
  /// In en, this message translates to:
  /// **'Get Secure File'**
  String get getSecureFile;

  /// No description provided for @getNormalFile.
  ///
  /// In en, this message translates to:
  /// **'Get Normal File'**
  String get getNormalFile;

  /// No description provided for @deleteValue.
  ///
  /// In en, this message translates to:
  /// **'Delete Value'**
  String get deleteValue;

  /// No description provided for @clearSecureStorage.
  ///
  /// In en, this message translates to:
  /// **'Clear Secure Storage'**
  String get clearSecureStorage;

  /// No description provided for @clearNormalStorage.
  ///
  /// In en, this message translates to:
  /// **'Clear Normal Storage'**
  String get clearNormalStorage;

  /// No description provided for @showStorageLocation.
  ///
  /// In en, this message translates to:
  /// **'🔍 Show Storage Location'**
  String get showStorageLocation;

  /// No description provided for @sectionKeyValue.
  ///
  /// In en, this message translates to:
  /// **'Key-Value Storage:'**
  String get sectionKeyValue;

  /// No description provided for @sectionFile.
  ///
  /// In en, this message translates to:
  /// **'File Storage:'**
  String get sectionFile;

  /// No description provided for @sectionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete:'**
  String get sectionDelete;

  /// No description provided for @sectionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear Storage:'**
  String get sectionClear;

  /// No description provided for @sectionDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug:'**
  String get sectionDebug;

  /// No description provided for @sectionAvailableKeys.
  ///
  /// In en, this message translates to:
  /// **'Available Keys:'**
  String get sectionAvailableKeys;

  /// No description provided for @sectionCurrentFileKey.
  ///
  /// In en, this message translates to:
  /// **'Current File Key:'**
  String get sectionCurrentFileKey;

  /// No description provided for @initializingStorage.
  ///
  /// In en, this message translates to:
  /// **'Initializing storage...'**
  String get initializingStorage;

  /// No description provided for @availableKeyItem.
  ///
  /// In en, this message translates to:
  /// **'• {key}'**
  String availableKeyItem(String key);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
