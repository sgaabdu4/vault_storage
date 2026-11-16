import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:vault_storage/src/extensions/extensions.dart';
import 'package:vault_storage/src/storage/file_metadata_keys.dart';
import 'package:vault_storage/src/storage/file_ref.dart';

/// The file and key name that a secure file operation works on.
final class SecureTarget {
  SecureTarget.of(Map<String, dynamic> metadata, bool? isWeb, BoxResolver getBox)
    : file = FileRef(
        fileId: metadata.getRequiredString(FileMetadataKeys.fileId),
        useWeb: isWeb ?? kIsWeb,
        getBox: getBox,
      ),
      secureKeyName = metadata.getRequiredString(FileMetadataKeys.secureKeyName);

  /// The file to read or delete.
  final FileRef file;

  /// The name of the secure storage entry that holds the file key.
  final String secureKeyName;

  /// Whether the file data lives in a box instead of the file system.
  bool get useWeb => file.useWeb;
}
