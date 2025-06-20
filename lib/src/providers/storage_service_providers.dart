import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:storage_service/src/interface/i_storage_service.dart';
import 'package:storage_service/src/storage_service_impl.dart';

part 'storage_service_providers.g.dart';

@Riverpod(keepAlive: true)
Future<IStorageService> storageService(Ref ref) async {
  final implementation = StorageServiceImpl();
  final initResult = await implementation.init();

  return initResult.fold(
    (error) => throw Exception('Failed to initialize storage: ${error.message}'),
    (_) {
      ref.onDispose(() async => implementation.dispose());
      return implementation;
    },
  );
}
