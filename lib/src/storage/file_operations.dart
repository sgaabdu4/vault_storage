// Prefer web-safe default imports and gate native IO behind dart.library.io
import 'dart:typed_data' show BytesBuilder, Uint8List;

import 'package:cryptography_plus/cryptography_plus.dart' show SecretBox;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vault_storage/src/entities/decrypt_request.dart';
import 'package:vault_storage/src/entities/encrypt_request.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/extensions/extensions.dart';
import 'package:vault_storage/src/interface/i_file_operations.dart';
import 'package:vault_storage/src/mock/file_io_mock.dart' if (dart.library.io) 'dart:io';
import 'package:vault_storage/src/mock/path_provider_mock.dart'
    if (dart.library.io) 'package:path_provider/path_provider.dart';
import 'package:vault_storage/src/storage/encryption_helpers.dart';
import 'package:vault_storage/src/storage/web_download_helper.dart'
    if (dart.library.io) 'package:vault_storage/src/mock/web_download_stub.dart';

/// Handles file operations for both secure and normal files
///
/// This class is responsible for saving, retrieving, and deleting files,
/// with platform-specific implementations for web and native platforms.
class FileOperations implements IFileOperations {
  /// Creates a new [FileOperations] instance
  FileOperations();

  /// Save a secure (encrypted) file
  ///
  /// Returns metadata needed to retrieve the file later.
  /// Throws [VaultStorageError] if the operation fails.
  @override
  Future<Map<String, dynamic>> saveSecureFile({
    required Uint8List fileBytes,
    required String fileExtension,
    required bool? isWeb,
    required FlutterSecureStorage secureStorage,
    required Uuid uuid,
    required BoxBase<dynamic> Function(BoxType) getBox,
  }) async {
    try {
      final fileId = uuid.v4();
      final secureKeyName = 'file_key_$fileId';
      final secretKey = await encryptionAlgorithm.newSecretKey();
      final keyBytes = await secretKey.extractBytes();

      final SecretBox secretBox = await compute(
        encryptInIsolate,
        EncryptRequest(fileBytes: fileBytes, keyBytes: keyBytes),
      );

      // Platform-aware saving logic
      String? filePath; // Nullable for web
      if (isWeb ?? kIsWeb) {
        // WEB: Store encrypted bytes directly as Uint8List — no base64 overhead.
        await (getBox(BoxType.secureFiles) as LazyBox<dynamic>).put(
          fileId,
          Uint8List.fromList(secretBox.cipherText),
        );
      } else {
        // NATIVE: Use path_provider and dart:io to save to a file
        final dir = await getApplicationDocumentsDirectory();
        filePath = '${dir.path}/$fileId.$fileExtension.enc';
        await File(filePath).writeAsBytes(secretBox.cipherText, flush: true);
      }

      await secureStorage.write(
          key: secureKeyName, value: await keyBytes.encodeBase64Safely(context: 'encryption key'));

      // Return unified metadata
      return {
        'fileId': fileId, // The universal key for retrieval
        'filePath': filePath, // Path is only present on native platforms
        'secureKeyName': secureKeyName,
        'nonce': await secretBox.nonce.encodeBase64Safely(context: 'nonce'),
        'mac': await secretBox.mac.bytes.encodeBase64Safely(context: 'MAC bytes'),
        'extension': fileExtension, // Store the original extension
      };
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageWriteError('Failed to save secure file', e);
    }
  }

