// Prefer web-safe default imports and gate native IO behind dart.library.io
import 'package:cryptography_plus/cryptography_plus.dart' show SecretBox;
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:vault_storage/src/entities/decrypt_request.dart';
import 'package:vault_storage/src/entities/encrypt_request.dart';
import 'package:vault_storage/src/entities/normal_file_request.dart';
import 'package:vault_storage/src/entities/secure_file_request.dart';
import 'package:vault_storage/src/entities/secure_file_stream_request.dart';
import 'package:vault_storage/src/enum/box_type.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/extensions/extensions.dart';
import 'package:vault_storage/src/interface/i_file_operations.dart';
import 'package:vault_storage/src/interface/i_secure_key_store.dart';
import 'package:vault_storage/src/mock/file_io_mock.dart' if (dart.library.io) 'dart:io';
import 'package:vault_storage/src/mock/path_provider_mock.dart'
    if (dart.library.io) 'package:path_provider/path_provider.dart';
import 'package:vault_storage/src/storage/encryption_helpers.dart';
import 'package:vault_storage/src/storage/file_download.dart';
import 'package:vault_storage/src/storage/file_metadata_keys.dart';
import 'package:vault_storage/src/storage/file_ref.dart';
import 'package:vault_storage/src/storage/secure_chunks.dart';

const _defaultChunkSize = 2 << 20;
const _secureBoxLocation = 'Hive secure files box';
const _secureDecodeContext = 'encrypted content';
const _normalBoxLocation = 'Hive normal files box';
const _normalDecodeContext = 'normal file content';

/// Handles file operations for both secure and normal files
class FileOperations implements IFileOperations {
  /// Creates a new [FileOperations] instance
  FileOperations();

