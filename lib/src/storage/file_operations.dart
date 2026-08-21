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
        await _writeCiphertext(filePath, secretBox.cipherText);
      }

      await secureStorage.write(
        key: secureKeyName,
        value: await keyBytes.encodeBase64Safely(context: 'encryption key'),
      );

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
      final size = chunkSize ?? (2 << 20);
      if (size <= 0) {
        throw VaultStorageWriteError('Chunk size must be positive, got $size');
      }

      final useWeb = isWeb ?? kIsWeb;
      final chunksMeta = <Map<String, dynamic>>[];
      String? filePath;
      IOSink? sink;
      if (!useWeb) {
        final dir = await getApplicationDocumentsDirectory();
        filePath = '${dir.path}/$fileId.$fileExtension.encf';
        sink = File(filePath).openWrite();
      }

      final buffer = BytesBuilder(copy: false);
      var chunkIndex = 0;
      try {
        await for (final part in stream) {
          buffer.add(part);
          while (buffer.length >= size) {
            final data = buffer.takeBytes();
            chunksMeta.add(
              await _encryptAndStoreChunk(
                bytes: Uint8List.sublistView(data, 0, size),
                keyBytes: keyBytes,
                fileId: fileId,
                chunkIndex: chunkIndex,
                useWeb: useWeb,
                getBox: getBox,
                sink: sink,
              ),
            );
            chunkIndex++;
            if (data.length > size) {
              buffer.add(Uint8List.sublistView(data, size));
            }
          }
        }
        final tail = buffer.takeBytes();
        if (tail.isNotEmpty) {
          chunksMeta.add(
            await _encryptAndStoreChunk(
              bytes: Uint8List.fromList(tail),
              keyBytes: keyBytes,
              fileId: fileId,
              chunkIndex: chunkIndex,
              useWeb: useWeb,
              getBox: getBox,
              sink: sink,
            ),
          );
          chunkIndex++;
        }
      } finally {
        await sink?.close();
      }

      await secureStorage.write(
        key: secureKeyName,
        value: await keyBytes.encodeBase64Safely(context: 'encryption key'),
      );

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

  Future<Map<String, dynamic>> _encryptAndStoreChunk({
    required Uint8List bytes,
    required List<int> keyBytes,
    required String fileId,
    required int chunkIndex,
    required bool useWeb,
    required BoxBase<dynamic> Function(BoxType) getBox,
    required IOSink? sink,
  }) async {
    final encryptedPayload = await compute(
      encryptInIsolate,
      EncryptRequest(fileBytes: bytes, keyBytes: keyBytes),
    );
    if (useWeb) {
      await (getBox(BoxType.secureFiles) as LazyBox<dynamic>).put(
        '$fileId:c:$chunkIndex',
        Uint8List.fromList(encryptedPayload.cipherText),
      );
    } else {
      _writeFramedChunk(sink!, encryptedPayload);
    }
    return {
      'i': chunkIndex,
      'size': bytes.length,
      'nonce': await encryptedPayload.nonce.encodeBase64Safely(context: 'chunk nonce'),
      'mac': await encryptedPayload.mac.bytes.encodeBase64Safely(context: 'chunk mac'),
    };
  }

  void _writeFramedChunk(IOSink sink, SecretBox encryptedPayload) {
    final bytes = encryptedPayload.cipherText;
    final length = bytes.length;
    final header = BytesBuilder()
      ..add([length >> 24 & 0xFF, length >> 16 & 0xFF, length >> 8 & 0xFF, length & 0xFF])
      ..add([encryptedPayload.nonce.length])
      ..add(encryptedPayload.nonce)
      ..add([encryptedPayload.mac.bytes.length])
      ..add(encryptedPayload.mac.bytes);
    sink
      ..add(header.takeBytes())
      ..add(bytes);
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
      final fileId = fileMetadata.getRequiredString('fileId');
      final secureKeyName = fileMetadata.getRequiredString('secureKeyName');
      final useWeb = isWeb ?? kIsWeb;
      final decryptedBytes = fileMetadata['streaming'] == true
          ? await _readStreamingSecureFile(
              fileMetadata: fileMetadata,
              fileId: fileId,
              secureKeyName: secureKeyName,
              useWeb: useWeb,
              secureStorage: secureStorage,
              getBox: getBox,
            )
          : await _readSingleSecureFile(
              fileMetadata: fileMetadata,
              fileId: fileId,
              secureKeyName: secureKeyName,
              useWeb: useWeb,
              secureStorage: secureStorage,
              getBox: getBox,
            );
      if (useWeb) {
        _downloadFile(
          fileBytes: decryptedBytes,
          fileId: fileId,
          extension: fileMetadata.getOptionalString('extension') ?? '',
          secure: true,
          downloadFileName: downloadFileName,
        );
      }
      return decryptedBytes;
    } on VaultStorageError {
      rethrow;
    } catch (e) {
      throw VaultStorageReadError('Failed to read secure file', e);
    }
  }

  Future<Uint8List> _readStreamingSecureFile({
    required Map<String, dynamic> fileMetadata,
    required String fileId,
    required String secureKeyName,
    required bool useWeb,
    required FlutterSecureStorage secureStorage,
    required BoxBase<dynamic> Function(BoxType) getBox,
  }) async {
    final keyBytes = await _readEncryptionKey(secureStorage, secureKeyName);
    if (useWeb) {
      return _readWebSecureChunks(
        fileMetadata: fileMetadata,
        fileId: fileId,
        keyBytes: keyBytes,
        getBox: getBox,
      );
    }
    return _readNativeSecureChunks(fileMetadata: fileMetadata, fileId: fileId, keyBytes: keyBytes);
  }

  Future<Uint8List> _readWebSecureChunks({
    required Map<String, dynamic> fileMetadata,
    required String fileId,
    required List<int> keyBytes,
    required BoxBase<dynamic> Function(BoxType) getBox,
  }) async {
    final chunkCount = fileMetadata['chunkCount'] as int? ?? 0;
    final chunks = (fileMetadata['chunks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final output = BytesBuilder(copy: false);
    for (var index = 0; index < chunkCount; index++) {
      final stored = await (getBox(BoxType.secureFiles) as LazyBox<dynamic>).get(
        '$fileId:c:$index',
      );
      if (stored == null) {
        throw FileNotFoundError(fileId, 'Hive secure files chunk $index');
      }
      output.add(
        await _decryptChunk(
          encryptedBytes: stored is Uint8List
              ? stored
              : await (stored as String).decodeBase64Safely(context: 'encrypted chunk'),
          keyBytes: keyBytes,
          metadata: chunks[index],
        ),
      );
    }
    return output.takeBytes();
  }

  Future<Uint8List> _readNativeSecureChunks({
    required Map<String, dynamic> fileMetadata,
    required String fileId,
    required List<int> keyBytes,
  }) async {
    final file = await _existingFile(fileMetadata, fileId);
    final output = BytesBuilder(copy: false);
    final reader = await file.open();
    try {
      while (true) {
        final lengthBytes = await reader.read(4);
        if (lengthBytes.isEmpty) break;
        final length =
            (lengthBytes[0] << 24) |
            (lengthBytes[1] << 16) |
            (lengthBytes[2] << 8) |
            lengthBytes[3];
        final nonce = await reader.read((await reader.read(1))[0]);
        final mac = await reader.read((await reader.read(1))[0]);
        output.add(
          await compute(
            decryptInIsolate,
            DecryptRequest(
              encryptedBytes: await reader.read(length),
              keyBytes: keyBytes,
              nonce: nonce,
              macBytes: mac,
            ),
          ),
        );
      }
    } finally {
      await reader.close();
    }
    return output.takeBytes();
  }

  Future<Uint8List> _decryptChunk({
    required Uint8List encryptedBytes,
    required List<int> keyBytes,
    required Map<String, dynamic> metadata,
  }) async => compute(
    decryptInIsolate,
    DecryptRequest(
      encryptedBytes: encryptedBytes,
      keyBytes: keyBytes,
      nonce: await metadata.getRequiredString('nonce').decodeBase64Safely(context: 'chunk nonce'),
      macBytes: await metadata.getRequiredString('mac').decodeBase64Safely(context: 'chunk mac'),
    ),
  );

  Future<Uint8List> _readSingleSecureFile({
    required Map<String, dynamic> fileMetadata,
    required String fileId,
    required String secureKeyName,
    required bool useWeb,
    required FlutterSecureStorage secureStorage,
    required BoxBase<dynamic> Function(BoxType) getBox,
  }) async => compute(
    decryptInIsolate,
    DecryptRequest(
      encryptedBytes: useWeb
          ? await _readWebFileBytes(
              fileId: fileId,
              boxType: BoxType.secureFiles,
              location: 'Hive secure files box',
              decodeContext: 'encrypted content',
              getBox: getBox,
            )
          : await (await _existingFile(fileMetadata, fileId)).readAsBytes(),
      keyBytes: await _readEncryptionKey(secureStorage, secureKeyName),
      nonce: await fileMetadata.getRequiredString('nonce').decodeBase64Safely(context: 'nonce'),
      macBytes: await fileMetadata
          .getRequiredString('mac')
          .decodeBase64Safely(context: 'MAC bytes'),
    ),
  );

  Future<List<int>> _readEncryptionKey(
    FlutterSecureStorage secureStorage,
    String secureKeyName,
  ) async {
    final encodedKey = await secureStorage.read(key: secureKeyName);
    if (encodedKey == null) throw KeyNotFoundError(secureKeyName);
    return encodedKey.decodeBase64Safely(context: 'encryption key');
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
      final useWeb = isWeb ?? kIsWeb;
      if (fileMetadata['streaming'] == true && useWeb) {
        await _deleteWebChunks(fileMetadata, fileId, getBox);
      } else {
        await _deleteStoredFile(
          fileMetadata: fileMetadata,
          fileId: fileId,
          useWeb: useWeb,
          boxType: BoxType.secureFiles,
          getBox: getBox,
        );
      }
      await secureStorage.delete(key: secureKeyName);
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageDeleteError('Failed to delete secure file', e);
    }
  }

  Future<void> _deleteWebChunks(
    Map<String, dynamic> fileMetadata,
    String fileId,
    BoxBase<dynamic> Function(BoxType) getBox,
  ) async {
    final box = getBox(BoxType.secureFiles) as LazyBox<dynamic>;
    final chunkCount = fileMetadata['chunkCount'] as int? ?? 0;
    await Future.wait([
      for (var index = 0; index < chunkCount; index++) box.delete('$fileId:c:$index'),
    ]);
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
      return {'fileId': fileId, 'filePath': filePath, 'extension': fileExtension};
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
      final fileId = fileMetadata.getRequiredString('fileId');
      final useWeb = isWeb ?? kIsWeb;
      final fileBytes = useWeb
          ? await _readWebFileBytes(
              fileId: fileId,
              boxType: BoxType.normalFiles,
              location: 'Hive normal files box',
              decodeContext: 'normal file content',
              getBox: getBox,
            )
          : await (await _existingFile(fileMetadata, fileId)).readAsBytes();
      if (useWeb) {
        _downloadFile(
          fileBytes: fileBytes,
          fileId: fileId,
          extension: fileMetadata.getOptionalString('extension') ?? '',
          secure: false,
          downloadFileName: downloadFileName,
        );
      }
      return fileBytes;
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
      await _deleteStoredFile(
        fileMetadata: fileMetadata,
        fileId: fileId,
        useWeb: isWeb ?? kIsWeb,
        boxType: BoxType.normalFiles,
        getBox: getBox,
      );
    } catch (e) {
      if (e is VaultStorageError) rethrow;
      throw VaultStorageDeleteError('Failed to delete normal file', e);
    }
  }

  Future<void> _deleteStoredFile({
    required Map<String, dynamic> fileMetadata,
    required String fileId,
    required bool useWeb,
    required BoxType boxType,
    required BoxBase<dynamic> Function(BoxType) getBox,
  }) async {
    if (useWeb) {
      await (getBox(boxType) as LazyBox<dynamic>).delete(fileId);
      return;
    }
    final filePath = fileMetadata.getOptionalString('filePath');
    if (filePath == null) return;
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }

  Future<Uint8List> _readWebFileBytes({
    required String fileId,
    required BoxType boxType,
    required String location,
    required String decodeContext,
    required BoxBase<dynamic> Function(BoxType) getBox,
  }) async {
    final stored = await (getBox(boxType) as LazyBox<dynamic>).get(fileId);
    if (stored == null) throw FileNotFoundError(fileId, location);
    return stored is Uint8List
        ? stored
        : (stored as String).decodeBase64Safely(context: decodeContext);
  }

  Future<File> _existingFile(Map<String, dynamic> fileMetadata, String fileId) async {
    final filePath = fileMetadata.getOptionalString('filePath');
    if (filePath == null) throw InvalidMetadataError('filePath');
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileNotFoundError(fileId, 'file system at path: $filePath');
    }
    return file;
  }

  void _downloadFile({
    required Uint8List fileBytes,
    required String fileId,
    required String extension,
    required bool secure,
    required String? downloadFileName,
  }) {
    final suffix = secure ? '_secure_file' : '_file';
    final fileName =
        downloadFileName ??
        (extension.isNotEmpty ? '$fileId$suffix.$extension' : '$fileId$suffix.bin');
    downloadFileOnWeb(
      fileBytes: fileBytes,
      fileName: fileName,
      mimeType: _getMimeTypeFromExtension(extension),
    );
  }

  Future<void> _writeCiphertext(String filePath, List<int> ciphertext) =>
      File(filePath).writeAsBytes(ciphertext, flush: true);

  static const _mimeTypes = <String, String>{
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'json': 'application/json',
    'xml': 'application/xml',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'svg': 'image/svg+xml',
    'mp4': 'video/mp4',
    'avi': 'video/x-msvideo',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'zip': 'application/zip',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };

  String _getMimeTypeFromExtension(String extension) =>
      _mimeTypes[extension.toLowerCase()] ?? 'application/octet-stream';
}
