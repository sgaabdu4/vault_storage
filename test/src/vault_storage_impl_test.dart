import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/constants/storage_keys.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

import '../mocks.dart';
import '../test_context.dart';

void main() {
  group('VaultStorageImpl', () {
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

    group('init', () {
      test('should initialize successfully when not already initialized', () async {
        // Arrange
        final tempDir = Directory.systemTemp.createTempSync('vault_init_test_');
        addTearDown(() async {
          await Hive.close();
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });
        final vaultStorage = testContext.createStorage(storageDirectory: tempDir.path);

        // Provide a valid 32-byte key (AES-256) encoded in base64
        final base64Key = base64Encode(Uint8List(32));
        when(
          () => testContext.mockSecureStorage.read(key: StorageKeys.secureKey),
        ).thenAnswer((_) async => base64Key);

        // Act
        await vaultStorage.init();

        // Assert
        expect(vaultStorage.isVaultStorageReady, isTrue);
        verify(() => testContext.mockSecureStorage.read(key: StorageKeys.secureKey)).called(1);
      });

      test('should not reinitialize when already initialized', () async {
        // Arrange
        testContext.vaultStorage.isVaultStorageReady = true;

        // Act
        await testContext.vaultStorage.init();

        // Assert
        expect(testContext.vaultStorage.isVaultStorageReady, isTrue);
        verifyNever(() => testContext.mockSecureStorage.read(key: any(named: 'key')));
      });

      test('should throw VaultStorageInitializationError when initialization fails', () async {
        // Arrange
        final vaultStorage = testContext.createStorage();

        when(
          () => testContext.mockSecureStorage.read(key: StorageKeys.secureKey),
        ).thenThrow(Exception('Secure storage failed'));

        // Act & Assert
        expect(() => vaultStorage.init(), throwsA(isA<VaultStorageInitializationError>()));
      });
    });

    group('getOrCreateSecureKey', () {
      test('should return existing key when it exists', () async {
        // Arrange
        const existingKey = 'dGVzdEtleQ=='; // base64 encoded test key
        when(
          () => testContext.mockSecureStorage.read(key: StorageKeys.secureKey),
        ).thenAnswer((_) async => existingKey);

        // Act
        final result = await testContext.vaultStorage.getOrCreateSecureKey();

        // Assert
        expect(result, isA<List<int>>());
        verify(() => testContext.mockSecureStorage.read(key: StorageKeys.secureKey)).called(1);
        verifyNever(
          () => testContext.mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        );
      });

      test('should create new key when it does not exist', () async {
        // Arrange
        when(
          () => testContext.mockSecureStorage.read(key: StorageKeys.secureKey),
        ).thenAnswer((_) async => null);
        when(
          () => testContext.mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final result = await testContext.vaultStorage.getOrCreateSecureKey();

        // Assert
        expect(result, isA<List<int>>());
        expect(result.length, equals(32)); // AES-256 key length
        verify(() => testContext.mockSecureStorage.read(key: StorageKeys.secureKey)).called(1);
        verify(
          () => testContext.mockSecureStorage.write(
            key: StorageKeys.secureKey,
            value: any(named: 'value'),
          ),
        ).called(1);
      });

      test('should throw VaultStorageInitializationError when key creation fails', () async {
        // Arrange
        when(
          () => testContext.mockSecureStorage.read(key: StorageKeys.secureKey),
        ).thenThrow(Exception('Secure storage failed'));

        // Act & Assert
        expect(
          () => testContext.vaultStorage.getOrCreateSecureKey(),
          throwsA(isA<VaultStorageInitializationError>()),
        );
      });
    });

    group('get', () {
      test('should get value from normal storage when isSecure is false', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';
        const jsonValue = '"test_value"';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockNormalBox.get(key)).thenReturn(jsonValue);

        // Act
        final result = await testContext.vaultStorage.get<String>(key, isSecure: false);

        // Assert
        expect(result, equals(value));
        verify(() => testContext.mockNormalBox.containsKey(key)).called(1);
        verify(() => testContext.mockNormalBox.get(key)).called(1);
        verifyNever(() => testContext.mockSecureBox.containsKey(any<String>()));
      });

      test('should get value from secure storage when isSecure is true', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';
        const jsonValue = '"test_value"';

        when(() => testContext.mockSecureBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockSecureBox.get(key)).thenReturn(jsonValue);

        // Act
        final result = await testContext.vaultStorage.get<String>(key, isSecure: true);

        // Assert
        expect(result, equals(value));
        verify(() => testContext.mockSecureBox.containsKey(key)).called(1);
        verify(() => testContext.mockSecureBox.get(key)).called(1);
        verifyNever(() => testContext.mockNormalBox.containsKey(any<String>()));
      });

      test('should check both storages when isSecure is null', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';
        const jsonValue = '"test_value"';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(false);
        when(() => testContext.mockSecureBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockSecureBox.get(key)).thenReturn(jsonValue);

        // Act
        final result = await testContext.vaultStorage.get<String>(key);

        // Assert
        expect(result, equals(value));
        verify(() => testContext.mockNormalBox.containsKey(key)).called(1);
        verify(() => testContext.mockSecureBox.containsKey(key)).called(1);
        verify(() => testContext.mockSecureBox.get(key)).called(1);
      });

      test('should return null when key does not exist', () async {
        // Arrange
        const key = 'nonexistent_key';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(false);
        when(() => testContext.mockSecureBox.containsKey(key)).thenReturn(false);

        // Act
        final result = await testContext.vaultStorage.get<String>(key);

        // Assert
        expect(result, isNull);
      });

      test('should throw VaultStorageInitializationError when not initialized', () async {
        // Arrange
        testContext.vaultStorage.isVaultStorageReady = false;

        // Act & Assert
        expect(
          () => testContext.vaultStorage.get<String>('test_key'),
          throwsA(isA<VaultStorageInitializationError>()),
        );
      });

      test('should throw VaultStorageReadError when reading fails', () async {
        // Arrange
        const key = 'test_key';

        when(
          () => testContext.mockNormalBox.containsKey(key),
        ).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(
          () => testContext.vaultStorage.get<String>(key),
          throwsA(isA<VaultStorageReadError>()),
        );
      });
    });

    group('saveSecure', () {
      test('should save value to secure storage successfully', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        when(
          () => testContext.mockSecureBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});
        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(false);

        // Act
        await testContext.vaultStorage.saveSecure(key: key, value: value);

        // Assert
        verify(() => testContext.mockSecureBox.put(key, any<String>())).called(1);
        verify(() => testContext.mockNormalBox.containsKey(key)).called(1);
      });

      test('should remove from normal storage if key exists there', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        when(
          () => testContext.mockSecureBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});
        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockNormalBox.delete(key)).thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.saveSecure(key: key, value: value);

        // Assert
        verify(() => testContext.mockSecureBox.put(key, any<Object?>())).called(1);
        verify(() => testContext.mockNormalBox.containsKey(key)).called(1);
        verify(() => testContext.mockNormalBox.delete(key)).called(1);
      });

      test('should throw VaultStorageWriteError when save fails', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        when(
          () => testContext.mockSecureBox.put(any<String>(), any<String>()),
        ).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(
          () => testContext.vaultStorage.saveSecure(key: key, value: value),
          throwsA(isA<VaultStorageWriteError>()),
        );
      });
    });

    group('saveNormal', () {
      test('should save value to normal storage successfully', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        when(
          () => testContext.mockNormalBox.put(any<String>(), any<String>()),
        ).thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.saveNormal(key: key, value: value);

        // Assert
        verify(() => testContext.mockNormalBox.put(key, any<Object?>())).called(1);
      });

      test('should throw VaultStorageWriteError when save fails', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        when(
          () => testContext.mockNormalBox.put(any<String>(), any<String>()),
        ).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(
          () => testContext.vaultStorage.saveNormal(key: key, value: value),
          throwsA(isA<VaultStorageWriteError>()),
        );
      });
    });

    group('delete', () {
      test('should delete from both storages when key exists in both', () async {
        // Arrange
        const key = 'test_key';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockSecureBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockNormalBox.delete(key)).thenAnswer((_) async {});
        when(() => testContext.mockSecureBox.delete(key)).thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.delete(key);

        // Assert
        verify(() => testContext.mockNormalBox.delete(key)).called(1);
        verify(() => testContext.mockSecureBox.delete(key)).called(1);
      });

      test('should only delete from storage where key exists', () async {
        // Arrange
        const key = 'test_key';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockSecureBox.containsKey(key)).thenReturn(false);
        when(() => testContext.mockNormalBox.delete(key)).thenAnswer((_) async {});

        // Act
        await testContext.vaultStorage.delete(key);

        // Assert
        verify(() => testContext.mockNormalBox.delete(key)).called(1);
        verifyNever(() => testContext.mockSecureBox.delete(any<String>()));
      });

      test('should throw VaultStorageDeleteError when deletion fails', () async {
        // Arrange
        const key = 'test_key';

        when(() => testContext.mockNormalBox.containsKey(key)).thenReturn(true);
        when(() => testContext.mockSecureBox.containsKey(key)).thenReturn(false);
        when(() => testContext.mockNormalBox.delete(key)).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(() => testContext.vaultStorage.delete(key), throwsA(isA<VaultStorageDeleteError>()));
      });
    });
  });

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
      expect(
        () => testContext.vaultStorage.keys(),
        throwsA(isA<VaultStorageInitializationError>()),
      );
    });
  });

  group('Talsec config', () {
    late TestContext testContext;
    late VaultStorageImpl storage;

    setUpAll(() {
      MocksHelper.registerFallbackValues();
    });

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
      storage = testContext.createStorage();
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      testContext.tearDownCommon();
    });

    test('androidConfigFor passes the given package name and certificate hashes', () {
      final certificateHash = base64Encode(.filled(32, 0));

      final config = storage.androidConfigFor(
        packageName: 'com.example.app',
        signingCertHashes: [certificateHash],
      );

      expect(config.packageName, 'com.example.app');
      expect(config.certificateHashes, [certificateHash]);
      expect(config.supportedAlternativeStores, ['com.android.vending']);
    });

    test('androidConfigFor fills the placeholder package name when none is given', () {
      debugDefaultTargetPlatformOverride = .macOS;

      final config = storage.androidConfigFor();

      expect(config.packageName, 'your.package.name');
      expect(config.certificateHashes, isEmpty);
    });

    test('iosConfigFor passes the given bundle id and team id', () {
      final config = storage.iosConfigFor(bundleId: 'com.example.ios', teamId: 'TEAM');

      expect(config.appBundleIds, ['com.example.ios']);
      expect(config.appTeamId, 'TEAM');
    });

    test('iosConfigFor leaves the bundle ids and team id empty when none are given', () {
      final config = storage.iosConfigFor();

      expect(config.appBundleIds, isEmpty);
      expect(config.appTeamId, isEmpty);
    });
  });
}
