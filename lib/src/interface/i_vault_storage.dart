import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/errors/storage_error.dart';

/// Defines the contract for a comprehensive vault storage.
///
/// This interface specifies the capabilities for both key-value storage and secure
/// file storage. It is designed to be implemented by a service that can handle
/// sensitive and non-sensitive data, with clear separation between the two.
/// The use of `fpdart`'s `Either` type ensures robust, type-safe error handling.
abstract class IVaultStorage {
  /// Initializes the vault storage.
  ///
  /// This must be called before any other methods are used. It sets up the necessary
  /// resources, such as opening Hive boxes and preparing encryption keys.
  ///
  /// Returns a `Future` that completes with an `Either`:
  /// - `Right(Unit)` on successful initialization.
  /// - `Left(StorageError)` if initialization fails.
  Future<Either<StorageError, Unit>> init();

  /// Retrieves a value from the specified Hive box by its [key].
  ///
  /// The [box] parameter determines whether to read from the `normal` or `secure`
  /// box. The type parameter [T] specifies the expected type of the value.
  ///
  /// Returns a `Future` that completes with an `Either`:
  /// - `Right(T?)` containing the value if found, or `null` if the key does not exist.
  /// - `Left(StorageError)` if the read operation fails.
  Future<Either<StorageError, T?>> get<T>(BoxType box, String key);

  /// Saves a [value] in the specified Hive box with the given [key].
  ///
  /// The [box] parameter determines whether to write to the `normal` or `secure`
  /// box. The type parameter [T] is the type of the value being stored.
  ///
  /// Returns a `Future` that completes with an `Either`:
  /// - `Right(void)` on successful write.
  /// - `Left(StorageError)` if the write operation fails (e.g., due to serialization issues).
  Future<Either<StorageError, void>> set<T>(BoxType box, String key, T value);

  /// Deletes a value from the specified Hive box by its [key].
  ///
  /// The [box] parameter determines which box to perform the deletion on.
  ///
  /// Returns a `Future` that completes with an `Either`:
  /// - `Right(void)` on successful deletion.
  /// - `Left(StorageError)` if the deletion fails.
  Future<Either<StorageError, void>> delete(BoxType box, String key);

  /// Clears all data from the specified Hive box.
  ///
  /// The [box] parameter determines whether to clear the `normal` or `secure` box.
  ///
  /// Returns a `Future` that completes with an `Either`:
  /// - `Right(void)` on successful clear.
  /// - `Left(StorageError)` if the clear operation fails.
  Future<Either<StorageError, void>> clear(BoxType box);

  /// Encrypts and saves a file's bytes securely.
  ///
  /// This method takes the raw [fileBytes] and a [fileExtension], encrypts the
  /// data, and stores it. It returns metadata required for later retrieval.
  ///
  /// Returns a `Future` that completes with an `Either`:
  /// - `Right(Map<String, dynamic>)` containing the file metadata (e.g., path, key, nonce).
  /// - `Left(StorageError)` if the encryption or save operation fails.
  Future<Either<StorageError, Map<String, dynamic>>> saveSecureFile({
    required Uint8List fileBytes,
    required String fileExtension,
  });

  /// Retrieves and decrypts a secure file using its [fileMetadata].
  ///
  /// The [fileMetadata] map must contain all the necessary information to locate
  /// and decrypt the file, as provided by `saveSecureFile`.
  ///
  /// Returns a `Future` that completes with an `Either`:
  /// - `Right(Uint8List)` containing the decrypted file bytes.
  /// - `Left(StorageError)` if the retrieval or decryption fails.
  Future<Either<StorageError, Uint8List>> getSecureFile({
    required Map<String, dynamic> fileMetadata,
  });

  /// Deletes a secure file from storage using its [fileMetadata].
  ///
  /// Returns a `Future` that completes with an `Either`:
  /// - `Right(Unit)` on successful deletion.
  /// - `Left(StorageError)` if the deletion fails.
  Future<Either<StorageError, Unit>> deleteSecureFile({required Map<String, dynamic> fileMetadata});

  /// Disposes of all resources used by the vault storage.
  ///
  /// This should be called when the storage service is no longer needed to ensure
  /// that all resources, such as Hive boxes, are properly closed.
  ///
  /// Returns a `Future` that completes with an `Either`:
  /// - `Right(Unit)` on successful disposal.
  /// - `Left(StorageError)` if disposal fails.
  Future<Either<StorageError, Unit>> dispose();
}