  /// Save a secure file from a stream with chunked AES-GCM encryption
  @override
  Future<Map<String, dynamic>> saveSecureFileStream({
    required Stream<List<int>> stream,
    required String fileExtension,
    required bool? isWeb,
    required FlutterSecureStorage secureStorage,
    required Uuid uuid,
    required BoxBase<dynamic> Function(BoxType) getBox,
    int? chunkSize,
  }) async {
    try {
      final fileId = uuid.v4();
      final secureKeyName = 'file_key_$fileId';
      final secretKey = await encryptionAlgorithm.newSecretKey();
      final keyBytes = await secretKey.extractBytes();

      // Chunk config – guard against zero/negative size to avoid infinite loop
      final size = chunkSize ?? (2 << 20); // 2MB default
      if (size <= 0) {
        throw VaultStorageWriteError('Chunk size must be positive, got $size');
      }
      final chunksMeta = <Map<String, dynamic>>[];

      // Native: framed single file for IO efficiency
      String? filePath;
      IOSink? sink;
      File? file;
      if (!(isWeb ?? kIsWeb)) {
        final dir = await getApplicationDocumentsDirectory();
        filePath = '${dir.path}/$fileId.$fileExtension.encf';
        file = File(filePath);
        sink = file.openWrite();
      }

      // Accumulator for chunking
      final buffer = BytesBuilder(copy: false);
      var chunkIndex = 0;
      await for (final part in stream) {
        buffer.add(part);
        while (buffer.length >= size) {
          final data = buffer.takeBytes();
          final toEncrypt = Uint8List.view(data.buffer, 0, size);

          final SecretBox secretBox = await compute(
            encryptInIsolate,
            EncryptRequest(fileBytes: toEncrypt, keyBytes: keyBytes),
          );

          final nonceB64 = await secretBox.nonce.encodeBase64Safely(context: 'chunk nonce');
          final macB64 = await secretBox.mac.bytes.encodeBase64Safely(context: 'chunk mac');

          if (isWeb ?? kIsWeb) {
            // WEB: Store chunk bytes directly as Uint8List — no base64 overhead.
            final key = '$fileId:c:$chunkIndex';
            await (getBox(BoxType.secureFiles) as LazyBox<dynamic>).put(
              key,
              Uint8List.fromList(secretBox.cipherText),
            );
          } else {
            // Write framed chunk: [len(4 bytes)][nonceLen(1)][nonce][macLen(1)][mac][ciphertext]
            final bytes = secretBox.cipherText;
            final header = BytesBuilder();
            final len = bytes.length;
            header.add([len >> 24 & 0xFF, len >> 16 & 0xFF, len >> 8 & 0xFF, len & 0xFF]);
            header.add([secretBox.nonce.length]);
            header.add(secretBox.nonce);
            header.add([secretBox.mac.bytes.length]);
            header.add(secretBox.mac.bytes);
            sink!.add(header.takeBytes());
            sink.add(bytes);
          }

          chunksMeta.add({
            'i': chunkIndex,
            'size': size,
            'nonce': nonceB64,
            'mac': macB64,
          });
          chunkIndex++;

          // If any remainder from data, re-add to buffer
          if (data.length > size) {
            buffer.add(Uint8List.view(data.buffer, size));
          }
        }
      }

      // Final small tail
      final tail = buffer.takeBytes();
      if (tail.isNotEmpty) {
        final SecretBox secretBox = await compute(
          encryptInIsolate,
          EncryptRequest(fileBytes: Uint8List.fromList(tail), keyBytes: keyBytes),
        );

        final nonceB64 = await secretBox.nonce.encodeBase64Safely(context: 'chunk nonce');
        final macB64 = await secretBox.mac.bytes.encodeBase64Safely(context: 'chunk mac');

        if (isWeb ?? kIsWeb) {
          // WEB: Store final chunk bytes directly as Uint8List.
          final key = '$fileId:c:$chunkIndex';
          await (getBox(BoxType.secureFiles) as LazyBox<dynamic>).put(
            key,
            Uint8List.fromList(secretBox.cipherText),
          );
        } else {
          final bytes = secretBox.cipherText;
          final header = BytesBuilder();
          final len = bytes.length;
          header.add([len >> 24 & 0xFF, len >> 16 & 0xFF, len >> 8 & 0xFF, len & 0xFF]);
          header.add([secretBox.nonce.length]);
          header.add(secretBox.nonce);
          header.add([secretBox.mac.bytes.length]);
          header.add(secretBox.mac.bytes);
          sink!.add(header.takeBytes());
          sink.add(bytes);
        }

        chunksMeta.add({
          'i': chunkIndex,
          'size': tail.length,
          'nonce': nonceB64,
          'mac': macB64,
        });
        chunkIndex++;
      }

      if (sink != null) {
        await sink.close();
      }

      await secureStorage.write(
          key: secureKeyName, value: await keyBytes.encodeBase64Safely(context: 'encryption key'));

      return {
        'fileId': fileId,
        'filePath': filePath,
        'secureKeyName': secureKeyName,
        'extension': fileExtension,
        'streaming': true,
        'chunkCount': chunkIndex,
        'chunkSize': size,
        'chunks': chunksMeta,
      };
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageWriteError('Failed to save secure file (stream)', e);
    }
  }

