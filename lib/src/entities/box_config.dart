import 'package:freezed_annotation/freezed_annotation.dart';

part 'box_config.freezed.dart';

/// Configuration for a custom storage box.
///
/// Defines the name, encryption, and storage type for a custom Hive box.
/// Custom boxes allow you to organize data into separate logical containers
/// beyond the default `normal` and `secure` boxes.
///
/// Example:
/// ```dart
/// final storage = VaultStorage.create(
///   customBoxes: [
///     BoxConfig(name: 'themes', encrypted: false),
///     BoxConfig(name: 'auth_info', encrypted: true),
///     BoxConfig(name: 'prescriptions', encrypted: true),
///   ],
/// );
/// ```
@freezed
class BoxConfig with _$BoxConfig {
  const factory BoxConfig({
    /// The unique name of the box.
    required String name,

    /// Whether the box should be encrypted.
    /// When true, uses AES-GCM encryption with the master key.
    @Default(false) bool encrypted,

    /// Whether to use lazy loading for this box.
    /// Lazy boxes load values on-demand, which is better for large data or files.
    /// Regular boxes load all keys into memory on open for faster access.
    @Default(false) bool lazy,
  }) = _BoxConfig;
}
