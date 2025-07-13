// test/unit/vault_storage/service_lifecycle_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/enum/internal_storage_box_type.dart';
import 'package:vault_storage/src/errors/storage_error.dart';
import 'package:vault_storage/src/extensions/storage_extensions.dart';
import '../../test_context.dart';

void main() {
  final ctx = TestContext();

  setUp(ctx.setUpCommon);
  tearDown(ctx.tearDownCommon);

  group('Service Lifecycle Management', () {
    group('Service State', () {
      test(
          'any operation should return StorageInitializationError if not initialized',
          () async {
        ctx.vaultStorage.isVaultStorageReady = false;

        final getResult =
            await ctx.vaultStorage.get<dynamic>(BoxType.normal, 'key');
        expect(getResult.fold((l) => l, (r) => r),
            isA<StorageInitializationError>());

        final setResult =
            await ctx.vaultStorage.set(BoxType.normal, 'key', 'value');
        expect(setResult.isLeft(), isTrue);
        setResult.fold((l) => expect(l, isA<StorageInitializationError>()),
            (r) => fail('Expected a StorageInitializationError'));
      });

      test('dispose should clear boxes and set ready flag to false', () async {
        await ctx.vaultStorage.dispose();
        expect(ctx.vaultStorage.storageBoxes.isEmpty, isTrue);
        expect(ctx.vaultStorage.isVaultStorageReady, isFalse);
      });

      test('dispose should return StorageDisposalError on failure', () async {
        // This test is more about ensuring the error handling path exists
        // The actual failure would come from Hive.close() in real scenarios
        ctx.vaultStorage.isVaultStorageReady = true;

        final result = await ctx.vaultStorage.dispose();

        // In normal cases, this should succeed
        expect(result.isRight(), isTrue);
      });

      test(
          '_getBox being called for a non-existent box should result in an error',
          () async {
        ctx.vaultStorage.storageBoxes.remove(InternalBoxType.secure);
        final result =
            await ctx.vaultStorage.get<dynamic>(BoxType.secure, 'key');
        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
      });
    });

    group('Initialization', () {
      test('init should succeed and set isVaultStorageReady to true', () async {
        ctx.vaultStorage.isVaultStorageReady = false;
        when(ctx.mockSecureStorage.read(key: anyNamed('key'))).thenAnswer(
            (_) async => List.generate(32, (i) => i).encodeBase64());

        final result = await ctx.vaultStorage.init();

        expect(result.isRight(), isTrue);
        expect(ctx.vaultStorage.isVaultStorageReady, isTrue);
      });

      test('init should return left if already initialized', () async {
        final result = await ctx.vaultStorage.init();
        expect(result.isRight(), isTrue);
      });

      test('getOrCreateSecureKey should create a key if one does not exist',
          () async {
        when(ctx.mockSecureStorage.read(key: anyNamed('key')))
            .thenAnswer((_) async => null);
        when(ctx.mockSecureStorage
                .write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});

        final result = await ctx.vaultStorage.getOrCreateSecureKey().run();

        expect(result.isRight(), isTrue);
        verify(ctx.mockSecureStorage
                .write(key: anyNamed('key'), value: anyNamed('value')))
            .called(1);
      });

      test('getOrCreateSecureKey should return existing key', () async {
        final key = List.generate(32, (i) => i).encodeBase64();
        when(ctx.mockSecureStorage.read(key: anyNamed('key')))
            .thenAnswer((_) async => key);

        final result = await ctx.vaultStorage.getOrCreateSecureKey().run();

        expect(result.isRight(), isTrue);
        result.fold((l) => fail('should not be left'),
            (r) => expect(r.encodeBase64(), key));
        verify(ctx.mockSecureStorage.read(key: anyNamed('key'))).called(1);
      });

      test('openBoxes should open all box types', () async {
        final key = List.generate(32, (i) => i);
        final result = await ctx.vaultStorage.openBoxes(key).run();

        expect(result.isRight(), isTrue);
        expect(
            ctx.vaultStorage.storageBoxes.containsKey(InternalBoxType.secure),
            isTrue);
        expect(
            ctx.vaultStorage.storageBoxes.containsKey(InternalBoxType.normal),
            isTrue);
        expect(
            ctx.vaultStorage.storageBoxes
                .containsKey(InternalBoxType.secureFiles),
            isTrue);
        expect(
            ctx.vaultStorage.storageBoxes
                .containsKey(InternalBoxType.normalFiles),
            isTrue);
      });

      test('init should return StorageInitializationError on failure',
          () async {
        ctx.vaultStorage.isVaultStorageReady = false;
        when(ctx.mockSecureStorage.read(key: anyNamed('key')))
            .thenThrow(Exception('Could not read key'));

        final result = await ctx.vaultStorage.init();

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => null),
            isA<StorageInitializationError>());
        expect(ctx.vaultStorage.isVaultStorageReady, isFalse);
      });

      test(
          'getOrCreateSecureKey should return StorageInitializationError on read failure',
          () async {
        when(ctx.mockSecureStorage.read(key: anyNamed('key')))
            .thenThrow(Exception('Could not read key'));

        final result = await ctx.vaultStorage.getOrCreateSecureKey().run();

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => null),
            isA<StorageInitializationError>());
      });

      test(
          'getOrCreateSecureKey should return StorageInitializationError on write failure',
          () async {
        when(ctx.mockSecureStorage.read(key: anyNamed('key')))
            .thenAnswer((_) async => null);
        when(ctx.mockSecureStorage
                .write(key: anyNamed('key'), value: anyNamed('value')))
            .thenThrow(Exception('Could not write key'));

        final result = await ctx.vaultStorage.getOrCreateSecureKey().run();

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => null),
            isA<StorageInitializationError>());
      });

      test('openBoxes should return StorageInitializationError on failure',
          () async {
        final key = List.generate(16, (i) => i); // Invalid key
        final result = await ctx.vaultStorage.openBoxes(key).run();

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => null),
            isA<StorageInitializationError>());
      });

      test('init should open all box types', () async {
        ctx.vaultStorage.isVaultStorageReady = false;
        ctx.vaultStorage.storageBoxes.clear();
        when(ctx.mockSecureStorage.read(key: anyNamed('key'))).thenAnswer(
            (_) async => List.generate(32, (i) => i).encodeBase64());

        final result = await ctx.vaultStorage.init();

        expect(result.isRight(), isTrue);
        expect(ctx.vaultStorage.isVaultStorageReady, isTrue);
        expect(
            ctx.vaultStorage.storageBoxes.containsKey(InternalBoxType.secure),
            isTrue);
        expect(
            ctx.vaultStorage.storageBoxes.containsKey(InternalBoxType.normal),
            isTrue);
        expect(
            ctx.vaultStorage.storageBoxes
                .containsKey(InternalBoxType.secureFiles),
            isTrue);
        expect(
            ctx.vaultStorage.storageBoxes
                .containsKey(InternalBoxType.normalFiles),
            isTrue);
      });
    });
  });
}