  /// Retrieve a secure (encrypted) file using its metadata
  ///
  /// Returns the decrypted file contents as a byte array.
  /// On web platforms, also triggers an automatic download.
  /// Throws [VaultStorageError] if the operation fails.
  @override
  Future<Uint8List> getSecureFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required FlutterSecureStorage secureStorage,
    required BoxBase<dynamic> Function(BoxType) getBox,
    String? downloadFileName, // Optional filename for web downloads
  }) async {
    try {
      // Extract required fields from metadata
      final fileId = fileMetadata.getRequiredString('fileId');
      final secureKeyName = fileMetadata.getRequiredString('secureKeyName');

      // Decode base64 values from metadata
      final nonce =
          await fileMetadata.getRequiredString('nonce').decodeBase64Safely(context: 'nonce');
      final macBytes =
          await fileMetadata.getRequiredString('mac').decodeBase64Safely(context: 'MAC bytes');

      // Streaming path
      if (fileMetadata['streaming'] == true) {
        final chunkCount = fileMetadata['chunkCount'] as int? ?? 0;
        final chunks = (fileMetadata['chunks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final out = BytesBuilder(copy: false);

        if (isWeb ?? kIsWeb) {
          // Read encryption key once before the loop
          final keyString = await secureStorage.read(key: secureKeyName);
          if (keyString == null) {
            throw KeyNotFoundError(secureKeyName);
          }
          final keyBytes = await keyString.decodeBase64Safely(context: 'encryption key');

          for (var i = 0; i < chunkCount; i++) {
            final entry = chunks[i];
            final nonceB =
                await entry.getRequiredString('nonce').decodeBase64Safely(context: 'chunk nonce');
            final macB =
                await entry.getRequiredString('mac').decodeBase64Safely(context: 'chunk mac');
            final key = '$fileId:c:$i';
            final storedChunk = await (getBox(BoxType.secureFiles) as LazyBox<dynamic>).get(key);
            if (storedChunk == null) {
              throw FileNotFoundError(fileId, 'Hive secure files chunk $i');
            }
            // Handle both Uint8List (v4.x) and base64 string (v3.x legacy).
            final enc = storedChunk is Uint8List
                ? storedChunk
                : await (storedChunk as String).decodeBase64Safely(context: 'encrypted chunk');
            final dec = await compute(
              decryptInIsolate,
              DecryptRequest(
                encryptedBytes: enc,
                keyBytes: keyBytes,
                nonce: nonceB,
                macBytes: macB,
              ),
            );
            out.add(dec);
          }
        } else {
          // Read framed chunks sequentially
          final filePath = fileMetadata.getOptionalString('filePath');
          if (filePath == null) {
            throw InvalidMetadataError('filePath');
          }
          final f = File(filePath);
          if (!await f.exists()) {
            throw FileNotFoundError(fileId, 'file system at path: $filePath');
          }
          final keyString = await secureStorage.read(key: secureKeyName);
          if (keyString == null) {
            throw KeyNotFoundError(secureKeyName);
          }
          final keyBytes = await keyString.decodeBase64Safely(context: 'encryption key');
          final raf = await f.open();
          try {
            while (true) {
              final header = await raf.read(4);
              if (header.isEmpty) break;
              final len = (header[0] << 24) | (header[1] << 16) | (header[2] << 8) | header[3];
              final nLenB = await raf.read(1);
              final nLen = nLenB[0];
              final nonceB = await raf.read(nLen);
              final mLenB = await raf.read(1);
              final mLen = mLenB[0];
              final macB = await raf.read(mLen);
              final enc = await raf.read(len);
              final dec = await compute(
                decryptInIsolate,
                DecryptRequest(
                  encryptedBytes: enc,
                  keyBytes: keyBytes,
                  nonce: nonceB,
                  macBytes: macB,
                ),
              );
              out.add(dec);
            }
          } finally {
            await raf.close();
          }
        }

        final decryptedBytes = out.takeBytes();

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
      }

      // Non-streaming legacy path
      Uint8List encryptedFileBytes;
      if (isWeb ?? kIsWeb) {
        final storedFile = await (getBox(BoxType.secureFiles) as LazyBox<dynamic>).get(fileId);
        if (storedFile == null) {
          throw FileNotFoundError(fileId, 'Hive secure files box');
        }
        // Handle both Uint8List (v4.x) and base64 string (v3.x legacy).
        encryptedFileBytes = storedFile is Uint8List
            ? storedFile
            : await (storedFile as String).decodeBase64Safely(context: 'encrypted content');
      } else {
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

      // Get the encryption key from secure storage after verifying presence
      final keyString = await secureStorage.read(key: secureKeyName);
      if (keyString == null) {
        throw KeyNotFoundError(secureKeyName);
      }
      final keyBytes = await keyString.decodeBase64Safely(context: 'encryption key');

      final decryptedBytes = await compute(
        decryptInIsolate,
        DecryptRequest(
          encryptedBytes: encryptedFileBytes,
          keyBytes: keyBytes,
          nonce: nonce,
          macBytes: macBytes,
        ),
      );

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
    } on VaultStorageError {
      rethrow;
    } catch (e) {
      throw VaultStorageReadError('Failed to read secure file', e);
    }
  }

  /// Delete a secure file and its associated encryption key
  /// Throws [VaultStorageError] if the operation fails.
  @override
  Future<void> deleteSecureFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required FlutterSecureStorage secureStorage,
    required BoxBase<dynamic> Function(BoxType) getBox,
  }) async {
    try {
      final fileId = fileMetadata.getRequiredString('fileId');
      final secureKeyName = fileMetadata.getRequiredString('secureKeyName');

      // Platform-aware deletion logic
      if (fileMetadata['streaming'] == true) {
        if (isWeb ?? kIsWeb) {
          final chunkCount = fileMetadata['chunkCount'] as int? ?? 0;
          for (var i = 0; i < chunkCount; i++) {
            await (getBox(BoxType.secureFiles) as LazyBox<dynamic>).delete('$fileId:c:$i');
          }
        } else {
          final filePath = fileMetadata.getOptionalString('filePath');
          if (filePath != null) {
            final file = File(filePath);
            if (await file.exists()) {
              await file.delete();
            }
          }
        }
      } else {
        if (isWeb ?? kIsWeb) {
          await (getBox(BoxType.secureFiles) as LazyBox<dynamic>).delete(fileId);
        } else {
          final filePath = fileMetadata.getOptionalString('filePath');
          if (filePath != null) {
            final file = File(filePath);
            if (await file.exists()) {
              await file.delete();
            }
          }
        }
      }

      // Delete the encryption key
      await secureStorage.delete(key: secureKeyName);
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageDeleteError('Failed to delete secure file', e);
    }
  }

  /// Save a normal (unencrypted) file
  ///
  /// Returns metadata needed to retrieve the file later.
  /// Throws [VaultStorageError] if the operation fails.
  @override
  Future<Map<String, dynamic>> saveNormalFile({
    required Uint8List fileBytes,
    required String fileExtension,
    required bool? isWeb,
    required Uuid uuid,
    required BoxBase<dynamic> Function(BoxType) getBox,
  }) async {
    try {
      final fileId = uuid.v4();

      // Platform-aware saving logic
      String? filePath; // Nullable for web
      if (isWeb ?? kIsWeb) {
        // WEB: Store bytes directly as Uint8List — no base64 overhead.
        await (getBox(BoxType.normalFiles) as LazyBox<dynamic>).put(fileId, fileBytes);
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
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageWriteError('Failed to save normal file', e);
    }
  }

  /// Retrieve a normal (unencrypted) file using its metadata
  ///
  /// Returns the file contents as a byte array.
  /// On web platforms, also triggers an automatic download.
  /// Throws [VaultStorageError] if the operation fails.
  @override
  Future<Uint8List> getNormalFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required BoxBase<dynamic> Function(BoxType) getBox,
    String? downloadFileName, // Optional filename for web downloads
  }) async {
    try {
      // Extract required fields from metadata
      final fileId = fileMetadata.getRequiredString('fileId');

      // Platform-aware retrieval logic
      if (isWeb ?? kIsWeb) {
        // WEB: Retrieve from Hive — handle Uint8List (v4.x) and base64 string (v3.x legacy).
        final stored = await (getBox(BoxType.normalFiles) as LazyBox<dynamic>).get(fileId);
        if (stored == null) {
          throw FileNotFoundError(fileId, 'Hive normal files box');
        }

        final fileBytes = stored is Uint8List
            ? stored
            : await (stored as String).decodeBase64Safely(context: 'normal file content');

        // Trigger download on web
        final extension = fileMetadata.getOptionalString('extension') ?? '';
        final fileName = downloadFileName ??
            (extension.isNotEmpty ? '${fileId}_file.$extension' : '${fileId}_file.bin');
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
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageReadError('Failed to retrieve normal file', e);
    }
  }

  /// Delete a normal file
  /// Throws [VaultStorageError] if the operation fails.
  @override
  Future<void> deleteNormalFile({
    required Map<String, dynamic> fileMetadata,
    required bool? isWeb,
    required BoxBase<dynamic> Function(BoxType) getBox,
  }) async {
    try {
      final fileId = fileMetadata.getRequiredString('fileId');

      // Platform-aware deletion
      if (isWeb ?? kIsWeb) {
        // WEB: Remove from Hive
        await (getBox(BoxType.normalFiles) as LazyBox<dynamic>).delete(fileId);
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
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageDeleteError('Failed to delete normal file', e);
    }
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
