import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vault_storage/src/interface/i_vault_storage.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

part 'vault_storage_providers.g.dart';

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
@Riverpod(keepAlive: true)
Future<IVaultStorage> vaultStorage(Ref ref) async {
  final implementation = VaultStorageImpl();
  final initResult = await implementation.init();

  return initResult.fold(
    (error) =>
        throw Exception('Failed to initialize storage: ${error.message}'),
    (_) {
      ref.onDispose(() async => implementation.dispose());
      return implementation;
    },
  );
}
