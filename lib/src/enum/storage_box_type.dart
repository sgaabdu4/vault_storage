/// Defines the type of Hive box to be used for a storage operation.
///
/// This enum allows for a clear distinction between storing sensitive and non-sensitive
/// data, ensuring that appropriate security measures are applied.
enum BoxType {
  /// For non-sensitive data like cache and user preferences.
  normal,

  /// For sensitive data like auth tokens and user credentials, stored encrypted.
  secure,

  /// For storing file data, such as images or documents.
  secureFiles, // WEB-COMPAT: Add this for storing file data
}
