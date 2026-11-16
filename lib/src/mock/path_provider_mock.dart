/// Mock implementation for `path_provider` on the web.
library;

abstract interface class Directory {
  String get path;
}

Future<Directory> getApplicationDocumentsDirectory() async {
  throw UnsupportedError('getApplicationDocumentsDirectory is not supported on the web.');
}

// Add other path_provider functions here if you use them.
