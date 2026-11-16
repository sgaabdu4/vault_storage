import 'package:freezed_annotation/freezed_annotation.dart';

part 'box_config.freezed.dart';

/// Configuration for a custom storage box.
@freezed
sealed class BoxConfig with _$BoxConfig {
  const factory BoxConfig({
    /// The unique name of the box.
    required String name,

    /// Whether the box should be encrypted.
    @Default(false) bool encrypted,

    /// Whether to use lazy loading for this box.
    @Default(false) bool lazy,
  }) = _BoxConfig;
}
