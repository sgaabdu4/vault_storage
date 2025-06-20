// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

@ProviderFor(storageService)
const storageServiceProvider = StorageServiceProvider._();

final class StorageServiceProvider extends $FunctionalProvider<
        AsyncValue<IStorageService>, IStorageService, FutureOr<IStorageService>>
    with $FutureModifier<IStorageService>, $FutureProvider<IStorageService> {
  const StorageServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'storageServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$storageServiceHash();

  @$internal
  @override
  $FutureProviderElement<IStorageService> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<IStorageService> create(Ref ref) {
    return storageService(ref);
  }
}

String _$storageServiceHash() => r'e56c574df7155b65d16c9664abdca993f8f9d3ab';

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
