import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:vault_storage/src/enum/box_type.dart';
import 'package:vault_storage/src/interface/i_id_generator.dart';
import 'package:vault_storage/src/interface/i_secure_key_store.dart';

/// The collaborators a file save needs from the storage that owns the boxes.
final class FileServices {
  /// Creates a new [FileServices].
  const FileServices({
    required this.isWeb,
    required this.secureStorage,
    required this.uuid,
    required this.getBox,
  });

  /// Forces the web or native path; `null` follows the running platform.
  final bool? isWeb;

  /// Holds the per-file encryption keys.
  final ISecureKeyStore secureStorage;

  /// Creates the file ids.
  final IIdGenerator uuid;

  /// Resolves the box that holds a kind of file data.
  final BoxBase<Object?> Function(BoxType) getBox;
}
