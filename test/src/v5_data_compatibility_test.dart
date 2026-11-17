import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:vault_storage/src/constants/storage_keys.dart';
import 'package:vault_storage/src/entities/box_config.dart';
import 'package:vault_storage/src/interface/i_secure_key_store.dart';
import 'package:vault_storage/src/storage/file_operations.dart';
import 'package:vault_storage/src/storage/storage_strategy.dart';
import 'package:vault_storage/src/storage/uuid_id_generator.dart';
import 'package:vault_storage/src/storage/vault_storage_adapter_registry.dart';
import 'package:vault_storage/src/vault_storage_impl.dart';

const _writtenPath = '/tmp/vault_storage_fixture_5x/docs';
const _fixture = 'test/fixtures/v5';
const _twoMiBAndMore = 2107000;

Uint8List _bytes(int length) => .fromList(.generate(length, (index) => (index * 7 + 3) & 0xFF));

final class _FixtureKeyStore implements ISecureKeyStore {
  _FixtureKeyStore(this.keys);

  final Map<String, String?> keys;

  @override
  Future<String?> read({required String key}) async => keys[key];

  @override
  Future<void> write({required String key, required String? value}) async => keys[key] = value;

  @override
  Future<void> delete({required String key}) async => keys.remove(key);
}

void _copyDirectory(Directory source, Directory target) {
  target.createSync(recursive: true);
  for (final entity in source.listSync(recursive: true).whereType<File>()) {
    final copy = File('${target.path}${entity.path.substring(source.path.length)}');
    copy.parent.createSync(recursive: true);
    entity.copySync(copy.path);
  }
}

Future<void> _pointFilesAt(String docs, String? masterKey) async {
  VaultStorageAdapterRegistry.ensureRegistered();
  Hive.init('$docs/hive');
  final cipher = HiveAesCipher(base64Url.decode(masterKey ?? ''));
  for (final name in [StorageKeys.normalFilesBox, StorageKeys.secureFilesBox]) {
    final box = await Hive.openLazyBox<Object?>(
      name,
      encryptionCipher: name == StorageKeys.secureFilesBox ? cipher : null,
    );
    for (final key in box.keys) {
      if (await box.get(key) case StoredValue(value: final Map<Object?, Object?> metadata)) {
        final path = metadata['filePath'];
        if (path is String) {
          await box.put(
            key,
            StoredValue({...metadata, 'filePath': path.replaceFirst(_writtenPath, docs)}, .native),
          );
        }
      }
    }
    await box.close();
  }
  await Hive.close();
}

void main() {
  group('data written by vault_storage 5.x', () {
    late VaultStorageImpl storage;
    late Directory folder;
    final usedFolders = <String>[];

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      folder = await Directory.systemTemp.createTemp('vault_v5_');
      final docs = Directory('${folder.path}/docs');
      _copyDirectory(Directory('$_fixture/docs'), docs);
      usedFolders.add(docs.path);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => call.method == 'getApplicationDocumentsDirectory' ? docs.path : null,
      );
      final keys = switch (jsonDecode(File('$_fixture/keys.json').readAsStringSync())) {
        {'master': final String master, 'files': final Map<String, dynamic> files} =>
          <String, String?>{
            'hive_encryption_key': master,
            for (final MapEntry(:key, :value) in files.entries)
              'file_key_$key': value is String ? value : null,
          },
        _ => fail('keys.json holds no master key'),
      };
      await _pointFilesAt(docs.path, keys['hive_encryption_key']);
      storage = VaultStorageImpl(
        secureStorage: _FixtureKeyStore(keys),
        uuid: const UuidIdGenerator(),
        fileOperations: FileOperations(),
        storageDirectory: 'hive',
        customBoxes: const [
          BoxConfig(name: 'plain_box'),
          BoxConfig(name: 'encrypted_box', encrypted: true),
          BoxConfig(name: 'lazy_box', encrypted: true, lazy: true),
        ],
      );
      await storage.init();
    });

    tearDown(() async {
      await storage.dispose();
      await Hive.close();
      await folder.delete(recursive: true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
    });

    test('works in a folder of its own for each run', () {
      expect(usedFolders, hasLength(usedFolders.toSet().length));
      expect(usedFolders.last, isNot(_writtenPath));
    });

    test('reads the plain values', () async {
      expect(await storage.get<String>('text', isSecure: false), 'hello 5.x');
      expect(await storage.get<int>('count', isSecure: false), 42);
      expect(await storage.get<double>('ratio', isSecure: false), 3.5);
      expect(await storage.get<bool>('flag', isSecure: false), isTrue);
      expect(await storage.get<List<Object?>>('list', isSecure: false), [1, 2, 3]);
      expect(await storage.get<Map<String, dynamic>>('map', isSecure: false), {
        'a': 1,
        'nested': {
          'b': [true, null],
        },
      });
      expect(await storage.get<String>('long_text', isSecure: false), 'x' * 1500);
    });

    test('reads the secure values', () async {
      expect(await storage.get<String>('secret', isSecure: true), 'secret-5x');
      expect(await storage.get<int>('pin', isSecure: true), 1234);
      expect(await storage.get<Map<String, dynamic>>('credentials', isSecure: true), {
        'user': 'u',
        'pass': 'p',
      });
    });

    test('reads a plain, an encrypted and an encrypted lazy custom box', () async {
      expect(await storage.get<String>('theme', box: 'plain_box'), 'dark');
      expect(await storage.get<Map<String, dynamic>>('token', box: 'encrypted_box'), {
        'id': 'tok-5x',
        'scopes': ['a', 'b'],
      });
      expect(await storage.get<Map<String, dynamic>>('record', box: 'lazy_box'), {
        'x': [1, 2],
      });
    });

    test('reads small and streamed secure files and normal files', () async {
      expect(await storage.getFile('normal_small', isSecure: false), _bytes(300));
      expect(await storage.getFile('normal_big', isSecure: false), _bytes(_twoMiBAndMore));
      expect(await storage.getFile('secure_small', isSecure: true), _bytes(300));
      expect(await storage.getFile('secure_big', isSecure: true), _bytes(_twoMiBAndMore));
    });

    test('reads a file from a custom box', () async {
      expect(await storage.getFile('custom_file', box: 'lazy_box'), _bytes(300));
    });

    test('keeps the user metadata of a stored file', () async {
      final metadata = await storage.getFileMetadata('normal_small', isSecure: false);

      expect(metadata['userMetadata'], {'owner': 'fixture'});
    });
  });
}
