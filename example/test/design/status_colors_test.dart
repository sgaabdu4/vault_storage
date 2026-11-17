import 'package:example/design/status_colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const colors = StatusColors(success: Colors.green, failure: Colors.red);

  test('copyWith replaces only the colors it is given', () {
    final copy = colors.copyWith(failure: Colors.orange);

    expect(copy.success, Colors.green);
    expect(copy.failure, Colors.orange);
    expect(colors.copyWith().failure, Colors.red);
  });

  test('lerp jumps to the other colors at the end of the animation', () {
    const other = StatusColors(success: Colors.blue, failure: Colors.black);

    expect(colors.lerp(other, 0.5), colors);
    expect(colors.lerp(other, 1), other);
    expect(colors.lerp(null, 1), colors);
  });
}
