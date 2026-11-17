import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart' show isA;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/entities/file_services.dart';
import 'package:vault_storage/src/entities/normal_file_request.dart';
import 'package:vault_storage/src/entities/secure_file_request.dart';
import 'package:vault_storage/src/entities/secure_file_stream_request.dart';
import 'package:vault_storage/src/enum/box_type.dart';
import 'package:vault_storage/src/interface/i_file_operations.dart';
import 'package:vault_storage/src/interface/i_id_generator.dart';
import 'package:vault_storage/src/interface/i_secure_key_store.dart';

/// Mock classes using Mocktail for testing
class MockSecureKeyStore extends Mock implements ISecureKeyStore {}

class MockIdGenerator extends Mock implements IIdGenerator {}

class MockBox<T> extends Mock implements Box<T> {}

class MockLazyBox<T> extends Mock implements LazyBox<T> {}

class MockFileOperations extends Mock implements IFileOperations {}

SecureFileRequest secureRequestFor(Uint8List expectedBytes, String expectedExtension) => any(
  that: isA<SecureFileRequest>()
      .having((request) => request.fileBytes, 'fileBytes', expectedBytes)
      .having((request) => request.fileExtension, 'fileExtension', expectedExtension),
);

NormalFileRequest normalRequestFor(Uint8List expectedBytes, String expectedExtension) => any(
  that: isA<NormalFileRequest>()
      .having((request) => request.fileBytes, 'fileBytes', expectedBytes)
      .having((request) => request.fileExtension, 'fileExtension', expectedExtension),
);

/// Helper class to register fallback values for Mocktail
abstract final class MocksHelper {
  static void registerFallbackValues() {
    // Register fallback values that Mocktail might need
    registerFallbackValue(<int>[]);
    registerFallbackValue('');
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(BoxType.normal);
    registerFallbackValue(false);
    // Fallback for Stream<List<int>> parameters used in any(named: 'stream')
    registerFallbackValue(const Stream<List<int>>.empty());
    registerFallbackValue(MockSecureKeyStore());
    registerFallbackValue(MockIdGenerator());
    registerFallbackValue((BoxType _) => MockBox<Object?>());
    final services = FileServices(
      isWeb: false,
      secureStorage: MockSecureKeyStore(),
      uuid: MockIdGenerator(),
      getBox: (_) => MockBox<Object?>(),
    );
    final secure = SecureFileRequest(
      fileBytes: Uint8List(0),
      fileExtension: '',
      services: services,
    );
    final streaming = SecureFileStreamRequest(
      stream: const .empty(),
      fileExtension: '',
      services: services,
    );
    final normal = NormalFileRequest(
      fileBytes: Uint8List(0),
      fileExtension: '',
      services: services,
    );
    registerFallbackValue(secure);
    registerFallbackValue(streaming);
    registerFallbackValue(normal);
  }
}
