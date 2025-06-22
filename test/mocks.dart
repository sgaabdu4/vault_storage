import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:uuid/uuid.dart';
import 'package:vault_storage/src/storage/task_execution.dart';

@GenerateMocks([FlutterSecureStorage, Uuid, Box, TaskExecutor])
void main() {}
