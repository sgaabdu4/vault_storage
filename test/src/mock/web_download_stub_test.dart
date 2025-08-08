import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/mock/web_download_stub.dart';

void main() {
  group('Web Download Stub', () {
    test('downloadFileOnWeb should do nothing on non-web platforms', () {
      // Arrange
      final fileBytes = Uint8List.fromList([1, 2, 3, 4]);
      const fileName = 'test.txt';
      const mimeType = 'text/plain';

      // Act & Assert - Should complete without throwing
      expect(() {
        downloadFileOnWeb(
          fileBytes: fileBytes,
          fileName: fileName,
          mimeType: mimeType,
        );
      }, returnsNormally);
    });

    test('downloadFileOnWeb should handle minimal parameters', () {
      // Arrange
      final fileBytes = Uint8List.fromList([1, 2, 3, 4]);
      const fileName = 'test.bin';

      // Act & Assert - Should complete without throwing
      expect(() {
        downloadFileOnWeb(
          fileBytes: fileBytes,
          fileName: fileName,
        );
      }, returnsNormally);
    });
  });
}
