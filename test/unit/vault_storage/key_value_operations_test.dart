// test/unit/vault_storage/key_value_operations_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/mockito.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/errors/storage_error.dart';
import '../../test_context.dart';

void main() {
  final ctx = TestContext();

  setUp(ctx.setUpCommon);
  tearDown(ctx.tearDownCommon);

  group('Key-Value Storage Operations', () {
    group('get', () {
      test('should return value when key exists', () async {
        const key = 'test_key';
        final value = {'data': 'test_data'};
        when(ctx.mockNormalBox.get(key)).thenReturn('{"data":"test_data"}');

        final result = await ctx.vaultStorage
            .get<Map<String, dynamic>>(BoxType.normal, key);

        expect(result.isRight(), isTrue);
        expect(result.getOrElse((_) => {}), value);
      });

      test('should return null when key does not exist', () async {
        const key = 'non_existent_key';
        when(ctx.mockNormalBox.get(key)).thenReturn(null);

        final result = await ctx.vaultStorage.get<dynamic>(BoxType.normal, key);

        expect(result.isRight(), isTrue);
        expect(result.getOrElse((_) => 'a'), isNull);
      });

      test('should return StorageReadError on failure', () async {
        const key = 'test_key';
        when(ctx.mockNormalBox.get(key)).thenThrow(Exception('Read error'));

        final result = await ctx.vaultStorage.get<dynamic>(BoxType.normal, key);

        expect(result.isLeft(), isTrue);
        expect(result.fold((l) => l, (r) => r), isA<StorageReadError>());
      });

      test('should return StorageSerializationError on json decoding error',
          () async {
        const key = 'test_key';
        when(ctx.mockNormalBox.get(key)).thenReturn('invalid json');

        final result = await ctx.vaultStorage.get<dynamic>(BoxType.normal, key);

        expect(result.isLeft(), isTrue);
        expect(
            result.fold((l) => l, (r) => r), isA<StorageSerializationError>());
      });
    });

    group('set', () {
      test('should return unit when value is set successfully', () async {
        const key = 'test_key';
        const value = {'data': 'test_data'};
        when(ctx.mockNormalBox.put(any, any)).thenAnswer((_) async => unit);

        final result = await ctx.vaultStorage.set(BoxType.normal, key, value);

        expect(result.isRight(), isTrue);
        verify(ctx.mockNormalBox.put(key, '{"data":"test_data"}')).called(1);
      });

      test('should return StorageWriteError on failure', () async {
        const key = 'test_key';
        const value = {'data': 'test_data'};
        when(ctx.mockNormalBox.put(any, any))
            .thenThrow(Exception('Write error'));

        final result = await ctx.vaultStorage.set(BoxType.normal, key, value);

        expect(result.isLeft(), isTrue);
        result.fold(
          (l) => expect(l, isA<StorageWriteError>()),
          (r) => fail('Expected a StorageWriteError'),
        );
      });

      test('should return StorageSerializationError on json encoding error',
          () async {
        const key = 'test_key';
        final value = _UnencodableObject();

        final result = await ctx.vaultStorage.set(BoxType.normal, key, value);

        expect(result.isLeft(), isTrue);
        result.fold(
          (l) => expect(l, isA<StorageSerializationError>()),
          (r) => fail('Expected a StorageSerializationError'),
        );
      });
    });

    group('delete', () {
      test('should return unit when value is deleted successfully', () async {
        const key = 'test_key';
        when(ctx.mockNormalBox.delete(key)).thenAnswer((_) async => unit);

        final result = await ctx.vaultStorage.delete(BoxType.normal, key);

        expect(result.isRight(), isTrue);
        verify(ctx.mockNormalBox.delete(key)).called(1);
      });

      test('should return StorageDeleteError on failure', () async {
        const key = 'test_key';
        when(ctx.mockNormalBox.delete(key))
            .thenThrow(Exception('Delete error'));

        final result = await ctx.vaultStorage.delete(BoxType.normal, key);

        expect(result.isLeft(), isTrue);
        result.fold(
          (l) => expect(l, isA<StorageDeleteError>()),
          (r) => fail('Expected a StorageDeleteError'),
        );
      });
    });

    group('clear', () {
      test('should return unit when box is cleared successfully', () async {
        when(ctx.mockNormalBox.clear()).thenAnswer((_) async => 1);

        final result = await ctx.vaultStorage.clear(BoxType.normal);

        expect(result.isRight(), isTrue);
        verify(ctx.mockNormalBox.clear()).called(1);
      });

      test('should return StorageDeleteError on failure', () async {
        when(ctx.mockNormalBox.clear()).thenThrow(Exception('Clear error'));

        final result = await ctx.vaultStorage.clear(BoxType.normal);

        expect(result.isLeft(), isTrue);
        result.fold(
          (l) => expect(l, isA<StorageDeleteError>()),
          (r) => fail('Expected a StorageDeleteError'),
        );
      });
    });
  });
}

class _UnencodableObject {
  @override
  String toString() => 'I am not encodable';
}
