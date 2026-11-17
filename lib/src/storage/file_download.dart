import 'dart:typed_data' show Uint8List;

import 'package:vault_storage/src/storage/web_download_helper.dart'
    if (dart.library.io) 'package:vault_storage/src/mock/web_download_stub.dart';

/// A browser download of a stored file.
final class FileDownload {
  /// Creates a new [FileDownload].
  const FileDownload({
    required this.fileId,
    required this.extension,
    required this.suffix,
    required this.downloadFileName,
  });

  /// The name suffix of a download of a secure file.
  static const secureSuffix = '_secure_file';

  /// The name suffix of a download of a normal file.
  static const normalSuffix = '_file';

  static const _defaultName = 'bin';
  static const _defaultMimeType = 'application/octet-stream';
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

  /// The id of the downloaded file.
  final String fileId;

  /// The extension of the stored file, without a dot.
  final String? extension;

  /// The name suffix used when no [downloadFileName] is given.
  final String suffix;

  /// The name the caller asked for, if any.
  final String? downloadFileName;

  /// Downloads [fileBytes] under the chosen name.
  void start(Uint8List fileBytes) => downloadFileOnWeb(
    fileBytes: fileBytes,
    fileName: _name,
    mimeType: _mimeTypes[extension?.toLowerCase()] ?? _defaultMimeType,
  );

  String get _name => switch ((downloadFileName, extension)) {
    (final String name, _) => name,
    (_, final String ext) when ext.isNotEmpty => '$fileId$suffix.$ext',
    _ => '$fileId$suffix.$_defaultName',
  };
}
