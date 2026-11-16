/// Global configuration for Vault Storage performance tuning.
abstract final class VaultStorageConfig {
  /// JSON string length above which decoding runs in an isolate.
  static int jsonIsolateThreshold = 10000;

  /// Longest String primitive stored with a light-weight marker instead of JSON.
  static int primitiveStringThreshold = 1000;

  /// Payload size above which base64 encode and decode run in an isolate.
  static int base64IsolateThreshold = 50000;

  /// Secure file size in bytes above which saving uses streaming encryption.
  static int secureFileStreamingThresholdBytes = 2 * 1024 * 1024;

  /// Default chunk size for streaming secure file encryption.
  static int secureFileStreamingChunkSizeBytes = 2 * 1024 * 1024;
}
