import 'package:flutter_test/flutter_test.dart';

import 'browser/browser_coverage_mapping.dart';

void main() {
  test('unexecuted nested blocks override an executed outer function', () {
    final List<Object?> functions = [
      {
        'ranges': [
          {'startOffset': 0, 'endOffset': 100, 'count': 3},
          {'startOffset': 20, 'endOffset': 40, 'count': 0},
        ],
      },
    ];
    final ranges = coverageRanges(functions);
    expect(rangeHits(ranges, 19), 3);
    expect(rangeHits(ranges, 20), 0);
    expect(rangeHits(ranges, 39), 0);
    expect(rangeHits(ranges, 40), 3);
    expect(rangeHits(ranges, 100), isNull);
  });

  test('unexecuted functions are not counted by an executed enclosing script', () {
    final List<Object?> functions = [
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
    expect(rangeHits(coverageRanges(functions), 75), 0);
    expect(rangeHits(coverageRanges(functions.reversed.toList()), 75), 0);
    expect(rangeHits(coverageRanges([]), 75), isNull);
  });
}
