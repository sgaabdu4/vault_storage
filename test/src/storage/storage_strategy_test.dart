import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';

void main() {
  group('StorageStrategyHelper', () {
    test('should identify primitives as natively storable', () {
      expect(StorageStrategyHelper.determineStrategy(null), equals(StorageStrategy.native));
      expect(StorageStrategyHelper.determineStrategy('string'), equals(StorageStrategy.native));
      expect(StorageStrategyHelper.determineStrategy(123), equals(StorageStrategy.native));
      expect(StorageStrategyHelper.determineStrategy(12.34), equals(StorageStrategy.native));
      expect(StorageStrategyHelper.determineStrategy(true), equals(StorageStrategy.native));
      expect(StorageStrategyHelper.determineStrategy(Uint8List(0)), equals(StorageStrategy.native));
    });

    test('should identify simple lists and maps as natively storable', () {
      expect(StorageStrategyHelper.determineStrategy([1, 2, 3]), equals(StorageStrategy.native));
      expect(StorageStrategyHelper.determineStrategy({'a': 1, 'b': 2}),
          equals(StorageStrategy.native));
    });

    test('should identify complex objects as json storable', () {
      expect(StorageStrategyHelper.determineStrategy(DateTime.now()), equals(StorageStrategy.json));
      expect(StorageStrategyHelper.determineStrategy({1, 2}), equals(StorageStrategy.json));
      expect(StorageStrategyHelper.determineStrategy(Object()), equals(StorageStrategy.json));
    });

    test('should handle nested structures', () {
      final nested = [
        {
          'a': [1, 2]
        },
        {
          'b': {'c': 'd'}
        }
      ];
      expect(StorageStrategyHelper.determineStrategy(nested), equals(StorageStrategy.native));
    });

    test('should handle deeply nested structures without stack overflow', () {
      // Create a deeply nested list: [[[[...]]]]
      dynamic deepList = 1;
      for (var i = 0; i < 10000; i++) {
        deepList = [deepList];
      }

      // This would cause stack overflow with recursive implementation
      expect(StorageStrategyHelper.determineStrategy(deepList), equals(StorageStrategy.native));
    });

    test('should handle wide structures', () {
      final wideList = List.generate(10000, (i) => i);
      expect(StorageStrategyHelper.determineStrategy(wideList), equals(StorageStrategy.native));
    });

    test('should identify mixed valid/invalid structures correctly', () {
      final mixed = [1, 2, DateTime.now()];
      expect(StorageStrategyHelper.determineStrategy(mixed), equals(StorageStrategy.json));
    });
  });
}
