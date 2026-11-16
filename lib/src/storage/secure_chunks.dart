import 'dart:typed_data' show ByteData, BytesBuilder, Uint8List;

import 'package:cryptography_plus/cryptography_plus.dart' show SecretBox;
import 'package:flutter/foundation.dart';
import 'package:vault_storage/src/constants/vault_storage_config.dart';
import 'package:vault_storage/src/entities/decrypt_request.dart';
import 'package:vault_storage/src/entities/encrypt_request.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/extensions/extensions.dart';
import 'package:vault_storage/src/mock/file_io_mock.dart' if (dart.library.io) 'dart:io';
import 'package:vault_storage/src/mock/path_provider_mock.dart'
    if (dart.library.io) 'package:path_provider/path_provider.dart';
import 'package:vault_storage/src/storage/encryption_helpers.dart';
import 'package:vault_storage/src/storage/file_metadata_keys.dart';
import 'package:vault_storage/src/storage/file_ref.dart';
import 'package:vault_storage/src/utils/concurrency.dart';

const _webChunkConcurrency = 4;
const _lengthFieldBytes = 4;
const _chunkDecodeContext = 'encrypted chunk';
const _chunkLocationPrefix = 'Hive secure files chunk';

/// A stream of plain bytes to store as encrypted chunks.
final class StreamUpload {
  /// Creates a new [StreamUpload].
  const StreamUpload({
    required this.stream,
    required this.size,
    required this.fileExtension,
    required this.keyBytes,
  });

  /// The plain bytes to encrypt.
  final Stream<List<int>> stream;

  /// The plain size of each chunk.
  final int size;

  /// The extension of the stored file, without a dot.
  final String fileExtension;

  /// The key that encrypts every chunk.
  final List<int> keyBytes;
}

/// Writes, reads and removes files stored as separately encrypted chunks.
abstract final class SecureChunks {
  /// Encrypts [upload] chunk by chunk into a file, or into boxes on the web.
  static Future<({String? filePath, List<Map<String, dynamic>> chunks})> write(
    StreamUpload upload,
    FileRef file,
  ) async {
    final StreamUpload(:fileExtension, :keyBytes, :size, :stream) = upload;
    String? filePath;
    IOSink? sink;
    if (!file.useWeb) {
      final dir = await getApplicationDocumentsDirectory();
      filePath = '${dir.path}/${file.fileId}.$fileExtension.encf';
      sink = File(filePath).openWrite();
    }
    final chunks = <Map<String, dynamic>>[];
    try {
      await for (final bytes in _fileChunks(stream, size)) {
        final chunkIndex = chunks.length;
        final encryptedPayload = await compute(
          encryptInIsolate,
          EncryptRequest(fileBytes: bytes, keyBytes: keyBytes),
        );
        if (sink case final IOSink target) {
          _writeFramedChunk(target, encryptedPayload);
        } else {
          await file
              .lazyBox(.secureFiles)
              .put(
                FileMetadataKeys.webChunk(file.fileId, chunkIndex),
                Uint8List.fromList(encryptedPayload.cipherText),
              );
        }
        chunks.add({
          FileMetadataKeys.chunkIndex: chunkIndex,
          FileMetadataKeys.chunkLength: bytes.length,
          FileMetadataKeys.nonce: encryptedPayload.nonce.encodeBase64SafelySync(
            context: 'chunk nonce',
          ),
          FileMetadataKeys.mac: encryptedPayload.mac.bytes.encodeBase64SafelySync(
            context: 'chunk mac',
          ),
        });
      }
    } finally {
      await sink?.close();
    }
    return (filePath: filePath, chunks: chunks);
  }

