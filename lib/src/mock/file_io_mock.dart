/// Mock implementation for `dart:io` File operations on the web.
/// These should not be called on the web, and will throw if they are.
library;

import 'dart:typed_data';

/// Mock File class for web platform where dart:io is not available
class File {
  final String path;

  File(this.path);

  Future<bool> exists() async {
    throw UnsupportedError('File operations are not supported on the web.');
  }

  Future<Uint8List> readAsBytes() async {
    throw UnsupportedError('File operations are not supported on the web.');
  }

  Future<void> writeAsBytes(List<int> bytes, {bool flush = false}) async {
    throw UnsupportedError('File operations are not supported on the web.');
  }

  Future<void> delete() async {
    throw UnsupportedError('File operations are not supported on the web.');
  }

  // Added to satisfy conditional usage on native platforms
  IOSink openWrite() {
    throw UnsupportedError('File operations are not supported on the web.');
  }

  Future<RandomAccessFile> open() async {
    throw UnsupportedError('File operations are not supported on the web.');
  }
}

/// Minimal stub of IOSink used in native-only code paths.
class IOSink {
  void add(List<int> data) {
    throw UnsupportedError('File operations are not supported on the web.');
  }

  Future<void> close() async {
    throw UnsupportedError('File operations are not supported on the web.');
  }
}

/// Minimal stub of RandomAccessFile used in native-only code paths.
class RandomAccessFile {
  Future<Uint8List> read(int bytes) async {
    throw UnsupportedError('File operations are not supported on the web.');
  }

  Future<void> close() async {
    throw UnsupportedError('File operations are not supported on the web.');
  }
}
