import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/entities/box_config.dart';

void main() {
  group('BoxConfig', () {
    test('should create box config with all properties', () {
      const config = BoxConfig(name: 'test_box', encrypted: true, lazy: true);

      expect(config.name, equals('test_box'));
      expect(config.encrypted, isTrue);
      expect(config.lazy, isTrue);
    });

    test('should create box config with default values', () {
      const config = BoxConfig(name: 'test_box');

      expect(config.name, equals('test_box'));
      expect(config.encrypted, isFalse);
      expect(config.lazy, isFalse);
    });

    test('should support copyWith', () {
      const base = BoxConfig(name: 'original');

      final changed = base.copyWith(encrypted: true, lazy: true);

      expect(changed.name, equals('original'));
      expect(changed.encrypted, isTrue);
      expect(changed.lazy, isTrue);

      // Original should be unchanged
      expect(base.encrypted, isFalse);
      expect(base.lazy, isFalse);
    });

    test('should support copyWith with name change', () {
      const base = BoxConfig(name: 'original');
      final changed = base.copyWith(name: 'updated');

      expect(changed.name, equals('updated'));
      expect(base.name, equals('original'));
    });

    test('should support equality', () {
      const config1 = BoxConfig(name: 'test', encrypted: true, lazy: true);
      final config2 = config1.copyWith(name: 'test');
      const config3 = BoxConfig(name: 'different', encrypted: true, lazy: true);

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });

    test('should support hashCode', () {
      const config1 = BoxConfig(name: 'test');
      final config2 = config1.copyWith(name: 'test');
      const config3 = BoxConfig(name: 'different');

      expect(config1.hashCode, equals(config2.hashCode));
      expect(config1.hashCode, isNot(equals(config3.hashCode)));
    });

    test('should support toString', () {
      const config = BoxConfig(name: 'test_box', encrypted: true);

      final str = config.toString();
      expect(str, contains('test_box'));
      expect(str, contains('encrypted'));
      expect(str, contains('lazy'));
    });

    test('should create encrypted lazy box config', () {
      const config = BoxConfig(name: 'secure_files', encrypted: true, lazy: true);

      expect(config.name, equals('secure_files'));
      expect(config.encrypted, isTrue);
      expect(config.lazy, isTrue);
    });

    test('should create non-encrypted regular box config', () {
      const config = BoxConfig(name: 'cache');

      expect(config.name, equals('cache'));
      expect(config.encrypted, isFalse);
      expect(config.lazy, isFalse);
    });
  });
}
