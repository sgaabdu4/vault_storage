import 'dart:typed_data' show Uint8List;

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:vault_storage/src/enum/box_type.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/extensions/extensions.dart';
import 'package:vault_storage/src/mock/file_io_mock.dart' if (dart.library.io) 'dart:io';
import 'package:vault_storage/src/storage/file_metadata_keys.dart';

/// Resolves the box that holds a kind of file data.
typedef BoxResolver = BoxBase<Object?> Function(BoxType);

/// Where one stored file lives and how to reach its data.
final class FileRef {
  /// Creates a new [FileRef].
  const FileRef({required this.fileId, required this.useWeb, required this.getBox});

  /// The id of the file.
  final String fileId;

  /// Whether the file data lives in a box instead of the file system.
  final bool useWeb;

  /// Resolves the box that holds a kind of file data.
  final BoxResolver getBox;

  /// The lazy box for [boxType].
  LazyBox<Object?> lazyBox(BoxType boxType) {
    final box = getBox(boxType);
    if (box is LazyBox<Object?>) return box;
    throw VaultStorageInitializationError('Box $boxType is not a lazy box: ${box.runtimeType}');
  }

  /// The bytes stored in [boxType] for this file, from the web path.
  Future<Uint8List> readWebBytes(
    BoxType boxType, {
    required String location,
    required String decodeContext,
  }) async {
    final stored = await lazyBox(boxType).get(fileId);
    if (stored == null) throw FileNotFoundError(fileId, location);
    return storedBytes(stored, decodeContext);
  }

  /// The bytes of a value read from a box.
  Future<Uint8List> storedBytes(Object stored, String decodeContext) async {
    if (stored is Uint8List) return stored;
    if (stored is String) return stored.decodeBase64Safely(context: decodeContext);
    throw VaultStorageSerializationError('Unsupported stored file content: ${stored.runtimeType}');
  }

  /// The file named by [fileMetadata], which must exist.
  Future<File> existingFile(Map<String, dynamic> fileMetadata) async {
    final filePath = fileMetadata.getOptionalString(FileMetadataKeys.filePath);
    if (filePath == null) throw InvalidMetadataError(FileMetadataKeys.filePath);
    final file = File(filePath);
    if (!await file.exists()) throw FileNotFoundError(fileId, fileSystemLocation(filePath));
    return file;
  }

  /// Removes the stored data of this file from [boxType] or the file system.
  Future<void> deleteStored(Map<String, dynamic> fileMetadata, BoxType boxType) async {
    if (useWeb) {
      await lazyBox(boxType).delete(fileId);
      return;
    }
    final filePath = fileMetadata.getOptionalString(FileMetadataKeys.filePath);
    if (filePath == null) return;
    final target = File(filePath);
    if (await target.exists()) await target.delete();
  }

  /// The location text of a file system path in a not found error.
  static String fileSystemLocation(String filePath) => 'file system at path: $filePath';
}
