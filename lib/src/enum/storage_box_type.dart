enum BoxType {
  /// For non-sensitive data like cache and user preferences.
  normal,

  /// For sensitive data like auth tokens and user credentials, stored encrypted.
  secure,
}
