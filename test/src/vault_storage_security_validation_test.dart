import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/constants/config.dart';
import 'package:vault_storage/src/entities/box_config.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/security/security_exceptions.dart';
import 'package:vault_storage/src/security/vault_security_config.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

import '../mocks.dart';
import '../test_context.dart';

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

    /// Helper to create a VaultStorageImpl with security config and mock boxes.
    VaultStorageImpl createStorageWithSecurity(VaultSecurityConfig config) {
      final storage = VaultStorageImpl(
        secureStorage: testContext.mockSecureStorage,
        uuid: testContext.mockUuid,
        fileOperations: testContext.mockFileOperations,
        securityConfig: config,
      );
      storage.boxes.addAll(testContext.vaultStorage.boxes);
      storage.isVaultStorageReady = true;
      return storage;
    }

    group('clearSecure blocks on insecure environment', () {
      test('should throw SecurityThreatException when blockOnJailbreak is true', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final storage = createStorageWithSecurity(
          const VaultSecurityConfig(),
        );
        storage.isSecureEnvironment = false;

        expect(
          () => storage.clearSecure(),
          throwsA(isA<SecurityThreatException>()),
        );
      });

      test('should throw SecurityThreatException when blockOnDebug is true', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final storage = createStorageWithSecurity(
          const VaultSecurityConfig(
            blockOnJailbreak: false,
            blockOnTampering: false,
            blockOnHooks: false,
            blockOnDebug: true,
          ),
        );
        storage.isSecureEnvironment = false;

        expect(
          () => storage.clearSecure(),
          throwsA(isA<SecurityThreatException>()),
        );
      });

      test('should throw SecurityThreatException when blockOnEmulator is true', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        final storage = createStorageWithSecurity(
          const VaultSecurityConfig(
            blockOnJailbreak: false,
            blockOnTampering: false,
            blockOnHooks: false,
            blockOnEmulator: true,
          ),
        );
        storage.isSecureEnvironment = false;

        expect(
          () => storage.clearSecure(),
          throwsA(isA<SecurityThreatException>()),
        );
      });

      test('should proceed when no blocking flags are set', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final storage = createStorageWithSecurity(
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
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final storage = createStorageWithSecurity(
          const VaultSecurityConfig(),
        );
        storage.isSecureEnvironment = false;

        expect(
          () => storage.clearAll(),
          throwsA(isA<SecurityThreatException>()),
        );
      });

      test('should throw SecurityThreatException when blockOnHooks is true', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        final storage = createStorageWithSecurity(
          const VaultSecurityConfig(
            blockOnJailbreak: false,
            blockOnTampering: false,
          ),
        );
        storage.isSecureEnvironment = false;

        expect(
          () => storage.clearAll(),
          throwsA(isA<SecurityThreatException>()),
        );
      });
    });

    group('saveSecure blocks on insecure environment', () {
      test('should throw SecurityThreatException when blockOnUnofficialStore is true', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final storage = createStorageWithSecurity(
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
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final storage = createStorageWithSecurity(
          const VaultSecurityConfig(),
        );
        storage.isSecureEnvironment = false;

        expect(
          () => storage.saveSecureFile(
            key: 'file',
            fileBytes: Uint8List.fromList([1, 2, 3]),
          ),
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
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

        final storage = createStorageWithSecurity(
          const VaultSecurityConfig(),
        );
        storage.isSecureEnvironment = false;

        when(() => testContext.mockSecureBox.clear()).thenAnswer((_) async => 0);

        // Should NOT throw on macOS
        await storage.clearSecure();

        verify(() => testContext.mockSecureBox.clear()).called(1);
      });

      test('should skip validation when environment is secure', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final storage = createStorageWithSecurity(
          const VaultSecurityConfig(),
        );
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

    test('should rethrow StorageInitializationError without wrapping', () async {
      final storage = VaultStorageImpl(
        secureStorage: testContext.mockSecureStorage,
        uuid: testContext.mockUuid,
        fileOperations: testContext.mockFileOperations,
      );

      // Make getOrCreateSecureKey throw StorageInitializationError
      when(() => testContext.mockSecureStorage.read(key: any(named: 'key')))
          .thenThrow(const StorageInitializationError('Key storage failure'));

      try {
        await storage.init();
        fail('Expected StorageInitializationError');
      } on StorageInitializationError catch (e) {
        // Should be the original error, not double-wrapped
        expect(e.message, equals('Failed to get/create secure key'));
        // originalException should be the actual exception, not another StorageInitializationError
        expect(e.originalException, isA<StorageInitializationError>());
      }
    });

    test('should wrap non-StorageError in StorageInitializationError', () async {
      final storage = VaultStorageImpl(
        secureStorage: testContext.mockSecureStorage,
        uuid: testContext.mockUuid,
        fileOperations: testContext.mockFileOperations,
      );

      // Make getOrCreateSecureKey throw a generic exception
      when(() => testContext.mockSecureStorage.read(key: any(named: 'key')))
          .thenThrow(Exception('Generic failure'));

      try {
        await storage.init();
        fail('Expected StorageInitializationError');
      } on StorageInitializationError catch (e) {
        // getOrCreateSecureKey wraps this in StorageInitializationError,
        // which is then rethrown by init() without double-wrapping
        expect(e.message, equals('Failed to get/create secure key'));
      }
    });
  });

  group('Custom box duplicate name detection', () {
    test('should throw StorageInitializationError for duplicate box names', () {
      expect(
        () => VaultStorageImpl.validateCustomBoxConfigs(const [
          BoxConfig(name: 'my_box'),
          BoxConfig(name: 'my_box', encrypted: true),
        ]),
        throwsA(
          isA<StorageInitializationError>().having(
            (e) => e.message,
            'message',
            allOf(contains('Duplicate custom box name'), contains('my_box')),
          ),
        ),
      );
    });

    test('should throw StorageInitializationError for reserved box names', () {
      expect(
        () => VaultStorageImpl.validateCustomBoxConfigs(const [
          BoxConfig(name: 'secure_box'),
        ]),
        throwsA(
          isA<StorageInitializationError>().having(
            (e) => e.message,
            'message',
            contains('conflicts with a reserved box name'),
          ),
        ),
      );
    });

    test('should accept valid unique non-reserved box names', () {
      // Should not throw
      VaultStorageImpl.validateCustomBoxConfigs(const [
        BoxConfig(name: 'tenant_a'),
        BoxConfig(name: 'tenant_b', encrypted: true),
        BoxConfig(name: 'cache', lazy: true),
      ]);
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
      final mockCustomBox = MockBox<dynamic>();
      testContext.vaultStorage.customBoxes['tenant_1'] = mockCustomBox;

      when(() => testContext.mockNormalBox.clear()).thenAnswer((_) async => 0);
      when(() => testContext.mockSecureBox.clear()).thenAnswer((_) async => 0);
      when(() => testContext.mockNormalFilesBox.keys).thenReturn([]);
      when(() => testContext.mockNormalFilesBox.clear()).thenAnswer((_) async => 0);
      when(() => testContext.mockSecureFilesBox.keys).thenReturn([]);
      when(() => testContext.mockSecureFilesBox.clear()).thenAnswer((_) async => 0);
      when(() => mockCustomBox.clear()).thenAnswer((_) async => 0);
      when(() => testContext.mockSecureStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await testContext.vaultStorage.clearAll();

      verify(() => mockCustomBox.clear()).called(1);
    });

    test('should clear multiple custom boxes during clearAll', () async {
      final mockBox1 = MockBox<dynamic>();
      final mockBox2 = MockBox<dynamic>();
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
      when(() => testContext.mockSecureStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await testContext.vaultStorage.clearAll();

      verify(() => mockBox1.clear()).called(1);
      verify(() => mockBox2.clear()).called(1);
    });

    test('should clear custom boxes even when includeFiles is false', () async {
      final mockCustomBox = MockBox<dynamic>();
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
      final mockCustomBox = MockBox<dynamic>();
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

  group('init() re-entrancy', () {
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

    test('should return immediately when already initialized', () async {
      testContext.vaultStorage.isVaultStorageReady = true;

      // Should return without error
      await testContext.vaultStorage.init();

      // No interactions with secure storage (init body not executed)
      verifyNever(() => testContext.mockSecureStorage.read(key: any(named: 'key')));
    });
  });

  group('keys() includes custom box keys', () {
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

    test('should include keys from custom boxes', () async {
      final mockCustomBox = MockBox<dynamic>();
      testContext.vaultStorage.customBoxes['tenant'] = mockCustomBox;

      when(() => testContext.mockNormalBox.keys).thenReturn(['normal_key']);
      when(() => testContext.mockSecureBox.keys).thenReturn(['secure_key']);
      when(() => testContext.mockNormalFilesBox.keys).thenReturn([]);
      when(() => testContext.mockSecureFilesBox.keys).thenReturn([]);
      when(() => mockCustomBox.keys).thenReturn(['custom_key']);

      final keys = await testContext.vaultStorage.keys();

      expect(keys, containsAll(['normal_key', 'secure_key', 'custom_key']));
    });

    test('should include custom box keys when isSecure is specified', () async {
      final mockCustomBox = MockBox<dynamic>();
      testContext.vaultStorage.customBoxes['tenant'] = mockCustomBox;

      when(() => testContext.mockSecureBox.keys).thenReturn(['secure_key']);
      when(() => testContext.mockSecureFilesBox.keys).thenReturn([]);
      when(() => mockCustomBox.keys).thenReturn(['custom_key']);

      final keys = await testContext.vaultStorage.keys(isSecure: true);

      expect(keys, containsAll(['secure_key', 'custom_key']));
    });
  });

  group('clearNormal/clearSecure rethrow StorageError', () {
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

    test('clearNormal should rethrow StorageError without wrapping', () async {
      when(() => testContext.mockNormalBox.clear())
          .thenThrow(const StorageDeleteError('inner error'));

      expect(
        () => testContext.vaultStorage.clearNormal(),
        throwsA(isA<StorageDeleteError>().having(
          (e) => e.message,
          'message',
          equals('inner error'),
        )),
      );
    });

    test('clearSecure should rethrow StorageError without wrapping', () async {
      when(() => testContext.mockSecureBox.clear())
          .thenThrow(const StorageDeleteError('inner error'));

      expect(
        () => testContext.vaultStorage.clearSecure(),
        throwsA(isA<StorageDeleteError>().having(
          (e) => e.message,
          'message',
          equals('inner error'),
        )),
      );
    });

    test('clearNormal should wrap non-StorageError in StorageDeleteError', () async {
      when(() => testContext.mockNormalBox.clear()).thenThrow(Exception('unexpected'));

      expect(
        () => testContext.vaultStorage.clearNormal(),
        throwsA(isA<StorageDeleteError>().having(
          (e) => e.message,
          'message',
          equals('Failed to clear normal storage'),
        )),
      );
    });
  });

  group('dispose handles in-flight init', () {
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

    test('should dispose cleanly when not initialized and no pending init', () async {
      testContext.vaultStorage.isVaultStorageReady = false;

      // Should not throw
      await testContext.vaultStorage.dispose();

      expect(testContext.vaultStorage.isVaultStorageReady, isFalse);
    });

    test('should survive custom box close error during dispose', () async {
      final mockCustomBox = MockBox<dynamic>();
      testContext.vaultStorage.customBoxes['failing'] = mockCustomBox;

      when(() => testContext.mockSecureBox.close()).thenAnswer((_) async {});
      when(() => testContext.mockNormalBox.close()).thenAnswer((_) async {});
      when(() => testContext.mockSecureFilesBox.close()).thenAnswer((_) async {});
      when(() => testContext.mockNormalFilesBox.close()).thenAnswer((_) async {});
      when(() => mockCustomBox.close()).thenThrow(Exception('close failed'));

      // Should not throw despite custom box close failure
      await testContext.vaultStorage.dispose();

      expect(testContext.vaultStorage.isVaultStorageReady, isFalse);
      expect(testContext.vaultStorage.customBoxes, isEmpty);
    });
  });

  group('Custom box file operations', () {
    late TestContext testContext;
    late MockBox<dynamic> mockCustomBox;

    setUpAll(() {
      MocksHelper.registerFallbackValues();
    });

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
      mockCustomBox = MockBox<dynamic>();
      testContext.vaultStorage.customBoxes['tenant'] = mockCustomBox;
    });

    tearDown(() {
      testContext.tearDownCommon();
    });

    test('saveSecureFile to custom box should store base64 data', () async {
      when(() => mockCustomBox.containsKey(any<dynamic>())).thenReturn(false);
      when(() => mockCustomBox.put(any<dynamic>(), any<dynamic>())).thenAnswer((_) async {});

      await testContext.vaultStorage.saveSecureFile(
        key: 'myfile',
        fileBytes: Uint8List.fromList([1, 2, 3]),
        originalFileName: 'test.png',
        metadata: {'author': 'tester'},
        box: 'tenant',
      );

      final captured = verify(
        () => mockCustomBox.put('myfile', captureAny<dynamic>()),
      ).captured.single;
      // _putInBoxBase now stores StoredValue directly (v4.x TypeAdapter format)
      expect(captured, isA<StoredValue>());
    });

    test('saveSecureFile to non-existent box should throw BoxNotFoundError', () {
      expect(
        () => testContext.vaultStorage.saveSecureFile(
          key: 'myfile',
          fileBytes: Uint8List.fromList([1, 2, 3]),
          box: 'unknown_box',
        ),
        throwsA(isA<BoxNotFoundError>()),
      );
    });

    test('saveNormalFile to custom box should store base64 data', () async {
      when(() => mockCustomBox.containsKey(any<dynamic>())).thenReturn(false);
      when(() => mockCustomBox.put(any<dynamic>(), any<dynamic>())).thenAnswer((_) async {});

      await testContext.vaultStorage.saveNormalFile(
        key: 'myfile',
        fileBytes: Uint8List.fromList([4, 5, 6]),
        originalFileName: 'data.bin',
        metadata: {'category': 'docs'},
        box: 'tenant',
      );

      final captured = verify(
        () => mockCustomBox.put('myfile', captureAny<dynamic>()),
      ).captured.single;
      // _putInBoxBase now stores StoredValue directly (v4.x TypeAdapter format)
      expect(captured, isA<StoredValue>());
    });

    test('saveNormalFile to non-existent box should throw BoxNotFoundError', () {
      expect(
        () => testContext.vaultStorage.saveNormalFile(
          key: 'myfile',
          fileBytes: Uint8List.fromList([1, 2, 3]),
          box: 'unknown_box',
        ),
        throwsA(isA<BoxNotFoundError>()),
      );
    });

    test('getFile from custom box should return decoded bytes', () async {
      when(() => mockCustomBox.containsKey('myfile')).thenReturn(true);
      // For Box<dynamic>, _getFromBoxBase calls box.get(key) synchronously.
      // Return a plain JSON string (legacy format) with the custom box structure
      when(() => mockCustomBox.get('myfile'))
          .thenReturn('{"base64Data":"AQID","extension":"bin","isCustomBox":true}');

      final result = await testContext.vaultStorage.getFile('myfile', box: 'tenant');

      expect(result, isNotNull);
      expect(result, equals(Uint8List.fromList([1, 2, 3])));
    });

    test('getFile from non-existent custom box should throw BoxNotFoundError', () {
      expect(
        () => testContext.vaultStorage.getFile('myfile', box: 'unknown_box'),
        throwsA(isA<BoxNotFoundError>()),
      );
    });

    test('getFile from custom box returns null when key not found', () async {
      when(() => mockCustomBox.containsKey('missing')).thenReturn(false);

      final result = await testContext.vaultStorage.getFile('missing', box: 'tenant');

      expect(result, isNull);
    });

    test('getFile from custom box throws StorageReadError for invalid metadata', () async {
      when(() => mockCustomBox.containsKey('bad')).thenReturn(true);
      // Return data without 'isCustomBox: true' (plain JSON string, legacy format)
      when(() => mockCustomBox.get('bad')).thenReturn('{"someField":"data"}');

      expect(
        () => testContext.vaultStorage.getFile('bad', box: 'tenant'),
        throwsA(isA<StorageReadError>().having(
          (e) => e.message,
          'message',
          contains('Invalid custom box file metadata'),
        )),
      );
    });
  });

  group('getFile auto-search', () {
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

    test('should return null when key not found in any box', () async {
      when(() => testContext.mockNormalFilesBox.containsKey('missing')).thenReturn(false);
      when(() => testContext.mockSecureFilesBox.containsKey('missing')).thenReturn(false);

      final result = await testContext.vaultStorage.getFile('missing');

      expect(result, isNull);
    });

    test('should throw AmbiguousKeyError when file in multiple default boxes', () async {
      // Normal files box has the key
      when(() => testContext.mockNormalFilesBox.containsKey('ambiguous')).thenReturn(true);
      when(() => testContext.mockNormalFilesBox.get('ambiguous'))
          .thenAnswer((_) async => '{"fileId":"1","filePath":"/f","isSecure":false}');

      // Secure files box also has the key
      when(() => testContext.mockSecureFilesBox.containsKey('ambiguous')).thenReturn(true);
      when(() => testContext.mockSecureFilesBox.get('ambiguous'))
          .thenAnswer((_) async => '{"fileId":"2","filePath":"/g","isSecure":true}');

      expect(
        () => testContext.vaultStorage.getFile('ambiguous'),
        throwsA(isA<AmbiguousKeyError>()),
      );
    });
  });

  group('Type coercion', () {
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

    test('should throw StorageReadError for incompatible type', () async {
      // Store a bool value directly in normal box
      when(() => testContext.mockNormalBox.containsKey('typed')).thenReturn(true);
      when(() => testContext.mockNormalBox.get('typed')).thenReturn(true);

      expect(
        () => testContext.vaultStorage.get<List<int>>('typed', isSecure: false),
        throwsA(isA<StorageReadError>().having(
          (e) => e.message,
          'message',
          contains('Type mismatch'),
        )),
      );
    });

    test('should coerce int from num', () async {
      when(() => testContext.mockNormalBox.containsKey('num_val')).thenReturn(true);
      when(() => testContext.mockNormalBox.get('num_val')).thenReturn(42.0);

      final result = await testContext.vaultStorage.get<int>('num_val', isSecure: false);

      expect(result, equals(42));
    });

    test('should coerce double from int', () async {
      when(() => testContext.mockNormalBox.containsKey('int_val')).thenReturn(true);
      when(() => testContext.mockNormalBox.get('int_val')).thenReturn(42);

      final result = await testContext.vaultStorage.get<double>('int_val', isSecure: false);

      expect(result, equals(42.0));
    });
  });

  group('AmbiguousKeyError', () {
    test('should store key and foundInBoxes', () {
      // Use non-const to ensure runtime constructor execution for coverage
      // ignore: prefer_const_constructors
      final error = AmbiguousKeyError(
        'test_key',
        ['box1', 'box2'],
        'Key found in multiple boxes',
      );

      expect(error.key, equals('test_key'));
      expect(error.foundInBoxes, equals(['box1', 'box2']));
      expect(error.message, equals('Key found in multiple boxes'));
      expect(error.originalException, isNull);
    });

    test('should format toString correctly', () {
      // ignore: prefer_const_constructors
      final error = AmbiguousKeyError(
        'key',
        ['normal', 'secure'],
        'Ambiguous key',
      );

      expect(
        error.toString(),
        equals('AmbiguousKeyError: Ambiguous key'),
      );
    });
  });

  group('get() auto-search ambiguity detection', () {
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

    test('should throw AmbiguousKeyError when key found in both default boxes', () async {
      // Key exists in both normal AND secure boxes (stored as native StoredValue)
      final normalWrapped = const StoredValue('normal_val', StorageStrategy.native).toHiveMap();
      final secureWrapped = const StoredValue('secure_val', StorageStrategy.native).toHiveMap();
      when(() => testContext.mockNormalBox.containsKey('shared')).thenReturn(true);
      when(() => testContext.mockNormalBox.get('shared')).thenReturn(normalWrapped);
      when(() => testContext.mockSecureBox.containsKey('shared')).thenReturn(true);
      when(() => testContext.mockSecureBox.get('shared')).thenReturn(secureWrapped);

      expect(
        () => testContext.vaultStorage.get<String>('shared'),
        throwsA(isA<AmbiguousKeyError>().having(
          (e) => e.foundInBoxes,
          'foundInBoxes',
          containsAll(['normal', 'secure']),
        )),
      );
    });

    test('should throw AmbiguousKeyError when key in default box and custom box', () async {
      final mockCustomBox = MockBox<dynamic>();
      testContext.vaultStorage.customBoxes['tenant'] = mockCustomBox;

      final normalWrapped = const StoredValue('normal_val', StorageStrategy.native).toHiveMap();
      final customWrapped = const StoredValue('custom_val', StorageStrategy.native).toHiveMap();
      when(() => testContext.mockNormalBox.containsKey('shared')).thenReturn(true);
      when(() => testContext.mockNormalBox.get('shared')).thenReturn(normalWrapped);
      when(() => testContext.mockSecureBox.containsKey('shared')).thenReturn(false);
      when(() => mockCustomBox.containsKey('shared')).thenReturn(true);
      when(() => mockCustomBox.get('shared')).thenReturn(customWrapped);

      expect(
        () => testContext.vaultStorage.get<String>('shared'),
        throwsA(isA<AmbiguousKeyError>().having(
          (e) => e.foundInBoxes,
          'foundInBoxes',
          containsAll(['normal', 'tenant']),
        )),
      );
    });
  });

  group('saveSecureFile streaming and metadata', () {
    late TestContext testContext;
    late int originalThreshold;

    setUpAll(() {
      MocksHelper.registerFallbackValues();
    });

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
      originalThreshold = VaultStorageConfig.secureFileStreamingThresholdBytes;
    });

    tearDown(() {
      VaultStorageConfig.secureFileStreamingThresholdBytes = originalThreshold;
      testContext.tearDownCommon();
    });

    test('should use streaming path when file exceeds threshold', () async {
      // Lower threshold to trigger streaming path
      VaultStorageConfig.secureFileStreamingThresholdBytes = 1;

      final streamMetadata = {'fileId': 'stream-id', 'extension': 'bin'};
      when(() => testContext.mockFileOperations.saveSecureFileStream(
            stream: any(named: 'stream'),
            fileExtension: any(named: 'fileExtension'),
            isWeb: any(named: 'isWeb'),
            secureStorage: any(named: 'secureStorage'),
            uuid: any(named: 'uuid'),
            getBox: any(named: 'getBox'),
            chunkSize: any(named: 'chunkSize'),
          )).thenAnswer((_) async => streamMetadata);
      when(() => testContext.mockSecureFilesBox.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      await testContext.vaultStorage.saveSecureFile(
        key: 'big_file',
        fileBytes: Uint8List.fromList([1, 2, 3]),
      );

      verify(() => testContext.mockFileOperations.saveSecureFileStream(
            stream: any(named: 'stream'),
            fileExtension: any(named: 'fileExtension'),
            isWeb: any(named: 'isWeb'),
            secureStorage: any(named: 'secureStorage'),
            uuid: any(named: 'uuid'),
            getBox: any(named: 'getBox'),
            chunkSize: any(named: 'chunkSize'),
          )).called(1);
    });

    test('should include user metadata in secure file storage', () async {
      final mockMetadata = {'fileId': 'test-id', 'extension': 'txt'};
      when(() => testContext.mockFileOperations.saveSecureFile(
            fileBytes: any(named: 'fileBytes'),
            fileExtension: any(named: 'fileExtension'),
            isWeb: any(named: 'isWeb'),
            secureStorage: any(named: 'secureStorage'),
            uuid: any(named: 'uuid'),
            getBox: any(named: 'getBox'),
          )).thenAnswer((_) async => mockMetadata);
      when(() => testContext.mockSecureFilesBox.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      await testContext.vaultStorage.saveSecureFile(
        key: 'with_meta',
        fileBytes: Uint8List.fromList([1, 2]),
        metadata: {'author': 'test'},
      );

      final captured = verify(
        () => testContext.mockSecureFilesBox.put('with_meta', captureAny<dynamic>()),
      ).captured.single as StoredValue;
      expect(captured.value, isA<Map<dynamic, dynamic>>());
      expect((captured.value as Map<dynamic, dynamic>)['userMetadata'], equals({'author': 'test'}));
    });
  });

  group('saveNormalFile with metadata', () {
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

    test('should include user metadata in normal file storage', () async {
      final mockMetadata = {'fileId': 'normal-id', 'extension': 'pdf'};
      when(() => testContext.mockFileOperations.saveNormalFile(
            fileBytes: any(named: 'fileBytes'),
            fileExtension: any(named: 'fileExtension'),
            isWeb: any(named: 'isWeb'),
            uuid: any(named: 'uuid'),
            getBox: any(named: 'getBox'),
          )).thenAnswer((_) async => mockMetadata);
      when(() => testContext.mockNormalFilesBox.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});

      await testContext.vaultStorage.saveNormalFile(
        key: 'doc',
        fileBytes: Uint8List.fromList([10, 20]),
        metadata: {'category': 'reports'},
      );

      final captured = verify(
        () => testContext.mockNormalFilesBox.put('doc', captureAny<dynamic>()),
      ).captured.single as StoredValue;
      expect(captured.value, isA<Map<dynamic, dynamic>>());
      expect((captured.value as Map<dynamic, dynamic>)['userMetadata'],
          equals({'category': 'reports'}));
    });
  });

  group('getFile content retrieval paths', () {
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

    test('getFile with isSecure=false returns normal file via getNormalFile', () async {
      final expectedBytes = Uint8List.fromList([10, 20, 30]);
      const jsonMetadata = '{"fileId":"n-id","isSecure":false}';

      when(() => testContext.mockNormalFilesBox.containsKey('myfile')).thenReturn(true);
      when(() => testContext.mockNormalFilesBox.get('myfile'))
          .thenAnswer((_) async => jsonMetadata);
      when(() => testContext.mockFileOperations.getNormalFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            getBox: any(named: 'getBox'),
          )).thenAnswer((_) async => expectedBytes);

      final result = await testContext.vaultStorage.getFile('myfile', isSecure: false);

      expect(result, equals(expectedBytes));
      verify(() => testContext.mockFileOperations.getNormalFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            getBox: any(named: 'getBox'),
          )).called(1);
    });

    test('getFile auto-search finds file in normal box and returns content', () async {
      final expectedBytes = Uint8List.fromList([5, 6, 7]);
      const jsonMetadata = '{"fileId":"auto-n","filePath":"/f"}';

      // File only in normal files box
      when(() => testContext.mockNormalFilesBox.containsKey('autofile')).thenReturn(true);
      when(() => testContext.mockNormalFilesBox.get('autofile'))
          .thenAnswer((_) async => jsonMetadata);
      when(() => testContext.mockSecureFilesBox.containsKey('autofile')).thenReturn(false);

      when(() => testContext.mockFileOperations.getNormalFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            getBox: any(named: 'getBox'),
          )).thenAnswer((_) async => expectedBytes);

      final result = await testContext.vaultStorage.getFile('autofile');

      expect(result, equals(expectedBytes));
      verify(() => testContext.mockFileOperations.getNormalFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            getBox: any(named: 'getBox'),
          )).called(1);
    });

    test('getFile auto-search finds file in secure box and returns content', () async {
      final expectedBytes = Uint8List.fromList([8, 9, 10]);
      const jsonMetadata = '{"fileId":"auto-s","filePath":"/g"}';

      // File only in secure files box
      when(() => testContext.mockNormalFilesBox.containsKey('secfile')).thenReturn(false);
      when(() => testContext.mockSecureFilesBox.containsKey('secfile')).thenReturn(true);
      when(() => testContext.mockSecureFilesBox.get('secfile'))
          .thenAnswer((_) async => jsonMetadata);

      when(() => testContext.mockFileOperations.getSecureFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            secureStorage: any(named: 'secureStorage'),
            getBox: any(named: 'getBox'),
          )).thenAnswer((_) async => expectedBytes);

      final result = await testContext.vaultStorage.getFile('secfile');

      expect(result, equals(expectedBytes));
      verify(() => testContext.mockFileOperations.getSecureFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            secureStorage: any(named: 'secureStorage'),
            getBox: any(named: 'getBox'),
          )).called(1);
    });

    test('getFile auto-search finds file in custom box and returns decoded bytes', () async {
      final mockCustomBox = MockBox<dynamic>();
      testContext.vaultStorage.customBoxes['tenant'] = mockCustomBox;

      // No file in default boxes
      when(() => testContext.mockNormalFilesBox.containsKey('cbfile')).thenReturn(false);
      when(() => testContext.mockSecureFilesBox.containsKey('cbfile')).thenReturn(false);

      // File in custom box (stored as legacy JSON string with isCustomBox flag)
      when(() => mockCustomBox.containsKey('cbfile')).thenReturn(true);
      when(() => mockCustomBox.get('cbfile'))
          .thenReturn('{"base64Data":"AQID","extension":"bin","isCustomBox":true}');

      final result = await testContext.vaultStorage.getFile('cbfile');

      expect(result, equals(Uint8List.fromList([1, 2, 3])));
    });
  });

  group('clearAllFilesInBox with entries', () {
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

    test('should delete underlying normal files before clearing box', () async {
      const jsonMetadata = '{"fileId":"f1","filePath":"/tmp/f1.txt"}';

      when(() => testContext.mockNormalFilesBox.keys).thenReturn(['file1']);
      when(() => testContext.mockNormalFilesBox.containsKey('file1')).thenReturn(true);
      when(() => testContext.mockNormalFilesBox.get('file1')).thenAnswer((_) async => jsonMetadata);
      when(() => testContext.mockNormalFilesBox.clear()).thenAnswer((_) async => 0);

      when(() => testContext.mockFileOperations.deleteNormalFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            getBox: any(named: 'getBox'),
          )).thenAnswer((_) async {});

      await testContext.vaultStorage.clearAllFilesInBox(BoxType.normalFiles, isSecure: false);

      verify(() => testContext.mockFileOperations.deleteNormalFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            getBox: any(named: 'getBox'),
          )).called(1);
      verify(() => testContext.mockNormalFilesBox.clear()).called(1);
    });

    test('should delete underlying secure files before clearing box', () async {
      const jsonMetadata = '{"fileId":"s1","filePath":"/tmp/s1.enc"}';

      when(() => testContext.mockSecureFilesBox.keys).thenReturn(['sfile1']);
      when(() => testContext.mockSecureFilesBox.containsKey('sfile1')).thenReturn(true);
      when(() => testContext.mockSecureFilesBox.get('sfile1'))
          .thenAnswer((_) async => jsonMetadata);
      when(() => testContext.mockSecureFilesBox.clear()).thenAnswer((_) async => 0);

      when(() => testContext.mockFileOperations.deleteSecureFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            secureStorage: any(named: 'secureStorage'),
            getBox: any(named: 'getBox'),
          )).thenAnswer((_) async {});

      await testContext.vaultStorage.clearAllFilesInBox(BoxType.secureFiles, isSecure: true);

      verify(() => testContext.mockFileOperations.deleteSecureFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            secureStorage: any(named: 'secureStorage'),
            getBox: any(named: 'getBox'),
          )).called(1);
      verify(() => testContext.mockSecureFilesBox.clear()).called(1);
    });

    test('should continue on per-file delete errors', () async {
      const jsonMetadata = '{"fileId":"f1","filePath":"/tmp/f1.txt"}';

      when(() => testContext.mockNormalFilesBox.keys).thenReturn(['file1', 'file2']);
      when(() => testContext.mockNormalFilesBox.containsKey(any<dynamic>())).thenReturn(true);
      when(() => testContext.mockNormalFilesBox.get(any<dynamic>()))
          .thenAnswer((_) async => jsonMetadata);
      when(() => testContext.mockNormalFilesBox.clear()).thenAnswer((_) async => 0);

      // First file delete throws, second succeeds
      var callCount = 0;
      when(() => testContext.mockFileOperations.deleteNormalFile(
            fileMetadata: any(named: 'fileMetadata'),
            isWeb: any(named: 'isWeb'),
            getBox: any(named: 'getBox'),
          )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw Exception('IO error');
      });

      // Should not throw despite first file failing
      await testContext.vaultStorage.clearAllFilesInBox(BoxType.normalFiles, isSecure: false);

      verify(() => testContext.mockNormalFilesBox.clear()).called(1);
    });
  });

  group('keys() error handling', () {
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

    test('should wrap errors in StorageReadError', () async {
      when(() => testContext.mockNormalBox.keys).thenThrow(Exception('corrupted'));

      expect(
        () => testContext.vaultStorage.keys(),
        throwsA(isA<StorageReadError>().having(
          (e) => e.message,
          'message',
          equals('Failed to list keys'),
        )),
      );
    });
  });

  group('deleteFile with file metadata', () {
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

    test('should delete from custom boxes during default deleteFile', () async {
      final mockCustomBox = MockBox<dynamic>();
      testContext.vaultStorage.customBoxes['tenant'] = mockCustomBox;

      // No metadata in default file boxes
      when(() => testContext.mockNormalFilesBox.containsKey('cf')).thenReturn(false);
      when(() => testContext.mockSecureFilesBox.containsKey('cf')).thenReturn(false);

      // Key exists in custom box
      when(() => mockCustomBox.containsKey('cf')).thenReturn(true);
      when(() => mockCustomBox.delete('cf')).thenAnswer((_) async {});

      await testContext.vaultStorage.deleteFile('cf');

      verify(() => mockCustomBox.delete('cf')).called(1);
    });
  });

  group('_getFromBoxBase JSON strategy path', () {
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

    test('should decode JSON-strategy wrapped values', () async {
      // Create a StoredValue map with JSON strategy containing a JSON-encoded map
      final wrappedValue =
          const StoredValue('{"name":"test","count":42}', StorageStrategy.json).toHiveMap();

      when(() => testContext.mockNormalBox.containsKey('json_val')).thenReturn(true);
      when(() => testContext.mockNormalBox.get('json_val')).thenReturn(wrappedValue);

      final result =
          await testContext.vaultStorage.get<Map<String, dynamic>>('json_val', isSecure: false);

      expect(result, isNotNull);
      expect(result!['name'], equals('test'));
      expect(result['count'], equals(42));
    });
  });

  group('saveSecure removes from normal box', () {
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

    test('should not attempt normal box removal when key not in normal box', () async {
      when(() => testContext.mockSecureBox.put(any<dynamic>(), any<dynamic>()))
          .thenAnswer((_) async {});
      when(() => testContext.mockNormalBox.containsKey('only_secure')).thenReturn(false);

      await testContext.vaultStorage.saveSecure(key: 'only_secure', value: 'data');

      verifyNever(() => testContext.mockNormalBox.delete(any<dynamic>()));
    });
  });
}
