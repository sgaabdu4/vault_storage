import 'package:uuid/uuid.dart';
import 'package:vault_storage/src/interface/i_id_generator.dart';

/// The [IIdGenerator] that creates random version 4 UUIDs.
final class UuidIdGenerator implements IIdGenerator {
  const UuidIdGenerator();

  static const Uuid _uuid = Uuid();

  @override
  String v4() => _uuid.v4();
}
