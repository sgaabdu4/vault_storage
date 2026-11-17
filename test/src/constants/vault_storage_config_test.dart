import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/constants/vault_storage_config.dart';

void main() {
  group('VaultStorageConfig', () {
    test('uses the documented defaults', () {
      const config = VaultStorageConfig();

      expect(config.jsonIsolateThreshold, 10000);
      expect(config.primitiveStringThreshold, 1000);
      expect(config.base64IsolateThreshold, 50000);
      expect(config.secureFileStreamingThresholdBytes, 2 * 1024 * 1024);
      expect(config.secureFileStreamingChunkSizeBytes, 2 * 1024 * 1024);
    });

    test('keeps every custom value', () {
      const config = VaultStorageConfig(
        jsonIsolateThreshold: 5000,
        primitiveStringThreshold: 500,
        base64IsolateThreshold: 25000,
        secureFileStreamingThresholdBytes: 1024 * 1024,
        secureFileStreamingChunkSizeBytes: 512 * 1024,
      );

      expect(config.jsonIsolateThreshold, 5000);
      expect(config.primitiveStringThreshold, 500);
      expect(config.base64IsolateThreshold, 25000);
      expect(config.secureFileStreamingThresholdBytes, 1024 * 1024);
      expect(config.secureFileStreamingChunkSizeBytes, 512 * 1024);
    });

    test('changing one value leaves the other defaults', () {
      const config = VaultStorageConfig(secureFileStreamingThresholdBytes: 1);

      expect(config.secureFileStreamingThresholdBytes, 1);
      expect(config.jsonIsolateThreshold, 10000);
      expect(config.secureFileStreamingChunkSizeBytes, 2 * 1024 * 1024);
    });

    test('instances do not share state', () {
      const first = VaultStorageConfig(jsonIsolateThreshold: 1);
      const second = VaultStorageConfig();

      expect(first.jsonIsolateThreshold, 1);
      expect(second.jsonIsolateThreshold, 10000);
    });
  });
}
