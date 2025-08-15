import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';
import 'package:vault_storage/src/enum/storage_box_type.dart';
import 'package:vault_storage/src/storage/file_operations.dart';

/// Mock classes using Mocktail for testing
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockUuid extends Mock implements Uuid {}

class MockBox<T> extends Mock implements Box<T> {}

class MockLazyBox<T> extends Mock implements LazyBox<T> {}

class MockFileOperations extends Mock implements FileOperations {}

/// Helper class to register fallback values for Mocktail
class MocksHelper {
  static void registerFallbackValues() {
    // Register fallback values that Mocktail might need
    registerFallbackValue(<int>[]);
    registerFallbackValue('');
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const FlutterSecureStorage());
    registerFallbackValue(const Uuid());
    registerFallbackValue(BoxType.normal);
    registerFallbackValue(false);
    // Fallback for Stream<List<int>> parameters used in any(named: 'stream')
    registerFallbackValue(const Stream<List<int>>.empty());
  }
}
