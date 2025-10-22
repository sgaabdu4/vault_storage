// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'box_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$BoxConfig {
  /// The unique name of the box.
  String get name => throw _privateConstructorUsedError;

  /// Whether the box should be encrypted.
  /// When true, uses AES-GCM encryption with the master key.
  bool get encrypted => throw _privateConstructorUsedError;

  /// Whether to use lazy loading for this box.
  /// Lazy boxes load values on-demand, which is better for large data or files.
  /// Regular boxes load all keys into memory on open for faster access.
  bool get lazy => throw _privateConstructorUsedError;

  /// Create a copy of BoxConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BoxConfigCopyWith<BoxConfig> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BoxConfigCopyWith<$Res> {
  factory $BoxConfigCopyWith(BoxConfig value, $Res Function(BoxConfig) then) =
      _$BoxConfigCopyWithImpl<$Res, BoxConfig>;
  @useResult
  $Res call({String name, bool encrypted, bool lazy});
}

/// @nodoc
class _$BoxConfigCopyWithImpl<$Res, $Val extends BoxConfig> implements $BoxConfigCopyWith<$Res> {
  _$BoxConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BoxConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? encrypted = null,
    Object? lazy = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      encrypted: null == encrypted
          ? _value.encrypted
          : encrypted // ignore: cast_nullable_to_non_nullable
              as bool,
      lazy: null == lazy
          ? _value.lazy
          : lazy // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BoxConfigImplCopyWith<$Res> implements $BoxConfigCopyWith<$Res> {
  factory _$$BoxConfigImplCopyWith(_$BoxConfigImpl value, $Res Function(_$BoxConfigImpl) then) =
      __$$BoxConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, bool encrypted, bool lazy});
}

/// @nodoc
class __$$BoxConfigImplCopyWithImpl<$Res> extends _$BoxConfigCopyWithImpl<$Res, _$BoxConfigImpl>
    implements _$$BoxConfigImplCopyWith<$Res> {
  __$$BoxConfigImplCopyWithImpl(_$BoxConfigImpl _value, $Res Function(_$BoxConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of BoxConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? encrypted = null,
    Object? lazy = null,
  }) {
    return _then(_$BoxConfigImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      encrypted: null == encrypted
          ? _value.encrypted
          : encrypted // ignore: cast_nullable_to_non_nullable
              as bool,
      lazy: null == lazy
          ? _value.lazy
          : lazy // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$BoxConfigImpl implements _BoxConfig {
  const _$BoxConfigImpl({required this.name, this.encrypted = false, this.lazy = false});

  /// The unique name of the box.
  @override
  final String name;

  /// Whether the box should be encrypted.
  /// When true, uses AES-GCM encryption with the master key.
  @override
  @JsonKey()
  final bool encrypted;

  /// Whether to use lazy loading for this box.
  /// Lazy boxes load values on-demand, which is better for large data or files.
  /// Regular boxes load all keys into memory on open for faster access.
  @override
  @JsonKey()
  final bool lazy;

  @override
  String toString() {
    return 'BoxConfig(name: $name, encrypted: $encrypted, lazy: $lazy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BoxConfigImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.encrypted, encrypted) || other.encrypted == encrypted) &&
            (identical(other.lazy, lazy) || other.lazy == lazy));
  }

  @override
  int get hashCode => Object.hash(runtimeType, name, encrypted, lazy);

  /// Create a copy of BoxConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BoxConfigImplCopyWith<_$BoxConfigImpl> get copyWith =>
      __$$BoxConfigImplCopyWithImpl<_$BoxConfigImpl>(this, _$identity);
}

abstract class _BoxConfig implements BoxConfig {
  const factory _BoxConfig({required final String name, final bool encrypted, final bool lazy}) =
      _$BoxConfigImpl;

  /// The unique name of the box.
  @override
  String get name;

  /// Whether the box should be encrypted.
  /// When true, uses AES-GCM encryption with the master key.
  @override
  bool get encrypted;

  /// Whether to use lazy loading for this box.
  /// Lazy boxes load values on-demand, which is better for large data or files.
  /// Regular boxes load all keys into memory on open for faster access.
  @override
  bool get lazy;

  /// Create a copy of BoxConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BoxConfigImplCopyWith<_$BoxConfigImpl> get copyWith => throw _privateConstructorUsedError;
}
