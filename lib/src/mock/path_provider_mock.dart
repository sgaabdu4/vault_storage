/// Mock implementation for `path_provider` on the web.
library;

import 'package:vault_storage/src/errors/storage_error.dart';

abstract interface class Directory {
  String get path;
}

Future<Directory> getApplicationDocumentsDirectory() async {
  throw const UnsupportedPlatformError(
    'getApplicationDocumentsDirectory is not supported on the web.',
  );
}

// Add other path_provider functions here if you use them.
