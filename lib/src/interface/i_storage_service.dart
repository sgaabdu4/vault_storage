import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:storage_service/src/enum/storage_box_type.dart';
import 'package:storage_service/src/errors/storage_error.dart';

/// Defines the contract for the Storage Service.
/// This service now handles both key-value data storage and secure file storage.
abstract class IStorageService {
  Future<Either<StorageError, Unit>> init();
  Future<Either<StorageError, T?>> get<T>(BoxType box, String key);
  Future<Either<StorageError, void>> set<T>(BoxType box, String key, T value);
  Future<Either<StorageError, void>> delete(BoxType box, String key);
  Future<Either<StorageError, void>> clear(BoxType box);

  Future<Either<StorageError, Map<String, dynamic>>> saveSecureFile({
    required Uint8List fileBytes,
    required String fileExtension,
  });

  Future<Either<StorageError, Uint8List>> getSecureFile({
    required Map<String, dynamic> fileMetadata,
  });

  Future<Either<StorageError, Unit>> deleteSecureFile({required Map<String, dynamic> fileMetadata});
}
