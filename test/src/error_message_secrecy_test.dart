import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/constants/vault_storage_config.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/extensions/json_safe.dart';

import 'package:vault_storage/src/storage/storage_strategy.dart';

import '../mocks.dart';
import '../test_context.dart';

const _secret = 'hunter2-secret';
const _config = VaultStorageConfig();

Future<String> _errorText(Future<Object?> Function() action) async {
  try {
    await action();
  } on VaultStorageError catch (error) {
    return error.toString();
  }
  fail('The call did not throw a VaultStorageError');
}

void main() {
  group('error messages never hold stored values', () {
    late TestContext testContext;

    setUpAll(MocksHelper.registerFallbackValues);

    setUp(() {
      testContext = TestContext();
      testContext.setUpCommon();
    });

    tearDown(() {
      testContext.tearDownCommon();
    });

    test(
      'a secure box text value that does not fit the type names only the key and types',
      () async {
        when(() => testContext.mockSecureBox.containsKey('token')).thenReturn(true);
        when(
          () => testContext.mockSecureBox.get('token'),
        ).thenReturn(const StoredValue(_secret, .native));

        final text = await _errorText(
          () => testContext.vaultStorage.get<int>('token', isSecure: true),
        );

        expect(text, isNot(contains(_secret)));
        expect(text, allOf(contains('"token"'), contains('String'), contains('int')));
      },
    );

    test(
      'a secure box map value that does not fit the type names only the key and types',
      () async {
        when(() => testContext.mockSecureBox.containsKey('login')).thenReturn(true);
        when(() => testContext.mockSecureBox.get('login')).thenReturn({'password': _secret});

        final text = await _errorText(
          () => testContext.vaultStorage.get<List<int>>('login', isSecure: true),
        );

        expect(text, isNot(contains(_secret)));
        expect(text, allOf(contains('"login"'), contains('List<int>')));
      },
    );

    test('a decoded list that does not fit the type leaves its content out', () async {
      final encoded = await JsonSafe.encode([_secret], _config);

      final text = await _errorText(() => JsonSafe.decode<int>(encoded, _config));

      expect(text, isNot(contains(_secret)));
      expect(text, allOf(contains('int'), contains('List')));
    });

    test('a decoded text that cannot parse as int leaves its content out', () async {
      final encoded = await JsonSafe.encode(_secret, _config);

      final text = await _errorText(() => JsonSafe.decode<int>(encoded, _config));

      expect(text, isNot(contains(_secret)));
    });

    test('a decoded text that cannot parse as double leaves its content out', () async {
      final encoded = await JsonSafe.encode(_secret, _config);

      final text = await _errorText(() => JsonSafe.decode<double>(encoded, _config));

      expect(text, isNot(contains(_secret)));
    });

    test('text that is not valid JSON leaves its content out', () async {
      final text = await _errorText(
        () => JsonSafe.decode<Map<String, dynamic>>('{"password": $_secret}', _config),
      );

      expect(text, isNot(contains(_secret)));
    });
  });
}
