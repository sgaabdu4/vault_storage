/// Mock implementation for `dart:io` File operations on the web.
library;

import 'dart:typed_data';

import 'package:vault_storage/src/errors/storage_error.dart';

/// Minimal stub of Directory used where dart:io is not available.
abstract interface class Directory {
  String get path;
}

/// Mock File class for web platform where dart:io is not available
class File {
  final String path;

  File(this.path);

  Future<bool> exists() async {
    throw const UnsupportedPlatformError('File operations are not supported on the web.');
  }

  Future<Uint8List> readAsBytes() async {
    throw const UnsupportedPlatformError('File operations are not supported on the web.');
  }

  Future<void> writeAsBytes(List<int> bytes, {bool flush = false}) async {
    throw const UnsupportedPlatformError('File operations are not supported on the web.');
  }

  Future<void> delete() async {
    throw const UnsupportedPlatformError('File operations are not supported on the web.');
  }

  // Added to satisfy conditional usage on native platforms
  IOSink openWrite() {
    throw const UnsupportedPlatformError('File operations are not supported on the web.');
  }

  Future<RandomAccessFile> open() async {
    throw const UnsupportedPlatformError('File operations are not supported on the web.');
  }
}

/// Minimal stub of IOSink used in native-only code paths.
class IOSink {
  void add(List<int> data) {
    throw const UnsupportedPlatformError('File operations are not supported on the web.');
  }

  Future<void> close() async {
    throw const UnsupportedPlatformError('File operations are not supported on the web.');
  }
}

/// Minimal stub of RandomAccessFile used in native-only code paths.
class RandomAccessFile {
  Future<Uint8List> read(int bytes) async {
    throw const UnsupportedPlatformError('File operations are not supported on the web.');
  }

  Future<void> close() async {
    throw const UnsupportedPlatformError('File operations are not supported on the web.');
  }
}
