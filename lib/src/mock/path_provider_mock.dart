/// Mock implementation for `path_provider` on the web.
library;

import 'package:vault_storage/src/errors/storage_error.dart';
import 'package:vault_storage/src/mock/file_io_mock.dart';

Future<Directory> getApplicationDocumentsDirectory() async {
  throw const UnsupportedPlatformError(
    'getApplicationDocumentsDirectory is not supported on the web.',
  );
}

// Add other path_provider functions here if you use them.
