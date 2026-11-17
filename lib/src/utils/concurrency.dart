Future<List<R>> mapWithConcurrency<T, R>(
  Iterable<T> items,
  int limit,
  Future<R> Function(T item) task,
) async {
  assert(limit > 0, 'limit must be positive');
  final queue = items.toList();
  final results = <({int index, R result})>[];
  int next = 0;

  final workers = limit < queue.length ? limit : queue.length;
  await Future.wait(
    List.generate(workers, (_) async {
      while (next < queue.length) {
        final index = next++;
        try {
          results.add((index: index, result: await task(queue[index])));
        } catch (_) {
          next = queue.length;
          rethrow;
        }
      }
    }),
  );
  results.sort((a, b) => a.index.compareTo(b.index));
  return [for (final (:result, index: _) in results) result];
}

Future<void> inOrder<T>(
  Iterable<T> items,
  Future<void> Function(T item) step, {
  required String reason,
}) async {
  for (final item in items) {
    await step(item);
  }
}
