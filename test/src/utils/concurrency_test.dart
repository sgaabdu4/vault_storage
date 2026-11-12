import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault_storage/src/utils/concurrency.dart';

void main() {
  group('mapWithConcurrency', () {
    test('returns results in input order when later tasks finish first', () async {
      final gates = List.generate(3, (_) => Completer<void>());
      final run = mapWithConcurrency<int, String>([0, 1, 2], 3, (index) async {
        await gates[index].future;
        return 'item $index';
      });

      gates[2].complete();
      gates[1].complete();
      gates[0].complete();

      expect(await run, ['item 0', 'item 1', 'item 2']);
    });

    test('never runs more tasks at once than the limit', () async {
      var running = 0;
      var peak = 0;
      final results = await mapWithConcurrency<int, int>(List.generate(10, (index) => index), 3, (
        value,
      ) async {
        running++;
        peak = running > peak ? running : peak;
        await Future<void>.delayed(Duration.zero);
        running--;
        return value * 2;
      });

      expect(peak, 3);
      expect(results, List.generate(10, (index) => index * 2));
    });

    test('returns an empty list for no items without calling the task', () async {
      var calls = 0;
      final results = await mapWithConcurrency<int, int>(const [], 4, (value) async {
        calls++;
        return value;
      });

      expect(results, isEmpty);
      expect(calls, 0);
    });

    test('keeps null results in place', () async {
      final results = await mapWithConcurrency<int, int?>(
        [1, 2, 3],
        2,
        (value) async => value.isOdd ? null : value,
      );

      expect(results, [null, 2, null]);
    });

    test('rethrows the first failure and starts no further items', () async {
      final started = <int>[];
      final run = mapWithConcurrency<int, int>(List.generate(6, (index) => index), 1, (
        value,
      ) async {
        started.add(value);
        if (value == 2) throw StateError('item 2 failed');
        return value;
      });

      await expectLater(run, throwsA(isA<StateError>()));
      expect(started, [0, 1, 2]);
    });
  });

  group('inOrder', () {
    test('finishes each step before it starts the next one', () async {
      final events = <String>[];
      await inOrder<int>([1, 2, 3], (value) async {
        events.add('start $value');
        await Future<void>.delayed(Duration(milliseconds: 4 - value));
        events.add('end $value');
      }, reason: 'The test needs strictly ordered steps');

      expect(events, ['start 1', 'end 1', 'start 2', 'end 2', 'start 3', 'end 3']);
    });

    test('stops at the first failing step', () async {
      final seen = <int>[];
      final run = inOrder<int>([1, 2, 3], (value) async {
        seen.add(value);
        if (value == 2) throw StateError('step 2 failed');
      }, reason: 'The test needs strictly ordered steps');

      await expectLater(run, throwsA(isA<StateError>()));
      expect(seen, [1, 2]);
    });
  });
}
