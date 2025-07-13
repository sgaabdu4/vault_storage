import 'dart:io'
    if (dart.library.js_interop) 'package:vault_storage/src/mock/file_io_mock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart'
    if (dart.library.js_interop) 'package:vault_storage/src/mock/path_provider_mock.dart';
import 'package:uuid/uuid.dart';
import 'package:vault_storage/src/storage/web_download_helper.dart'
    if (dart.library.io) 'package:vault_storage/src/mock/web_download_stub.dart';

import 'package:vault_storage/src/entities/decrypt_request.dart';
import 'package:vault_storage/src/entities/encrypt_request.dart';
import 'package:vault_storage/src/enum/internal_storage_box_type.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/extensions/extensions.dart';
import 'package:vault_storage/src/storage/encryption_helpers.dart';
import 'package:vault_storage/src/storage/task_execution.dart';

/// Handles file operations for both secure and normal files
///
/// This class is responsible for saving, retrieving, and deleting files,
/// with platform-specific implementations for web and native platforms.
class FileOperations {
  final TaskExecutor _taskExecutor;

  /// Creates a new [FileOperations] instance
  FileOperations({TaskExecutor? taskExecutor})
      : _taskExecutor = taskExecutor ?? TaskExecutor();

  /// Save a secure (encrypted) file
  ///
  /// Returns metadata needed to retrieve the file later.
  Future<Either<StorageError, Map<String, dynamic>>> saveSecureFile({
    required Uint8List fileBytes,
    required String fileExtension,
    required bool? isWeb,
    required FlutterSecureStorage secureStorage,
    required Uuid uuid,
    required Box<dynamic> Function(InternalBoxType) getBox,
    required bool isStorageReady,
  }) {
    final operation =
        TaskEither<StorageError, Map<String, dynamic>>.tryCatch(() async {
      final fileId = uuid.v4();
      final secureKeyName = 'file_key_$fileId';
      final secretKey = await encryptionAlgorithm.newSecretKey();
      final keyBytes = await secretKey.extractBytes();

      final secretBox = await compute(
        encryptInIsolate,
        EncryptRequest(fileBytes: fileBytes, keyBytes: keyBytes),
      );

      // Platform-aware saving logic
      String? filePath; // Nullable for web
      if (isWeb ?? kIsWeb) {
        // WEB: Store the encrypted bytes directly in Hive as a base64 string
        final encryptedContentBase64 = secretBox.cipherText.encodeBase64();
        await getBox(InternalBoxType.secureFiles).put(fileId, encryptedContentBase64);
      } else {
        // NATIVE: Use path_provider and dart:io to save to a file
        final dir = await getApplicationDocumentsDirectory();
        filePath = '${dir.path}/$fileId.$fileExtension.enc';
        await File(filePath).writeAsBytes(secretBox.cipherText, flush: true);
      }

      await secureStorage.write(
          key: secureKeyName, value: keyBytes.encodeBase64());

      // Return unified metadata
      return {
        'fileId': fileId, // The universal key for retrieval
        'filePath': filePath, // Path is only present on native platforms
        'secureKeyName': secureKeyName,
        'nonce': secretBox.nonce.encodeBase64(),
        'mac': secretBox.mac.bytes.encodeBase64(),
        'extension': fileExtension, // Store the original extension
      };
    }, (e, _) => StorageWriteError('Failed to save secure file', e));

    return _taskExecutor.executeTask(operation, isStorageReady: isStorageReady);
  }

