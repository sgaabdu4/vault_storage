// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'box_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BoxConfig {

/// The unique name of the box.
 String get name;/// Whether the box should be encrypted.
/// When true, uses AES-GCM encryption with the master key.
 bool get encrypted;/// Whether to use lazy loading for this box.
/// Lazy boxes load values on-demand, which is better for large data or files.
/// Regular boxes load all keys into memory on open for faster access.
 bool get lazy;
/// Create a copy of BoxConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BoxConfigCopyWith<BoxConfig> get copyWith => _$BoxConfigCopyWithImpl<BoxConfig>(this as BoxConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BoxConfig&&(identical(other.name, name) || other.name == name)&&(identical(other.encrypted, encrypted) || other.encrypted == encrypted)&&(identical(other.lazy, lazy) || other.lazy == lazy));
}


@override
int get hashCode => Object.hash(runtimeType,name,encrypted,lazy);

@override
String toString() {
  return 'BoxConfig(name: $name, encrypted: $encrypted, lazy: $lazy)';
}


}

/// @nodoc
abstract mixin class $BoxConfigCopyWith<$Res>  {
  factory $BoxConfigCopyWith(BoxConfig value, $Res Function(BoxConfig) _then) = _$BoxConfigCopyWithImpl;
@useResult
$Res call({
 String name, bool encrypted, bool lazy
});




}
/// @nodoc
class _$BoxConfigCopyWithImpl<$Res>
    implements $BoxConfigCopyWith<$Res> {
  _$BoxConfigCopyWithImpl(this._self, this._then);

  final BoxConfig _self;
  final $Res Function(BoxConfig) _then;

/// Create a copy of BoxConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? encrypted = null,Object? lazy = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,encrypted: null == encrypted ? _self.encrypted : encrypted // ignore: cast_nullable_to_non_nullable
as bool,lazy: null == lazy ? _self.lazy : lazy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [BoxConfig].
extension BoxConfigPatterns on BoxConfig {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BoxConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BoxConfig() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BoxConfig value)  $default,){
final _that = this;
switch (_that) {
case _BoxConfig():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BoxConfig value)?  $default,){
final _that = this;
switch (_that) {
case _BoxConfig() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  bool encrypted,  bool lazy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BoxConfig() when $default != null:
return $default(_that.name,_that.encrypted,_that.lazy);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  bool encrypted,  bool lazy)  $default,) {final _that = this;
switch (_that) {
case _BoxConfig():
return $default(_that.name,_that.encrypted,_that.lazy);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  bool encrypted,  bool lazy)?  $default,) {final _that = this;
switch (_that) {
case _BoxConfig() when $default != null:
return $default(_that.name,_that.encrypted,_that.lazy);case _:
  return null;

}
}

}

/// @nodoc


class _BoxConfig implements BoxConfig {
  const _BoxConfig({required this.name, this.encrypted = false, this.lazy = false});


/// The unique name of the box.
@override final  String name;
/// Whether the box should be encrypted.
/// When true, uses AES-GCM encryption with the master key.
@override@JsonKey() final  bool encrypted;
/// Whether to use lazy loading for this box.
/// Lazy boxes load values on-demand, which is better for large data or files.
/// Regular boxes load all keys into memory on open for faster access.
@override@JsonKey() final  bool lazy;

/// Create a copy of BoxConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BoxConfigCopyWith<_BoxConfig> get copyWith => __$BoxConfigCopyWithImpl<_BoxConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BoxConfig&&(identical(other.name, name) || other.name == name)&&(identical(other.encrypted, encrypted) || other.encrypted == encrypted)&&(identical(other.lazy, lazy) || other.lazy == lazy));
}


@override
int get hashCode => Object.hash(runtimeType,name,encrypted,lazy);

@override
String toString() {
  return 'BoxConfig(name: $name, encrypted: $encrypted, lazy: $lazy)';
}


}

/// @nodoc
abstract mixin class _$BoxConfigCopyWith<$Res> implements $BoxConfigCopyWith<$Res> {
  factory _$BoxConfigCopyWith(_BoxConfig value, $Res Function(_BoxConfig) _then) = __$BoxConfigCopyWithImpl;
@override @useResult
$Res call({
 String name, bool encrypted, bool lazy
});




}
/// @nodoc
class __$BoxConfigCopyWithImpl<$Res>
    implements _$BoxConfigCopyWith<$Res> {
  __$BoxConfigCopyWithImpl(this._self, this._then);

  final _BoxConfig _self;
  final $Res Function(_BoxConfig) _then;

/// Create a copy of BoxConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? encrypted = null,Object? lazy = null,}) {
  return _then(_BoxConfig(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,encrypted: null == encrypted ? _self.encrypted : encrypted // ignore: cast_nullable_to_non_nullable
as bool,lazy: null == lazy ? _self.lazy : lazy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