  /// Save a secure (encrypted) file
  @override
  Future<Map<String, dynamic>> saveSecureFile(SecureFileRequest request) async {
    final SecureFileRequest(:fileBytes, :fileExtension, :services) = request;
    try {
      final fileId = services.uuid.v4();
      final secureKeyName = 'file_key_$fileId';
      final secretKey = await encryptionAlgorithm.newSecretKey();
      final keyBytes = await secretKey.extractBytes();

      final SecretBox secretBox = await compute(
        encryptInIsolate,
        EncryptRequest(fileBytes: fileBytes, keyBytes: keyBytes),
      );

      // Platform-aware saving logic
      String? filePath; // Nullable for web
      final useWeb = services.isWeb ?? kIsWeb;
      if (useWeb) {
        // WEB: Store encrypted bytes directly as Uint8List — no base64 overhead.
        await FileRef(
          fileId: fileId,
          useWeb: useWeb,
          getBox: services.getBox,
        ).lazyBox(.secureFiles).put(fileId, Uint8List.fromList(secretBox.cipherText));
      } else {
        // NATIVE: Use path_provider and dart:io to save to a file
        final dir = await getApplicationDocumentsDirectory();
        filePath = '${dir.path}/$fileId.$fileExtension.enc';
        await File(filePath).writeAsBytes(secretBox.cipherText, flush: true);
      }

      await services.secureStorage.write(
        key: secureKeyName,
        value: await keyBytes.encodeBase64Safely(context: 'encryption key'),
      );

      // Return unified metadata
      return {
        FileMetadataKeys.fileId: fileId,
        FileMetadataKeys.filePath: filePath,
        FileMetadataKeys.secureKeyName: secureKeyName,
        FileMetadataKeys.nonce: await secretBox.nonce.encodeBase64Safely(context: 'nonce'),
        FileMetadataKeys.mac: await secretBox.mac.bytes.encodeBase64Safely(context: 'MAC bytes'),
        FileMetadataKeys.extension: fileExtension,
      };
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageWriteError('Failed to save secure file', e),
        stackTrace,
      );
    }
  }

  /// Save a secure file from a stream with chunked AES-GCM encryption
  @override
  Future<Map<String, dynamic>> saveSecureFileStream(SecureFileStreamRequest request) async {
    final SecureFileStreamRequest(:stream, :fileExtension, :services, :chunkSize) = request;
    try {
      final fileId = services.uuid.v4();
      final secureKeyName = 'file_key_$fileId';
      final secretKey = await encryptionAlgorithm.newSecretKey();
      final keyBytes = await secretKey.extractBytes();
      final size = chunkSize ?? _defaultChunkSize;
      if (size <= 0) {
        throw VaultStorageWriteError('Chunk size must be positive, got $size');
      }

      final stored = await SecureChunks.write(
        StreamUpload(stream: stream, size: size, fileExtension: fileExtension, keyBytes: keyBytes),
        FileRef(fileId: fileId, useWeb: services.isWeb ?? kIsWeb, getBox: services.getBox),
      );

      await services.secureStorage.write(
        key: secureKeyName,
        value: await keyBytes.encodeBase64Safely(context: 'encryption key'),
      );

      return {
        FileMetadataKeys.fileId: fileId,
        FileMetadataKeys.filePath: stored.filePath,
        FileMetadataKeys.secureKeyName: secureKeyName,
        FileMetadataKeys.extension: fileExtension,
        FileMetadataKeys.streaming: true,
        FileMetadataKeys.chunkCount: stored.chunks.length,
        FileMetadataKeys.chunkSize: size,
        FileMetadataKeys.chunks: stored.chunks,
      };
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageWriteError('Failed to save secure file (stream)', e),
        stackTrace,
      );
    }
  }

  /// Retrieve a secure (encrypted) file using its metadata
  @override
  Future<Uint8List> getSecureFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required ISecureKeyStore secureStorage,
    required BoxBase<Object?> Function(BoxType) getBox,
    String? downloadFileName, // Optional filename for web downloads
  }) async {
    try {
      final fileId = fileMetadata.getRequiredString(FileMetadataKeys.fileId);
      final secureKeyName = fileMetadata.getRequiredString(FileMetadataKeys.secureKeyName);
      final useWeb = isWeb ?? kIsWeb;
      final file = FileRef(fileId: fileId, useWeb: useWeb, getBox: getBox);
      final decryptedBytes = fileMetadata[FileMetadataKeys.streaming] == true
          ? await _readStreamingSecureFile(fileMetadata, file, secureStorage, secureKeyName)
          : await _readSingleSecureFile(fileMetadata, file, secureStorage, secureKeyName);
      if (useWeb) {
        FileDownload(
          fileId: fileId,
          extension: fileMetadata.getOptionalString(FileMetadataKeys.extension),
          suffix: FileDownload.secureSuffix,
          downloadFileName: downloadFileName,
        ).start(decryptedBytes);
      }
      return decryptedBytes;
    } on VaultStorageError {
      rethrow;
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(VaultStorageReadError('Failed to read secure file', e), stackTrace);
    }
  }

  Future<Uint8List> _readStreamingSecureFile(
    Map<String, dynamic> fileMetadata,
    FileRef file,
    ISecureKeyStore secureStorage,
    String secureKeyName,
  ) async {
    final keyBytes = await _readEncryptionKey(secureStorage, secureKeyName);
    if (file.useWeb) return SecureChunks.readWeb(fileMetadata, file, keyBytes);
    return SecureChunks.readNative(fileMetadata, file, keyBytes);
  }

  Future<Uint8List> _readSingleSecureFile(
    Map<String, dynamic> fileMetadata,
    FileRef file,
    ISecureKeyStore secureStorage,
    String secureKeyName,
  ) async => compute(
    decryptInIsolate,
    DecryptRequest(
      encryptedBytes: file.useWeb
          ? await file.readWebBytes(
              .secureFiles,
              location: _secureBoxLocation,
              decodeContext: _secureDecodeContext,
            )
          : await (await file.existingFile(fileMetadata)).readAsBytes(),
      keyBytes: await _readEncryptionKey(secureStorage, secureKeyName),
      nonce: await fileMetadata
          .getRequiredString(FileMetadataKeys.nonce)
          .decodeBase64Safely(context: 'nonce'),
      macBytes: await fileMetadata
          .getRequiredString(FileMetadataKeys.mac)
          .decodeBase64Safely(context: 'MAC bytes'),
    ),
  );

  Future<List<int>> _readEncryptionKey(ISecureKeyStore secureStorage, String secureKeyName) async {
    final encodedKey = await secureStorage.read(key: secureKeyName);
    if (encodedKey == null) throw KeyNotFoundError(secureKeyName);
    return encodedKey.decodeBase64Safely(context: 'encryption key');
  }

  /// Delete a secure file and its associated encryption key
  @override
  Future<void> deleteSecureFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required ISecureKeyStore secureStorage,
    required BoxBase<Object?> Function(BoxType) getBox,
  }) async {
    try {
      final fileId = fileMetadata.getRequiredString(FileMetadataKeys.fileId);
      final secureKeyName = fileMetadata.getRequiredString(FileMetadataKeys.secureKeyName);
      final useWeb = isWeb ?? kIsWeb;
      final file = FileRef(fileId: fileId, useWeb: useWeb, getBox: getBox);
      if (fileMetadata[FileMetadataKeys.streaming] == true && useWeb) {
        await SecureChunks.deleteWeb(fileMetadata, file);
      } else {
        await file.deleteStored(fileMetadata, .secureFiles);
      }
      await secureStorage.delete(key: secureKeyName);
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageDeleteError('Failed to delete secure file', e),
        stackTrace,
      );
    }
  }

  /// Save a normal (unencrypted) file
  @override
  Future<Map<String, dynamic>> saveNormalFile(NormalFileRequest request) async {
    final NormalFileRequest(:fileBytes, :fileExtension, :services) = request;
    try {
      final fileId = services.uuid.v4();

      // Platform-aware saving logic
      String? filePath; // Nullable for web
      final useWeb = services.isWeb ?? kIsWeb;
      if (useWeb) {
        // WEB: Store bytes directly as Uint8List — no base64 overhead.
        await FileRef(
          fileId: fileId,
          useWeb: useWeb,
          getBox: services.getBox,
        ).lazyBox(.normalFiles).put(fileId, fileBytes);
      } else {
        // NATIVE: Use path_provider and dart:io to save to a file
        final dir = await getApplicationDocumentsDirectory();
        filePath = '${dir.path}/$fileId.$fileExtension';
        await File(filePath).writeAsBytes(fileBytes, flush: true);
      }

      // Return metadata
      return {
        FileMetadataKeys.fileId: fileId,
        FileMetadataKeys.filePath: filePath,
        FileMetadataKeys.extension: fileExtension,
      };
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageWriteError('Failed to save normal file', e),
        stackTrace,
      );
    }
  }

  /// Retrieve a normal (unencrypted) file using its metadata
  @override
  Future<Uint8List> getNormalFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required BoxBase<Object?> Function(BoxType) getBox,
    String? downloadFileName, // Optional filename for web downloads
  }) async {
    try {
      final fileId = fileMetadata.getRequiredString(FileMetadataKeys.fileId);
      final useWeb = isWeb ?? kIsWeb;
      final file = FileRef(fileId: fileId, useWeb: useWeb, getBox: getBox);
      final fileBytes = useWeb
          ? await file.readWebBytes(
              .normalFiles,
              location: _normalBoxLocation,
              decodeContext: _normalDecodeContext,
            )
          : await (await file.existingFile(fileMetadata)).readAsBytes();
      if (useWeb) {
        FileDownload(
          fileId: fileId,
          extension: fileMetadata.getOptionalString(FileMetadataKeys.extension),
          suffix: FileDownload.normalSuffix,
          downloadFileName: downloadFileName,
        ).start(fileBytes);
      }
      return fileBytes;
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageReadError('Failed to retrieve normal file', e),
        stackTrace,
      );
    }
  }

  /// Delete a normal file
  @override
  Future<void> deleteNormalFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required BoxBase<Object?> Function(BoxType) getBox,
  }) async {
    try {
      final fileId = fileMetadata.getRequiredString(FileMetadataKeys.fileId);
      await FileRef(
        fileId: fileId,
        useWeb: isWeb ?? kIsWeb,
        getBox: getBox,
      ).deleteStored(fileMetadata, .normalFiles);
    } catch (e, stackTrace) {
      if (e is VaultStorageError) rethrow;
      Error.throwWithStackTrace(
        VaultStorageDeleteError('Failed to delete normal file', e),
        stackTrace,
      );
    }
  }
}
