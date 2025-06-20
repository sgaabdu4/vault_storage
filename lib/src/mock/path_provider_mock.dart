/// Mock implementation for `path_provider` on the web.
/// These functions should not be called on the web, and will throw if they are.
library;

Future<dynamic> getApplicationDocumentsDirectory() async {
  throw UnsupportedError(
      'getApplicationDocumentsDirectory is not supported on the web.');
}

// Add other functions from path_provider here if you use them,
// all throwing UnsupportedError.
