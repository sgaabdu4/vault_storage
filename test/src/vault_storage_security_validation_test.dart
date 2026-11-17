import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/entities/box_config.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/security/security_exceptions.dart';
import 'package:vault_storage/src/security/vault_security_config.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

import '../mocks.dart';
import '../test_context.dart';

VaultStorageImpl _storageWithSecurity(TestContext testContext, VaultSecurityConfig config) {
  final storage = testContext.createStorage(securityConfig: config);
  storage.boxes.addAll(testContext.vaultStorage.boxes);
  storage.isVaultStorageReady = true;
  return storage;
}

void main() {
  group('Security Environment Validation', () {
    late TestContext testContext;

    setUpAll(() {
      MocksHelper.registerFallbackValues();
    });

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      testContext.tearDownCommon();
    });

    group('clearSecure blocks on insecure environment', () {
      test('should throw SecurityThreatException when blockOnJailbreak is true', () {
        debugDefaultTargetPlatformOverride = .android;

        final storage = _storageWithSecurity(testContext, const VaultSecurityConfig());
        storage.isSecureEnvironment = false;

        expect(() => storage.clearSecure(), throwsA(isA<SecurityThreatException>()));
      });

      test('should throw SecurityThreatException when blockOnDebug is true', () {
        debugDefaultTargetPlatformOverride = .android;

        final storage = _storageWithSecurity(
          testContext,
          const VaultSecurityConfig(
            blockOnJailbreak: false,
            blockOnTampering: false,
            blockOnHooks: false,
            blockOnDebug: true,
          ),
        );
        storage.isSecureEnvironment = false;

        expect(() => storage.clearSecure(), throwsA(isA<SecurityThreatException>()));
      });

      test('should throw SecurityThreatException when blockOnEmulator is true', () {
        debugDefaultTargetPlatformOverride = .iOS;

        final storage = _storageWithSecurity(
          testContext,
          const VaultSecurityConfig(
            blockOnJailbreak: false,
            blockOnTampering: false,
            blockOnHooks: false,
            blockOnEmulator: true,
          ),
        );
        storage.isSecureEnvironment = false;

        expect(() => storage.clearSecure(), throwsA(isA<SecurityThreatException>()));
      });

      test('should proceed when no blocking flags are set', () async {
        debugDefaultTargetPlatformOverride = .android;

        final storage = _storageWithSecurity(
          testContext,
          const VaultSecurityConfig(
            blockOnJailbreak: false,
            blockOnTampering: false,
            blockOnHooks: false,
          ),
        );
        storage.isSecureEnvironment = false;

        when(() => testContext.mockSecureBox.clear()).thenAnswer((_) async => 0);

        // Should NOT throw despite insecure environment
        await storage.clearSecure();

        verify(() => testContext.mockSecureBox.clear()).called(1);
      });
    });

    group('clearAll blocks on insecure environment', () {
      test('should throw SecurityThreatException when blockOnTampering is true', () {
        debugDefaultTargetPlatformOverride = .android;

        final storage = _storageWithSecurity(testContext, const VaultSecurityConfig());
        storage.isSecureEnvironment = false;

        expect(() => storage.clearAll(), throwsA(isA<SecurityThreatException>()));
      });

      test('should throw SecurityThreatException when blockOnHooks is true', () {
        debugDefaultTargetPlatformOverride = .iOS;

        final storage = _storageWithSecurity(
          testContext,
          const VaultSecurityConfig(blockOnJailbreak: false, blockOnTampering: false),
        );
        storage.isSecureEnvironment = false;

        expect(() => storage.clearAll(), throwsA(isA<SecurityThreatException>()));
      });
    });

    group('saveSecure blocks on insecure environment', () {
      test('should throw SecurityThreatException when blockOnUnofficialStore is true', () {
        debugDefaultTargetPlatformOverride = .android;

        final storage = _storageWithSecurity(
          testContext,
          const VaultSecurityConfig(
            blockOnJailbreak: false,
            blockOnTampering: false,
            blockOnHooks: false,
            blockOnUnofficialStore: true,
          ),
        );
        storage.isSecureEnvironment = false;

        expect(
          () => storage.saveSecure(key: 'test', value: 'value'),
          throwsA(isA<SecurityThreatException>()),
        );
      });
    });

    group('saveSecureFile blocks on insecure environment', () {
      test('should throw SecurityThreatException when environment insecure', () {
        debugDefaultTargetPlatformOverride = .android;

        final storage = _storageWithSecurity(testContext, const VaultSecurityConfig());
        storage.isSecureEnvironment = false;

        expect(
          () => storage.saveSecureFile(key: 'file', fileBytes: .fromList([1, 2, 3])),
          throwsA(isA<SecurityThreatException>()),
        );
      });
    });

    group('security validation skipped appropriately', () {
      test('should skip validation when no security config provided', () async {
        // Use TestContext's default storage (no security config)
        testContext.vaultStorage.isSecureEnvironment = false;

        when(() => testContext.mockSecureBox.clear()).thenAnswer((_) async => 0);

        // Should NOT throw
        await testContext.vaultStorage.clearSecure();

        verify(() => testContext.mockSecureBox.clear()).called(1);
      });

      test('should skip validation on non-mobile platforms', () async {
        // Tests run on macOS by default, so _isSecuritySupportedOnCurrentPlatform = false
        debugDefaultTargetPlatformOverride = .macOS;

        final storage = _storageWithSecurity(testContext, const VaultSecurityConfig());
        storage.isSecureEnvironment = false;

        when(() => testContext.mockSecureBox.clear()).thenAnswer((_) async => 0);

        // Should NOT throw on macOS
        await storage.clearSecure();

        verify(() => testContext.mockSecureBox.clear()).called(1);
      });

      test('should skip validation when environment is secure', () async {
        debugDefaultTargetPlatformOverride = .android;

        final storage = _storageWithSecurity(testContext, const VaultSecurityConfig());
        storage.isSecureEnvironment = true; // Secure environment

        when(() => testContext.mockSecureBox.clear()).thenAnswer((_) async => 0);

        // Should NOT throw when environment IS secure
        await storage.clearSecure();

        verify(() => testContext.mockSecureBox.clear()).called(1);
      });
    });
  });

  group('init() error propagation', () {
    late TestContext testContext;

    setUpAll(() {
      MocksHelper.registerFallbackValues();
    });

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
    });

    tearDown(() {
      testContext.tearDownCommon();
    });

    test('should rethrow VaultStorageInitializationError without wrapping', () async {
      final storage = testContext.createStorage();

      // Make getOrCreateSecureKey throw VaultStorageInitializationError
      when(
        () => testContext.mockSecureStorage.read(key: any(named: 'key')),
      ).thenThrow(const VaultStorageInitializationError('Key storage failure'));

      try {
        await storage.init();
        fail('Expected VaultStorageInitializationError');
      } on VaultStorageInitializationError catch (e) {
        // Should be the original error, not double-wrapped
        expect(e.message, equals('Failed to get/create secure key'));
        // originalException should be the actual exception, not another VaultStorageInitializationError
        expect(e.originalException, isA<VaultStorageInitializationError>());
      }
    });

    test('should wrap non-VaultStorageError in VaultStorageInitializationError', () async {
      final storage = testContext.createStorage();

      // Make getOrCreateSecureKey throw a generic exception
      when(
        () => testContext.mockSecureStorage.read(key: any(named: 'key')),
      ).thenThrow(Exception('Generic failure'));

      try {
        await storage.init();
        fail('Expected VaultStorageInitializationError');
      } on VaultStorageInitializationError catch (e) {
        expect(e.message, equals('Failed to get/create secure key'));
      }
    });
  });

  group('Custom box duplicate name detection', () {
    test('should throw VaultStorageInitializationError for duplicate box names', () {
      expect(
        () => VaultStorageImpl.validateCustomBoxConfigs(const [
          BoxConfig(name: 'my_box'),
          BoxConfig(name: 'my_box', encrypted: true),
        ]),
        throwsA(
          isA<VaultStorageInitializationError>().having(
            (e) => e.message,
            'message',
            allOf(contains('Duplicate custom box name'), contains('my_box')),
          ),
        ),
      );
    });

    test('should throw VaultStorageInitializationError for reserved box names', () {
      expect(
        () => VaultStorageImpl.validateCustomBoxConfigs(const [BoxConfig(name: 'secure_box')]),
        throwsA(
          isA<VaultStorageInitializationError>().having(
            (e) => e.message,
            'message',
            contains('conflicts with a reserved box name'),
          ),
        ),
      );
    });

    test('should accept valid unique non-reserved box names', () {
      expect(
        () => VaultStorageImpl.validateCustomBoxConfigs(const [
          BoxConfig(name: 'tenant_a'),
          BoxConfig(name: 'tenant_b', encrypted: true),
          BoxConfig(name: 'cache', lazy: true),
        ]),
        returnsNormally,
      );
    });
  });

  group('VaultStorageError toString', () {
    test('should format error with message only', () {
      const error = VaultStorageReadError('Test message');
      expect(error.toString(), equals('VaultStorageReadError: Test message'));
    });

    test('should format error with message and original exception', () {
      const error = VaultStorageReadError('Test message', 'original cause');
      expect(
        error.toString(),
        equals('VaultStorageReadError: Test message (caused by: original cause)'),
      );
    });

    test('should format VaultStorageInitializationError', () {
      const error = VaultStorageInitializationError('Init failed', 'root cause');
      expect(
        error.toString(),
        equals('VaultStorageInitializationError: Init failed (caused by: root cause)'),
      );
    });

    test('should format error without original exception showing null', () {
      const error = VaultStorageDeleteError('Delete failed');
      expect(error.toString(), equals('VaultStorageDeleteError: Delete failed'));
      expect(error.originalException, isNull);
    });
  });

  group('clearAll clears custom boxes', () {
    late TestContext testContext;

    setUpAll(() {
      MocksHelper.registerFallbackValues();
    });

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
    });

    tearDown(() {
      testContext.tearDownCommon();
    });

    test('should clear custom boxes during clearAll', () async {
      final mockCustomBox = MockBox<Object?>();
      testContext.vaultStorage.customBoxes['tenant_1'] = mockCustomBox;

      when(() => testContext.mockNormalBox.clear()).thenAnswer((_) async => 0);
      when(() => testContext.mockSecureBox.clear()).thenAnswer((_) async => 0);
      when(() => testContext.mockNormalFilesBox.keys).thenReturn([]);
      when(() => testContext.mockNormalFilesBox.clear()).thenAnswer((_) async => 0);
      when(() => testContext.mockSecureFilesBox.keys).thenReturn([]);
      when(() => testContext.mockSecureFilesBox.clear()).thenAnswer((_) async => 0);
      when(() => mockCustomBox.clear()).thenAnswer((_) async => 0);
      when(
        () => testContext.mockSecureStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await testContext.vaultStorage.clearAll();

      verify(() => mockCustomBox.clear()).called(1);
    });

    test('should clear multiple custom boxes during clearAll', () async {
      final mockBox1 = MockBox<Object?>();
      final mockBox2 = MockBox<Object?>();
      testContext.vaultStorage.customBoxes['box_a'] = mockBox1;
      testContext.vaultStorage.customBoxes['box_b'] = mockBox2;

      when(() => testContext.mockNormalBox.clear()).thenAnswer((_) async => 0);
      when(() => testContext.mockSecureBox.clear()).thenAnswer((_) async => 0);
      when(() => testContext.mockNormalFilesBox.keys).thenReturn([]);
      when(() => testContext.mockNormalFilesBox.clear()).thenAnswer((_) async => 0);
      when(() => testContext.mockSecureFilesBox.keys).thenReturn([]);
      when(() => testContext.mockSecureFilesBox.clear()).thenAnswer((_) async => 0);
      when(() => mockBox1.clear()).thenAnswer((_) async => 0);
      when(() => mockBox2.clear()).thenAnswer((_) async => 0);
      when(
        () => testContext.mockSecureStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await testContext.vaultStorage.clearAll();

      verify(() => mockBox1.clear()).called(1);
      verify(() => mockBox2.clear()).called(1);
    });

    test('should clear custom boxes even when includeFiles is false', () async {
      final mockCustomBox = MockBox<Object?>();
      testContext.vaultStorage.customBoxes['tenant_1'] = mockCustomBox;

      when(() => testContext.mockNormalBox.clear()).thenAnswer((_) async => 0);
      when(() => testContext.mockSecureBox.clear()).thenAnswer((_) async => 0);
      when(() => mockCustomBox.clear()).thenAnswer((_) async => 0);

      await testContext.vaultStorage.clearAll(includeFiles: false);

      verify(() => mockCustomBox.clear()).called(1);
    });
  });

  group('dispose resets state', () {
    late TestContext testContext;

    setUpAll(() {
      MocksHelper.registerFallbackValues();
    });

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
    });

    tearDown(() {
      testContext.tearDownCommon();
    });

    test('should reset isSecureEnvironment to true on dispose', () async {
      testContext.vaultStorage.isSecureEnvironment = false;

      when(() => testContext.mockSecureBox.close()).thenAnswer((_) async {});
      when(() => testContext.mockNormalBox.close()).thenAnswer((_) async {});
      when(() => testContext.mockSecureFilesBox.close()).thenAnswer((_) async {});
      when(() => testContext.mockNormalFilesBox.close()).thenAnswer((_) async {});

      await testContext.vaultStorage.dispose();

      expect(testContext.vaultStorage.isSecureEnvironment, isTrue);
      expect(testContext.vaultStorage.isVaultStorageReady, isFalse);
    });

    test('should close custom boxes on dispose', () async {
      final mockCustomBox = MockBox<Object?>();
      testContext.vaultStorage.customBoxes['tenant'] = mockCustomBox;

      when(() => testContext.mockSecureBox.close()).thenAnswer((_) async {});
      when(() => testContext.mockNormalBox.close()).thenAnswer((_) async {});
      when(() => testContext.mockSecureFilesBox.close()).thenAnswer((_) async {});
      when(() => testContext.mockNormalFilesBox.close()).thenAnswer((_) async {});
      when(() => mockCustomBox.close()).thenAnswer((_) async {});

      await testContext.vaultStorage.dispose();

      verify(() => mockCustomBox.close()).called(1);
      expect(testContext.vaultStorage.customBoxes, isEmpty);
    });
  });
}
