class BrowserCheckFailure implements Exception {
  const BrowserCheckFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
