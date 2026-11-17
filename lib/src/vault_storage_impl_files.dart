part of 'vault_storage_impl.dart';

typedef _FileRecord = Map<String, dynamic>;

final class _FileUpload {
  _FileUpload({
    required this.key,
    required this.fileBytes,
    String? originalFileName,
    Map<String, dynamic>? metadata,
  }) : extension =
           originalFileName?.split(StoredFileKeys.extensionSeparator).last ??
           StoredFileKeys.defaultExtension,
       userEntry = switch (metadata) {
         final user? => {StoredFileKeys.userMetadata: user},
         null => const <String, dynamic>{},
       };

  final String key;
  final Uint8List fileBytes;
  final String extension;
  final Map<String, dynamic> userEntry;

  _FileRecord tagged(Map<String, dynamic> stored, {required bool isSecure}) {
    return <String, dynamic>{...stored, StoredFileKeys.isSecure: isSecure, ...userEntry};
  }
}

AmbiguousKeyError _multiBoxMatch(String subject, String key, List<String> boxes) {
  const hint = StoredFileKeys.disambiguationHint;
  final message = '$subject "$key" found in multiple boxes: ${boxes.join(', ')}. $hint';
  return AmbiguousKeyError(key, boxes, message);
}

extension VaultStorageFiles on VaultStorageImpl {
  Future<Map<String, dynamic>> _storeSecureFileBytes(Uint8List fileBytes, String ext) async {
    final shouldStream = fileBytes.length >= _config.secureFileStreamingThresholdBytes;

    return shouldStream
        ? await _fileOperations.saveSecureFileStream(
            SecureFileStreamRequest(
              stream: .value(fileBytes),
              fileExtension: ext,
              services: _fileServices,
              chunkSize: _config.secureFileStreamingChunkSizeBytes,
            ),
          )
        : await _fileOperations.saveSecureFile(
            SecureFileRequest(fileBytes: fileBytes, fileExtension: ext, services: _fileServices),
          );
  }

  FileServices get _fileServices => FileServices(
    isWeb: kIsWeb,
    secureStorage: _secureStorage,
    uuid: _uuid,
    getBox: getInternalBox,
  );

  Future<void> _saveFileToCustomBox(String box, _FileUpload upload) async {
    final _FileUpload(:key, :fileBytes, :extension, :userEntry) = upload;
    final toStore = <String, dynamic>{
      StoredFileKeys.base64Data: await fileBytes.encodeBase64Safely(
        context: 'custom box file',
        config: _config,
      ),
      FileMetadataKeys.extension: extension,
      StoredFileKeys.isCustomBox: true,
      ...userEntry,
    };
    await _putInBoxBase(_requireCustomBox(box), key, toStore);
  }

  Future<Uint8List?> _getCustomFile(String box, String key) async {
    final metadata = await _getFromBoxBase<Map<String, dynamic>>(_requireCustomBox(box), key);
    if (metadata == null) return null;
    return _decodeCustomFile(_customFileEncoded(metadata, key));
  }

  String _customFileEncoded(Map<String, dynamic> metadata, String key) {
    final encoded = metadata[StoredFileKeys.base64Data];
    if (metadata[StoredFileKeys.isCustomBox] != true || encoded is! String) {
      throw VaultStorageReadError('Invalid custom box file metadata for "$key"');
    }
    return encoded;
  }

  Future<Uint8List> _decodeCustomFile(String encoded) =>
      encoded.decodeBase64Safely(context: 'custom box file', config: _config);

  Future<Uint8List> _readFileContent(Map<String, dynamic> metadata) {
    if (metadata[StoredFileKeys.isSecure] == true) {
      return _fileOperations.getSecureFile(
        fileMetadata: metadata,
        isWeb: kIsWeb,
        secureStorage: _secureStorage,
        getBox: getInternalBox,
      );
    }
    return _fileOperations.getNormalFile(
      fileMetadata: metadata,
      isWeb: kIsWeb,
      getBox: getInternalBox,
    );
  }

  Future<Uint8List?> _findFileContent(String key) async {
    final [normal, secure] = await Future.wait([
      getFileMetadata(key, isSecure: false),
      getFileMetadata(key, isSecure: true),
    ]);
    final customEntries = customBoxes.entries.toList();
    final customMetadata = await mapWithConcurrency(
      customEntries,
      _customBoxReadConcurrency,
      (entry) => _getFromBoxBase<Map<String, dynamic>>(entry.value, key),
    );
    final customMatches = [
      for (final (index, entry) in customEntries.indexed)
        if (customMetadata[index] case final metadata?
            when metadata[StoredFileKeys.isCustomBox] == true)
          (box: entry.key, encoded: _customFileEncoded(metadata, key)),
    ];

    final locations = [
      if (normal.isNotEmpty) StoredFileKeys.normalFilesLocation,
      if (secure.isNotEmpty) StoredFileKeys.secureFilesLocation,
      for (final match in customMatches) match.box,
    ];
    if (locations.length > 1) throw _multiBoxMatch('File key', key, locations);

    if (customMatches case [(:final encoded, box: _)]) return _decodeCustomFile(encoded);
    final metadata = secure.isNotEmpty ? secure : normal;
    return metadata.isEmpty ? null : await _readFileContent(metadata);
  }
}
