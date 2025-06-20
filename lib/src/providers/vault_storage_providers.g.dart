// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_storage_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

/// A Riverpod provider that creates and initializes an instance of [IVaultStorage].
///
/// This provider is responsible for instantiating the [VaultStorageImpl],
/// calling its `init` method, and making the service available to the rest of
/// the application. It is marked with `keepAlive: true` to ensure the storage
/// service instance persists throughout the app's lifecycle.
///
/// If the initialization process fails, it throws an exception, which can be
/// caught and handled by Riverpod's error handling mechanisms.
///
/// The provider also registers a `ref.onDispose` callback to properly clean up
/// resources by calling the service's `dispose` method when the provider is
/// no longer in use.
@ProviderFor(vaultStorage)
const vaultStorageProvider = VaultStorageProvider._();

/// A Riverpod provider that creates and initializes an instance of [IVaultStorage].
///
/// This provider is responsible for instantiating the [VaultStorageImpl],
/// calling its `init` method, and making the service available to the rest of
/// the application. It is marked with `keepAlive: true` to ensure the storage
/// service instance persists throughout the app's lifecycle.
///
/// If the initialization process fails, it throws an exception, which can be
/// caught and handled by Riverpod's error handling mechanisms.
///
/// The provider also registers a `ref.onDispose` callback to properly clean up
/// resources by calling the service's `dispose` method when the provider is
/// no longer in use.
final class VaultStorageProvider extends $FunctionalProvider<
        AsyncValue<IVaultStorage>, IVaultStorage, FutureOr<IVaultStorage>>
    with $FutureModifier<IVaultStorage>, $FutureProvider<IVaultStorage> {
  /// A Riverpod provider that creates and initializes an instance of [IVaultStorage].
  ///
  /// This provider is responsible for instantiating the [VaultStorageImpl],
  /// calling its `init` method, and making the service available to the rest of
  /// the application. It is marked with `keepAlive: true` to ensure the storage
  /// service instance persists throughout the app's lifecycle.
  ///
  /// If the initialization process fails, it throws an exception, which can be
  /// caught and handled by Riverpod's error handling mechanisms.
  ///
  /// The provider also registers a `ref.onDispose` callback to properly clean up
  /// resources by calling the service's `dispose` method when the provider is
  /// no longer in use.
  const VaultStorageProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'vaultStorageProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$vaultStorageHash();

  @$internal
  @override
  $FutureProviderElement<IVaultStorage> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<IVaultStorage> create(Ref ref) {
    return vaultStorage(ref);
  }
}

String _$vaultStorageHash() => r'ecc9d0bc8af478921647ae12dcc183705f6572ac';

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
