import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vault_storage/src/constants/vault_storage_config.dart';
import 'package:vault_storage/src/errors/errors.dart';
import 'package:vault_storage/src/extensions/json_safe.dart';

import 'package:vault_storage/src/extensions/storage_extensions.dart';
import 'package:vault_storage/src/storage/file_operations.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';

import '../mocks.dart';
import '../test_context.dart';

const _secret = 'hunter2-secret';
const _config = VaultStorageConfig();
const _hint = 'Consider clearing corrupted data.';

String _decodeFailure(String inner, String cause) =>
    'VaultStorageSerializationError: Failed to decode value (caused by: '
    'VaultStorageSerializationError: $inner (caused by: FormatException: $cause))';

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
      expect(
        text,
        _decodeFailure(
          'Type mismatch: Cannot parse the stored text as int. $_hint',
          'Invalid number',
        ),
      );
    });

    test('a decoded text that cannot parse as double leaves its content out', () async {
      final encoded = await JsonSafe.encode(_secret, _config);

      final text = await _errorText(() => JsonSafe.decode<double>(encoded, _config));

      expect(text, isNot(contains(_secret)));
      expect(
        text,
        _decodeFailure(
          'Type mismatch: Cannot parse the stored text as double. $_hint',
          'Invalid number',
        ),
      );
    });

    test('text that is not valid JSON leaves its content out', () async {
      final text = await _errorText(
        () => JsonSafe.decode<Map<String, dynamic>>('{"password": $_secret}', _config),
      );

      expect(text, isNot(contains(_secret)));
      expect(
        text,
        'VaultStorageSerializationError: Failed to decode value (caused by: FormatException: Invalid JSON)',
      );
    });

    test('a corrupt stored file key leaves its content out of the error', () async {
      when(
        () => testContext.mockSecureStorage.read(key: 'file_key_1'),
      ).thenAnswer((_) async => _secret);

      final text = await _errorText(
        () => FileOperations().getSecureFile(
          fileMetadata: {
            'fileId': '1',
            'secureKeyName': 'file_key_1',
            'streaming': true,
            'chunkCount': 0,
          },
          isWeb: true,
          secureStorage: testContext.mockSecureStorage,
          getBox: testContext.getBox,
        ),
      );

      expect(text, isNot(contains(_secret)));
      expect(
        text,
        'Base64DecodeError: Failed to decode base64 for encryption key '
        '(caused by: FormatException: Invalid base64)',
      );
    });

    test('a corrupt stored text of any size leaves its content out of the error', () async {
      final small = await _errorText(
        () async => _secret.decodeBase64Safely(context: 'x', config: _config),
      );
      final large = await _errorText(
        () async => ('$_secret!' * 20).decodeBase64Safely(
          context: 'x',
          config: const VaultStorageConfig(base64IsolateThreshold: 10),
        ),
      );

      for (final text in [small, large]) {
        expect(
          text,
          'Base64DecodeError: Failed to decode base64 for x '
          '(caused by: FormatException: Invalid base64)',
        );
      }
    });
  });
}
