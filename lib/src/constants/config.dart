/// Global configuration for Vault Storage performance tuning.
///
/// Exposes thresholds that control when to offload JSON/base64 work to
/// background isolates to keep the UI responsive. You can tweak these based
/// on your app's workload at startup.
class VaultStorageConfig {
  VaultStorageConfig._();

  /// If a JSON string length exceeds this number of characters, decoding
  /// will run in an isolate. Default: 10k.
  static int jsonIsolateThreshold = 10000;

  /// If a String primitive is shorter than or equal to this length, it's
  /// stored with a light-weight marker rather than JSON encoding.
  /// Default: 1k.
  static int primitiveStringThreshold = 1000;

  /// If a binary payload (or base64 string) exceeds this many bytes/characters,
  /// base64 encode/decode will run in an isolate. Default: 50k.
  static int base64IsolateThreshold = 50000;

  /// If a secure file is larger than this many bytes, use internal streaming
  /// encryption for saving to reduce peak memory. Set to 0 to always stream,
  /// or a very large number to disable streaming. Default: 2MB.
  static int secureFileStreamingThresholdBytes = 2 * 1024 * 1024;

  /// Default chunk size for streaming secure file encryption.
  static int secureFileStreamingChunkSizeBytes = 2 * 1024 * 1024;
}
