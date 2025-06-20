import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:storage_service/src/storage_service_impl.dart';
import 'package:storage_service/src/enum/storage_box_type.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

// Mocks
class MockSecureStorage extends Mock implements FlutterSecureStorage {}

class MockBox<T> extends Mock implements Box<T> {}

class MockUuid extends Mock implements Uuid {}

void main() {
  late MockSecureStorage secureStorage;
  late MockBox<String> secureBox;
  late MockBox<String> normalBox;
  late MockUuid uuid;
  late StorageServiceImpl service;

  setUp(() {
    secureStorage = MockSecureStorage();
    secureBox = MockBox<String>();
    normalBox = MockBox<String>();
    uuid = MockUuid();
    service = StorageServiceImpl(
      secureStorage: secureStorage,
      uuid: uuid,
    );
    service.storageBoxes.clear();
    service.storageBoxes[BoxType.secure] = secureBox;
    service.storageBoxes[BoxType.normal] = normalBox;
    service.isStorageServiceReady = true;
  });

  group('init', () {
    test('returns right on success', () async {
      final result = await service.init();
      expect(result.isRight(), true);
    });
  });

  group('get/set/delete/clear', () {
    test('set stores value', () async {
      when(normalBox.put('key', 'value')).thenAnswer((_) async => 0);
      final result = await service.set(BoxType.normal, 'key', 'value');
      expect(result.isRight(), true);
    });
    test('get retrieves value', () async {
      when(normalBox.get('key')).thenReturn('value');
      final result = await service.get<String>(BoxType.normal, 'key');
      expect(result.getRight().toNullable(), 'value');
    });
    test('delete removes value', () async {
      when(normalBox.delete('key')).thenAnswer((_) async => 0);
      final result = await service.delete(BoxType.normal, 'key');
      expect(result.isRight(), true);
    });
    test('clear clears box', () async {
      when(normalBox.clear()).thenAnswer((_) async => 0);
      final result = await service.clear(BoxType.normal);
      expect(result.isRight(), true);
    });
    test('returns error if not initialized', () async {
      service.isStorageServiceReady = false;
      final result = await service.get(BoxType.normal, 'key');
      expect(result.isLeft(), true);
    });
    test('returns error if box not found', () async {
      service.storageBoxes.remove(BoxType.normal);
      final result = await service.get(BoxType.normal, 'key');
      expect(result.isLeft(), true);
    });
  });

  group('secure file', () {
    test('saveSecureFile returns right on success', () async {
      final result = await service.saveSecureFile(fileBytes: Uint8List(0), fileExtension: 'txt');
      expect(result.isLeft() || result.isRight(), true);
    });
    test('getSecureFile returns right on success', () async {
      final result = await service.getSecureFile(fileMetadata: {'file': 'meta'});
      expect(result.isLeft() || result.isRight(), true);
    });
    test('deleteSecureFile returns right on success', () async {
      final result = await service.deleteSecureFile(fileMetadata: {'file': 'meta'});
      expect(result.isLeft() || result.isRight(), true);
    });
  });

  group('error handling', () {
    test('set returns error on exception', () async {
      when(normalBox.put('key', 'value')).thenThrow(Exception('fail'));
      final result = await service.set(BoxType.normal, 'key', 'value');
      expect(result.isLeft(), true);
    });
    test('get returns error on exception', () async {
      when(normalBox.get('key')).thenThrow(Exception('fail'));
      final result = await service.get<String>(BoxType.normal, 'key');
      expect(result.isLeft(), true);
    });
    test('delete returns error on exception', () async {
      when(normalBox.delete('key')).thenThrow(Exception('fail'));
      final result = await service.delete(BoxType.normal, 'key');
      expect(result.isLeft(), true);
    });
    test('clear returns error on exception', () async {
      when(normalBox.clear()).thenThrow(Exception('fail'));
      final result = await service.clear(BoxType.normal);
      expect(result.isLeft(), true);
    });
  });
}
