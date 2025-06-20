import 'package:flutter_test/flutter_test.dart';
import 'package:storage_service/src/enum/storage_box_type.dart';

void main() {
  group('BoxType', () {
    test('BoxType.normal is normal', () {
      expect(BoxType.normal.toString(), 'BoxType.normal');
    });
    test('BoxType.secure is secure', () {
      expect(BoxType.secure.toString(), 'BoxType.secure');
    });
  });
}
