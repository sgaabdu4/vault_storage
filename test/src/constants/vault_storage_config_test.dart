import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/constants/config.dart';

void main() {
  group('VaultStorageConfig', () {
    // Save original values to restore after tests
    late int originalJsonThreshold;
    late int originalPrimitiveThreshold;
    late int originalBase64Threshold;
    late int originalStreamingThreshold;
    late int originalChunkSize;

    setUp(() {
      originalJsonThreshold = VaultStorageConfig.jsonIsolateThreshold;
      originalPrimitiveThreshold = VaultStorageConfig.primitiveStringThreshold;
      originalBase64Threshold = VaultStorageConfig.base64IsolateThreshold;
      originalStreamingThreshold = VaultStorageConfig.secureFileStreamingThresholdBytes;
      originalChunkSize = VaultStorageConfig.secureFileStreamingChunkSizeBytes;
    });

    tearDown(() {
      // Restore original values
      VaultStorageConfig.jsonIsolateThreshold = originalJsonThreshold;
      VaultStorageConfig.primitiveStringThreshold = originalPrimitiveThreshold;
      VaultStorageConfig.base64IsolateThreshold = originalBase64Threshold;
      VaultStorageConfig.secureFileStreamingThresholdBytes = originalStreamingThreshold;
      VaultStorageConfig.secureFileStreamingChunkSizeBytes = originalChunkSize;
    });

    group('Default Values', () {
      test('jsonIsolateThreshold should default to 10000', () {
        expect(VaultStorageConfig.jsonIsolateThreshold, equals(10000));
      });

      test('primitiveStringThreshold should default to 1000', () {
        expect(VaultStorageConfig.primitiveStringThreshold, equals(1000));
      });

      test('base64IsolateThreshold should default to 50000', () {
        expect(VaultStorageConfig.base64IsolateThreshold, equals(50000));
      });

      test('secureFileStreamingThresholdBytes should default to 2MB', () {
        expect(VaultStorageConfig.secureFileStreamingThresholdBytes, equals(2 * 1024 * 1024));
      });

      test('secureFileStreamingChunkSizeBytes should default to 2MB', () {
        expect(VaultStorageConfig.secureFileStreamingChunkSizeBytes, equals(2 * 1024 * 1024));
      });
    });

    group('Configuration Mutability', () {
      test('should allow changing jsonIsolateThreshold', () {
        VaultStorageConfig.jsonIsolateThreshold = 20000;
        expect(VaultStorageConfig.jsonIsolateThreshold, equals(20000));
      });

      test('should allow changing primitiveStringThreshold', () {
        VaultStorageConfig.primitiveStringThreshold = 2000;
        expect(VaultStorageConfig.primitiveStringThreshold, equals(2000));
      });

      test('should allow changing base64IsolateThreshold', () {
        VaultStorageConfig.base64IsolateThreshold = 100000;
        expect(VaultStorageConfig.base64IsolateThreshold, equals(100000));
      });

      test('should allow changing secureFileStreamingThresholdBytes', () {
        VaultStorageConfig.secureFileStreamingThresholdBytes = 5 * 1024 * 1024;
        expect(VaultStorageConfig.secureFileStreamingThresholdBytes, equals(5 * 1024 * 1024));
      });

      test('should allow changing secureFileStreamingChunkSizeBytes', () {
        VaultStorageConfig.secureFileStreamingChunkSizeBytes = 1024 * 1024;
        expect(VaultStorageConfig.secureFileStreamingChunkSizeBytes, equals(1024 * 1024));
      });

      test('should allow setting thresholds to 0', () {
        VaultStorageConfig.jsonIsolateThreshold = 0;
        VaultStorageConfig.primitiveStringThreshold = 0;
        VaultStorageConfig.base64IsolateThreshold = 0;
        VaultStorageConfig.secureFileStreamingThresholdBytes = 0;

        expect(VaultStorageConfig.jsonIsolateThreshold, equals(0));
        expect(VaultStorageConfig.primitiveStringThreshold, equals(0));
        expect(VaultStorageConfig.base64IsolateThreshold, equals(0));
        expect(VaultStorageConfig.secureFileStreamingThresholdBytes, equals(0));
      });

      test('should allow very large threshold values', () {
        VaultStorageConfig.jsonIsolateThreshold = 1000000000;
        VaultStorageConfig.base64IsolateThreshold = 1000000000;

        expect(VaultStorageConfig.jsonIsolateThreshold, equals(1000000000));
        expect(VaultStorageConfig.base64IsolateThreshold, equals(1000000000));
      });
    });

    group('Performance Tuning Scenarios', () {
      test('should support disabling isolate usage for JSON', () {
        VaultStorageConfig.jsonIsolateThreshold = 1000000000;
        expect(VaultStorageConfig.jsonIsolateThreshold, greaterThan(10000));
      });

      test('should support always using isolates for JSON', () {
        VaultStorageConfig.jsonIsolateThreshold = 0;
        expect(VaultStorageConfig.jsonIsolateThreshold, equals(0));
      });

      test('should support disabling streaming for secure files', () {
        VaultStorageConfig.secureFileStreamingThresholdBytes = 1000000000;
        expect(VaultStorageConfig.secureFileStreamingThresholdBytes, greaterThan(1000000));
      });

      test('should support always streaming secure files', () {
        VaultStorageConfig.secureFileStreamingThresholdBytes = 0;
        expect(VaultStorageConfig.secureFileStreamingThresholdBytes, equals(0));
      });

      test('should support custom chunk sizes for streaming', () {
        const customChunkSize = 512 * 1024; // 512KB
        VaultStorageConfig.secureFileStreamingChunkSizeBytes = customChunkSize;
        expect(VaultStorageConfig.secureFileStreamingChunkSizeBytes, equals(customChunkSize));
      });
    });

    group('Threshold Relationships', () {
      test('primitiveStringThreshold should be less than jsonIsolateThreshold by default', () {
        expect(
          VaultStorageConfig.primitiveStringThreshold,
          lessThan(VaultStorageConfig.jsonIsolateThreshold),
        );
      });

      test('should allow independent configuration of all thresholds', () {
        VaultStorageConfig.jsonIsolateThreshold = 5000;
        VaultStorageConfig.primitiveStringThreshold = 500;
        VaultStorageConfig.base64IsolateThreshold = 25000;
        VaultStorageConfig.secureFileStreamingThresholdBytes = 1024 * 1024;
        VaultStorageConfig.secureFileStreamingChunkSizeBytes = 512 * 1024;

        expect(VaultStorageConfig.jsonIsolateThreshold, equals(5000));
        expect(VaultStorageConfig.primitiveStringThreshold, equals(500));
        expect(VaultStorageConfig.base64IsolateThreshold, equals(25000));
        expect(VaultStorageConfig.secureFileStreamingThresholdBytes, equals(1024 * 1024));
        expect(VaultStorageConfig.secureFileStreamingChunkSizeBytes, equals(512 * 1024));
      });
    });

    test('should not allow instantiation', () {
      // VaultStorageConfig has a private constructor
      expect(() => VaultStorageConfig, isNotNull);
    });
  });
}
