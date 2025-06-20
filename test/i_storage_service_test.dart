import 'package:flutter_test/flutter_test.dart';
import 'package:storage_service/src/interface/i_storage_service.dart';
import 'package:storage_service/src/enum/storage_box_type.dart';
import 'package:fpdart/fpdart.dart';
import 'package:storage_service/src/errors/storage_error.dart';
import 'dart:typed_data';

class FakeStorageService implements IStorageService {
  @override
  Future<Either<StorageError, Unit>> init() async => right(unit);
  @override
  Future<Either<StorageError, T?>> get<T>(BoxType box, String key) async => right(null);
  @override
  Future<Either<StorageError, void>> set<T>(BoxType box, String key, T value) async => right(null);
  @override
  Future<Either<StorageError, void>> delete(BoxType box, String key) async => right(null);
  @override
  Future<Either<StorageError, void>> clear(BoxType box) async => right(null);
  @override
  Future<Either<StorageError, Map<String, dynamic>>> saveSecureFile(
          {required Uint8List fileBytes, required String fileExtension}) async =>
      right({'file': 'meta'});
  @override
  Future<Either<StorageError, Uint8List>> getSecureFile({required Map<String, dynamic> fileMetadata}) async =>
      right(Uint8List(0));
  @override
  Future<Either<StorageError, Unit>> deleteSecureFile({required Map<String, dynamic> fileMetadata}) async =>
      right(unit);
}

void main() {
  group('IStorageService', () {
    final service = FakeStorageService();
    test('init returns right', () async {
      final result = await service.init();
      expect(result.isRight(), true);
    });
    test('get returns right(null)', () async {
      final result = await service.get(BoxType.normal, 'key');
      expect(result.isRight(), true);
      expect(result.getRight().toNullable(), null);
    });
    test('set returns right', () async {
      final result = await service.set(BoxType.normal, 'key', 'value');
      expect(result.isRight(), true);
    });
    test('delete returns right', () async {
      final result = await service.delete(BoxType.normal, 'key');
      expect(result.isRight(), true);
    });
    test('clear returns right', () async {
      final result = await service.clear(BoxType.normal);
      expect(result.isRight(), true);
    });
    test('saveSecureFile returns right', () async {
      final result = await service.saveSecureFile(fileBytes: Uint8List(0), fileExtension: 'txt');
      expect(result.isRight(), true);
      expect(result.getRight().toNullable(), isA<Map<String, dynamic>>());
    });
    test('getSecureFile returns right', () async {
      final result = await service.getSecureFile(fileMetadata: {'file': 'meta'});
      expect(result.isRight(), true);
      expect(result.getRight().toNullable(), isA<Uint8List>());
    });
    test('deleteSecureFile returns right', () async {
      final result = await service.deleteSecureFile(fileMetadata: {'file': 'meta'});
      expect(result.isRight(), true);
    });
  });
}
