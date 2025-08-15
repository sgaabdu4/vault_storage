import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/errors/errors.dart';

import '../test_context.dart';

void main() {
  group('VaultStorageImpl.keys()', () {
    late TestContext testContext;

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
    });

    tearDown(() {
      testContext.tearDownCommon();
    });

    test('returns unique, sorted keys from all boxes by default', () async {
      // Arrange
      when(() => testContext.mockNormalBox.keys).thenReturn(<Object>['a', 'b']);
      when(() => testContext.mockSecureBox.keys).thenReturn(<Object>['b', 's1']);
      when(() => testContext.mockNormalFilesBox.keys).thenReturn(<Object>['f1', 'a']);
      when(() => testContext.mockSecureFilesBox.keys).thenReturn(<Object>['fs1', 's1']);

      // Act
      final result = await testContext.vaultStorage.keys();

      // Assert
      expect(result, equals(['a', 'b', 'f1', 'fs1', 's1']));
    });

    test('respects includeFiles=false (key-value only)', () async {
      // Arrange
      when(() => testContext.mockNormalBox.keys).thenReturn(<Object>['a', 'b']);
      when(() => testContext.mockSecureBox.keys).thenReturn(<Object>['b', 's1']);

      // Act
      final result = await testContext.vaultStorage.keys(includeFiles: false);

      // Assert
      expect(result, equals(['a', 'b', 's1']));
    });

    test('filters secure-only when isSecure=true', () async {
      // Arrange
      when(() => testContext.mockSecureBox.keys).thenReturn(<Object>['s1', 's2']);
      when(() => testContext.mockSecureFilesBox.keys).thenReturn(<Object>['fs1']);

      // Act
      final result = await testContext.vaultStorage.keys(isSecure: true);

      // Assert
      expect(result, equals(['fs1', 's1', 's2']));
    });

    test('filters normal-only when isSecure=false', () async {
      // Arrange
      when(() => testContext.mockNormalBox.keys).thenReturn(<Object>['a', 'b']);
      when(() => testContext.mockNormalFilesBox.keys).thenReturn(<Object>['f1']);

      // Act
      final result = await testContext.vaultStorage.keys(isSecure: false);

      // Assert
      expect(result, equals(['a', 'b', 'f1']));
    });

    test('throws when not initialised', () async {
      // Arrange
      testContext.vaultStorage.isVaultStorageReady = false;

      // Act & Assert
      expect(() => testContext.vaultStorage.keys(), throwsA(isA<StorageInitializationError>()));
    });
  });
}