  /// Reads and decrypts every chunk of a file stored in boxes.
  static Future<Uint8List> readWeb(
    Map<String, dynamic> fileMetadata,
    FileRef file,
    List<int> keyBytes,
    VaultStorageConfig config,
  ) async {
    final chunks = switch (fileMetadata[FileMetadataKeys.chunks]) {
      final List<Object?> items => [
        for (final item in items)
          if (item case final Map<String, dynamic> chunk) chunk,
      ],
      _ => <Map<String, dynamic>>[],
    };
    final output = BytesBuilder(copy: false);
    final plainChunks = await mapWithConcurrency(
      List<int>.generate(_chunkCount(fileMetadata), (index) => index),
      _webChunkConcurrency,
      (index) async {
        final stored = await file
            .lazyBox(.secureFiles)
            .get(FileMetadataKeys.webChunk(file.fileId, index));
        if (stored == null) {
          throw FileNotFoundError(file.fileId, _chunkLocation(index));
        }
        return _decryptChunk(
          encryptedBytes: await file.storedBytes(stored, _chunkDecodeContext, config),
          keyBytes: keyBytes,
          metadata: chunks[index],
        );
      },
    );
    plainChunks.forEach(output.add);
    return output.takeBytes();
  }

  /// Reads and decrypts every chunk of a file stored in the file system.
  static Future<Uint8List> readNative(
    Map<String, dynamic> fileMetadata,
    FileRef file,
    List<int> keyBytes,
  ) async {
    final storedFile = await file.existingFile(fileMetadata);
    final output = BytesBuilder(copy: false);
    final reader = await storedFile.open();
    try {
      while (true) {
        final lengthBytes = await reader.read(_lengthFieldBytes);
        if (lengthBytes.isEmpty) break;
        final length = ByteData.sublistView(lengthBytes).getUint32(0);
        final nonce = await reader.read(await _readByte(reader));
        final mac = await reader.read(await _readByte(reader));
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

  /// Removes every chunk of a file stored in boxes.
  static Future<void> deleteWeb(Map<String, dynamic> fileMetadata, FileRef file) async {
    final box = file.lazyBox(.secureFiles);
    final chunkCount = _chunkCount(fileMetadata);
    await Future.wait([
      for (int index = 0; index < chunkCount; index++)
        box.delete(FileMetadataKeys.webChunk(file.fileId, index)),
    ]);
  }

  static String _chunkLocation(int index) => '$_chunkLocationPrefix $index';

  static int _chunkCount(Map<String, dynamic> fileMetadata) =>
      switch (fileMetadata[FileMetadataKeys.chunkCount]) {
        final int count => count,
        _ => 0,
      };

  static Stream<Uint8List> _fileChunks(Stream<List<int>> stream, int size) async* {
    final buffer = BytesBuilder(copy: false);
    await for (final part in stream) {
      buffer.add(part);
      while (buffer.length >= size) {
        final data = buffer.takeBytes();
        yield Uint8List.sublistView(data, 0, size);
        if (data.length > size) buffer.add(Uint8List.sublistView(data, size));
      }
    }
    final tail = buffer.takeBytes();
    if (tail.isNotEmpty) yield tail;
  }

  static void _writeFramedChunk(IOSink sink, SecretBox encryptedPayload) {
    final bytes = encryptedPayload.cipherText;
    final header = BytesBuilder()
      ..add((ByteData(_lengthFieldBytes)..setUint32(0, bytes.length)).buffer.asUint8List())
      ..addByte(encryptedPayload.nonce.length)
      ..add(encryptedPayload.nonce)
      ..addByte(encryptedPayload.mac.bytes.length)
      ..add(encryptedPayload.mac.bytes);
    sink
      ..add(header.takeBytes())
      ..add(bytes);
  }

  static Future<int> _readByte(RandomAccessFile reader) async => switch (await reader.read(1)) {
    [final byte] => byte,
    _ => throw const FormatException('Truncated secure file chunk header'),
  };

  static Future<Uint8List> _decryptChunk({
    required Uint8List encryptedBytes,
    required List<int> keyBytes,
    required Map<String, dynamic> metadata,
  }) => compute(
    decryptInIsolate,
    DecryptRequest(
      encryptedBytes: encryptedBytes,
      keyBytes: keyBytes,
      nonce: metadata
          .getRequiredString(FileMetadataKeys.nonce)
          .decodeBase64SafelySync(context: 'chunk nonce'),
      macBytes: metadata
          .getRequiredString(FileMetadataKeys.mac)
          .decodeBase64SafelySync(context: 'chunk mac'),
    ),
  );
}
