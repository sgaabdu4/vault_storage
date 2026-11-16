/// Internal enum that includes all box types including file storage boxes.
enum BoxType {
  /// For non-sensitive data like cache and user preferences.
  normal,

  /// For sensitive data like auth tokens and user credentials, stored encrypted.
  secure,

  /// For storing encrypted file data on web platforms.
  secureFiles,

  /// For storing unencrypted file data on web platforms.
  normalFiles,
}
