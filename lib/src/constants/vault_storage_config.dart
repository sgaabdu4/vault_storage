/// Performance tuning for one vault storage instance.
final class VaultStorageConfig {
  /// Creates a new [VaultStorageConfig].
  const VaultStorageConfig({
    this.jsonIsolateThreshold = 10000,
    this.primitiveStringThreshold = 1000,
    this.base64IsolateThreshold = 50000,
    this.secureFileStreamingThresholdBytes = 2 * 1024 * 1024,
    this.secureFileStreamingChunkSizeBytes = 2 * 1024 * 1024,
  });

  /// JSON string length above which decoding runs in an isolate.
  final int jsonIsolateThreshold;

  /// Longest String primitive stored with a light-weight marker instead of JSON.
  final int primitiveStringThreshold;

  /// Payload size above which base64 encode and decode run in an isolate.
  final int base64IsolateThreshold;

  /// Secure file size in bytes above which saving uses streaming encryption.
  final int secureFileStreamingThresholdBytes;

  /// Default chunk size for streaming secure file encryption.
  final int secureFileStreamingChunkSizeBytes;
}
