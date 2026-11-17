/// Keys and labels the vault writes next to stored file content.
abstract final class StoredFileKeys {
  static const isSecure = 'isSecure';
  static const userMetadata = 'userMetadata';
  static const base64Data = 'base64Data';
  static const isCustomBox = 'isCustomBox';
  static const defaultExtension = 'bin';
  static const extensionSeparator = '.';
  static const normalLocation = 'normal';
  static const secureLocation = 'secure';
  static const normalFilesLocation = 'normal_files';
  static const secureFilesLocation = 'secure_files';
  static const disambiguationHint = 'Specify the box parameter to disambiguate.';
}
