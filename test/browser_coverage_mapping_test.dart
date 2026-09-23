import 'package:flutter_test/flutter_test.dart';

import '../tool/browser_coverage_mapping.dart';

void main() {
  test('unexecuted nested blocks override an executed outer function', () {
    final functions = [
      {
        'ranges': [
          {'startOffset': 0, 'endOffset': 100, 'count': 3},
          {'startOffset': 20, 'endOffset': 40, 'count': 0},
        ],
      },
    ];
    expect(rangeHits(functions, 19), 3);
    expect(rangeHits(functions, 20), 0);
    expect(rangeHits(functions, 39), 0);
    expect(rangeHits(functions, 40), 3);
    expect(rangeHits(functions, 100), isNull);
  });

  test('unexecuted functions are not counted by an executed enclosing script', () {
    final functions = [
      {
        'ranges': [
          {'startOffset': 0, 'endOffset': 200, 'count': 1},
        ],
      },
      {
        'ranges': [
          {'startOffset': 50, 'endOffset': 150, 'count': 0},
        ],
      },
    ];
    expect(rangeHits(functions, 75), 0);
    expect(rangeHits(functions.reversed.toList(), 75), 0);
    expect(rangeHits([], 75), isNull);
  });
}
