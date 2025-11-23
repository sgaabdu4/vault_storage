import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';

import '../mocks.dart';
import '../test_context.dart';

void main() {
  group('Native Storage Performance Tests', () {
    late TestContext context;

    setUp(() {
      MocksHelper.registerFallbackValues();
      context = TestContext();
      context.setUpCommon();
    });

    tearDown(() {
      context.tearDownCommon();
    });

    test('should use native storage strategy for Lists', () {
      final list = [1, 2, 3, 'four', true];
      final strategy = StorageStrategyHelper.determineStrategy(list);
      expect(strategy, StorageStrategy.native);
    });

    test('should use native storage strategy for Maps', () {
      final map = {'key1': 'value1', 'key2': 42, 'key3': true};
      final strategy = StorageStrategyHelper.determineStrategy(map);
      expect(strategy, StorageStrategy.native);
    });

    test('should use json strategy for custom objects', () {
      final customObject = CustomTestObject('test', 42);
      final strategy = StorageStrategyHelper.determineStrategy(customObject);
      expect(strategy, StorageStrategy.json);
    });

    test('should use native storage for primitive types', () {
      expect(
        StorageStrategyHelper.determineStrategy('string'),
        StorageStrategy.native,
      );
      expect(
        StorageStrategyHelper.determineStrategy(42),
        StorageStrategy.native,
      );
      expect(
        StorageStrategyHelper.determineStrategy(3.14),
        StorageStrategy.native,
      );
      expect(
        StorageStrategyHelper.determineStrategy(true),
        StorageStrategy.native,
      );
    });

    test('should verify StoredValue wrapper is used correctly', () {
      final testValue = [1, 2, 3];
      final wrapped = StoredValue(testValue, StorageStrategy.native);
      final hiveMap = wrapped.toHiveMap();

      expect(hiveMap, isA<Map<String, dynamic>>());
      expect(hiveMap['__VST_STRATEGY__'], StorageStrategy.native.index);
      expect(hiveMap['__VST_VALUE__'], testValue);

      final unwrapped = StoredValue.fromHiveMap(hiveMap);
      expect(unwrapped.value, testValue);
      expect(unwrapped.strategy, StorageStrategy.native);
    });

    test('should detect wrapped values correctly', () {
      final wrapped = {
        '__VST_STRATEGY__': 0,
        '__VST_VALUE__': [1, 2, 3],
      };
      expect(StoredValue.isWrapped(wrapped), true);

      final notWrapped = {'key': 'value'};
      expect(StoredValue.isWrapped(notWrapped), false);

      expect(StoredValue.isWrapped('string'), false);
      expect(StoredValue.isWrapped(42), false);
    });
  });
}

/// Test class for custom object serialization
class CustomTestObject {
  CustomTestObject(this.name, this.value);
  final String name;
  final int value;

  Map<String, dynamic> toJson() => {'name': name, 'value': value};
}