  /// Retrieve a secure (encrypted) file using its metadata
  ///
  /// Returns the decrypted file contents as a byte array.
  /// On web platforms, also triggers an automatic download.
  Future<Either<StorageError, Uint8List>> getSecureFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required FlutterSecureStorage secureStorage,
    required Box<dynamic> Function(InternalBoxType) getBox,
    required bool isStorageReady,
    String? downloadFileName, // Optional filename for web downloads
  }) {
    final operation = TaskEither<StorageError, Uint8List>.tryCatch(() async {
      // Extract required fields from metadata
      final fileId = fileMetadata.getRequiredString('fileId');
      final secureKeyName = fileMetadata.getRequiredString('secureKeyName');

      // Decode base64 values from metadata
      final nonceResult = fileMetadata
          .getRequiredString('nonce')
          .decodeBase64Safely(context: 'nonce');
      final macResult = fileMetadata
          .getRequiredString('mac')
          .decodeBase64Safely(context: 'MAC bytes');

      // Extract the bytes using fold
      final nonce = nonceResult.fold((error) => throw error, (bytes) => bytes);
      final macBytes = macResult.fold((error) => throw error, (bytes) => bytes);

      // Platform-aware retrieval logic
      Uint8List encryptedFileBytes;
      if (isWeb ?? kIsWeb) {
        // WEB: Retrieve from Hive and decode from base64
        final encryptedContentBase64 =
            getBox(InternalBoxType.secureFiles).get(fileId) as String?;
        if (encryptedContentBase64 == null) {
          throw FileNotFoundError(fileId, 'Hive secure files box');
        }

        final contentResult = encryptedContentBase64.decodeBase64Safely(
            context: 'encrypted content');
        encryptedFileBytes =
            contentResult.fold((error) => throw error, (bytes) => bytes);
      } else {
        // NATIVE: Retrieve from file system
        final filePath = fileMetadata.getOptionalString('filePath');
        if (filePath == null) {
          throw InvalidMetadataError('filePath');
        }

        final file = File(filePath);
        if (!await file.exists()) {
          throw FileNotFoundError(fileId, 'file system at path: $filePath');
        }

        encryptedFileBytes = await file.readAsBytes();
      }

      // Get the encryption key from secure storage
      final keyString = await secureStorage.read(key: secureKeyName);
      if (keyString == null) {
        throw KeyNotFoundError(secureKeyName);
      }

      final keyResult = keyString.decodeBase64Safely(context: 'encryption key');
      final keyBytes = keyResult.fold((error) => throw error, (bytes) => bytes);

      // Decrypt the file data
      final decryptedBytes = await compute(
        decryptInIsolate,
        DecryptRequest(
          encryptedBytes: encryptedFileBytes,
          keyBytes: keyBytes,
          nonce: nonce,
          macBytes: macBytes,
        ),
      );

      // Trigger download on web platforms
      if (isWeb ?? kIsWeb) {
        final extension = fileMetadata.getOptionalString('extension') ?? '';
        final fileName = downloadFileName ??
            (extension.isNotEmpty
                ? '${fileId}_secure_file.$extension'
                : '${fileId}_secure_file.bin');
        downloadFileOnWeb(
          fileBytes: decryptedBytes,
          fileName: fileName,
          mimeType: _getMimeTypeFromExtension(extension),
        );
      }

      return decryptedBytes;
    },
        (e, _) => e is StorageError
            ? e
            : StorageReadError('Failed to read secure file', e));

    return _taskExecutor.executeTask(operation, isStorageReady: isStorageReady);
  }

  /// Delete a secure file and its associated encryption key
  Future<Either<StorageError, Unit>> deleteSecureFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required FlutterSecureStorage secureStorage,
    required Box<dynamic> Function(InternalBoxType) getBox,
    required bool isStorageReady,
  }) {
    final operation = TaskEither<StorageError, Unit>.tryCatch(() async {
      final fileId = fileMetadata.getRequiredString('fileId');
      final secureKeyName = fileMetadata.getRequiredString('secureKeyName');

      // Platform-aware deletion logic
      if (isWeb ?? kIsWeb) {
        // WEB: Delete from Hive
        await getBox(InternalBoxType.secureFiles).delete(fileId);
      } else {
        // NATIVE: Delete from file system
        final filePath = fileMetadata.getOptionalString('filePath');
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }

      // Delete the encryption key
      await secureStorage.delete(key: secureKeyName);
      return unit;
    }, (e, _) => StorageDeleteError('Failed to delete secure file', e));

    return _taskExecutor.executeTask(operation, isStorageReady: isStorageReady);
  }

  /// Save a normal (unencrypted) file
  ///
  /// Returns metadata needed to retrieve the file later.
  Future<Either<StorageError, Map<String, dynamic>>> saveNormalFile({
    required Uint8List fileBytes,
    required String fileExtension,
    required bool? isWeb,
    required Uuid uuid,
    required Box<dynamic> Function(InternalBoxType) getBox,
    required bool isStorageReady,
  }) {
    final operation =
        TaskEither<StorageError, Map<String, dynamic>>.tryCatch(() async {
      final fileId = uuid.v4();

      // Platform-aware saving logic
      String? filePath; // Nullable for web
      if (isWeb ?? kIsWeb) {
        // WEB: Store the bytes directly in Hive as a base64 string
        final contentBase64 = fileBytes.encodeBase64();
        await getBox(InternalBoxType.normalFiles).put(fileId, contentBase64);
      } else {
        // NATIVE: Use path_provider and dart:io to save to a file
        final dir = await getApplicationDocumentsDirectory();
        filePath = '${dir.path}/$fileId.$fileExtension';
        await File(filePath).writeAsBytes(fileBytes, flush: true);
      }

      // Return metadata
      return {
        'fileId': fileId,
        'filePath': filePath,
        'extension': fileExtension,
      };
    }, (e, _) => StorageWriteError('Failed to save normal file', e));

    return _taskExecutor.executeTask(operation, isStorageReady: isStorageReady);
  }

  /// Retrieve a normal (unencrypted) file using its metadata
  ///
  /// Returns the file contents as a byte array.
  /// On web platforms, also triggers an automatic download.
  Future<Either<StorageError, Uint8List>> getNormalFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required Box<dynamic> Function(InternalBoxType) getBox,
    required bool isStorageReady,
    String? downloadFileName, // Optional filename for web downloads
  }) {
    final operation = TaskEither<StorageError, Uint8List>.tryCatch(() async {
      // Extract required fields from metadata
      final fileId = fileMetadata.getRequiredString('fileId');

      // Platform-aware retrieval logic
      if (isWeb ?? kIsWeb) {
        // WEB: Retrieve from Hive and decode from base64
        final contentBase64 =
            getBox(InternalBoxType.normalFiles).get(fileId) as String?;
        if (contentBase64 == null) {
          throw FileNotFoundError(fileId, 'Hive normal files box');
        }

        // Use our extension method for cleaner code
        final result =
            contentBase64.decodeBase64Safely(context: 'normal file content');
        final fileBytes = result.fold(
          (error) =>
              throw error, // Re-throw the Base64DecodeError to be caught by the outer tryCatch
          (bytes) => bytes,
        );

        // Trigger download on web
        final extension = fileMetadata.getOptionalString('extension') ?? '';
        final fileName = downloadFileName ??
            (extension.isNotEmpty
                ? '${fileId}_file.$extension'
                : '${fileId}_file.bin');
        downloadFileOnWeb(
          fileBytes: fileBytes,
          fileName: fileName,
          mimeType: _getMimeTypeFromExtension(extension),
        );

        return fileBytes;
      } else {
        // NATIVE: Retrieve from file system
        final filePath = fileMetadata.getOptionalString('filePath');
        if (filePath == null) {
          throw InvalidMetadataError('filePath');
        }

        final file = File(filePath);
        if (!await file.exists()) {
          throw FileNotFoundError(fileId, 'file system at path: $filePath');
        }

        return await file.readAsBytes();
      }
    },
        (e, _) => e is StorageError
            ? e
            : StorageReadError('Failed to retrieve normal file', e));

    return _taskExecutor.executeTask(operation, isStorageReady: isStorageReady);
  }

  /// Delete a normal file
  Future<Either<StorageError, Unit>> deleteNormalFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required Box<dynamic> Function(InternalBoxType) getBox,
    required bool isStorageReady,
  }) {
    final operation = TaskEither<StorageError, Unit>.tryCatch(() async {
      final fileId = fileMetadata.getRequiredString('fileId');

      // Platform-aware deletion
      if (isWeb ?? kIsWeb) {
        // WEB: Remove from Hive
        await getBox(InternalBoxType.normalFiles).delete(fileId);
      } else {
        // NATIVE: Delete the file from the file system
        final filePath = fileMetadata.getOptionalString('filePath');
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }

      return unit;
    }, (e, _) => StorageDeleteError('Failed to delete normal file', e));

    return _taskExecutor.executeTask(operation, isStorageReady: isStorageReady);
  }

  /// Helper method to determine MIME type from file extension
  String _getMimeTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'svg':
        return 'image/svg+xml';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'zip':
        return 'application/zip';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }
}
