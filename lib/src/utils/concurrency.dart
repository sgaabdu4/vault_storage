Future<List<R>> mapWithConcurrency<T, R>(
  Iterable<T> items,
  int limit,
  Future<R> Function(T item) task,
) async {
  assert(limit > 0, 'limit must be positive');
  final queue = items.toList();
  final results = <int, R>{};
  var next = 0;
  Future<void> worker() async {
    while (next < queue.length) {
      final index = next;
      next = index + 1;
      try {
        results[index] = await task(queue[index]);
      } catch (_) {
        next = queue.length;
        rethrow;
      }
    }
  }

  final workers = limit < queue.length ? limit : queue.length;
  await Future.wait(List.generate(workers, (_) => worker()));
  return [for (var index = 0; index < queue.length; index++) results[index] as R];
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
