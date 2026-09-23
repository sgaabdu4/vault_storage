# Performance Optimization

## Quick Reference

| Technique | Impact | Details |
|-----------|--------|---------|
| Cursor pagination | 100x faster at scale | [pagination-performance.md](pagination-performance.md) |
| Query.select() | 12-18x for relationships | [relationships.md](relationships.md) |
| Skip totals | Eliminates COUNT scan | [pagination-performance.md](pagination-performance.md) |
| Indexes | 100x faster queries | [schema-management.md](schema-management.md) |
| Atomic operators | Eliminates race conditions | [atomic-operators.md](atomic-operators.md) |
| Bulk operations | N requests → 1 | [bulk-operations.md](bulk-operations.md) |
| Realtime | WebSocket vs polling | [realtime.md](realtime.md) |
| Image caching | WebP/AVIF 30-55% smaller | [storage-files.md](storage-files.md) |
| Redis cache (self-hosted) | Cut DB reads hot data | See below |

---

## Checklist

Pre-deploy:

- [ ] All filter/sort columns indexed
- [ ] Lists use `Query.select()` for needed fields only
- [ ] Pagination uses cursor (not offset) for >100 rows
- [ ] `total: false` for infinite scroll
- [ ] Counters use `Operator.increment()`
- [ ] Bulk creates use `createRows()` not loops
- [ ] ID queries chunked when >100 IDs
- [ ] Realtime replaces polling
- [ ] Images use WebP/AVIF at quality 80

---

## Red Flags

| Symptom | Cause | Fix |
|---------|-------|-----|
| Query >500ms | Missing index | Add index for queried columns |
| Latency grows over time | Offset pagination | Switch to cursor |
| High client memory | Fetch all data | Use generators |
| Duplicate data in responses | Missing Query.select() | Select only needed fields |
| Lost counter updates | Read-modify-write | Use Operator.increment() |

---

## Performance Targets

| Operation | Target |
|-----------|--------|
| Single row get | <50ms |
| List (25 rows) | <100ms |
| Full-text search | <200ms |
| Bulk (100 rows) | <500ms |

## Dependency-Aware Bootstrap

- Graph = resource/read → dependency edges → ready waves.
- Execute one wave with bounded concurrency + one deadline; preserve deterministic result order.
- Fully serial independent reads = latency risk; unbounded fan-out = connection/runtime starvation risk.
- Bound = measured target capacity; transient retry = idempotent read only + bounded backoff.
- Proof = dependency order + peak concurrency + timeout + partial-failure cancellation + final latency receipt.

---

## Self-Hosted: Redis Caching

Self-hosted Appwrite ships Redis. Cache frequent reads, cut DB load.

### Cache-Aside Pattern (Function-Level)

```dart
import 'dart:convert';
import 'package:redis/redis.dart';

final redis = RedisConnection();
Command? _cmd;

Future<Command> getRedis() async {
    _cmd ??= await redis.connect('localhost', 6379);
    return _cmd!;
}

Future<Map<String, dynamic>> getCachedRow(String key, Future<Map<String, dynamic>> Function() fetch) async {
    final cmd = await getRedis();
    final cached = await cmd.get(key);

    if (cached != null) return jsonDecode(cached as String);

    final data = await fetch();
    await cmd.send_object(['SET', key, jsonEncode(data), 'EX', '300']); // 5 min TTL
    return data;
}
```

### When to Cache

| Cache | Skip Cache |
|-------|-----------|
| User profiles read 100x/min | Data changes every request |
| Config/settings (rarely change) | Writes (go to TablesDB) |
| Computed aggregations | Security-sensitive data |
| API responses shared across users | Per-user real-time data |

### Invalidation

Invalidate on write. Appwrite event triggers clear stale entries:

```dart
// In your data-update function: clear the cache key after writing
await cmd.send_object(['DEL', 'user:$userId']);
```

---

## Delta Sync (Incremental Pull)

Fetch only rows changed since last sync, not re-download all. Uses `Query.updatedAfter()` with per-table timestamps.

### Pattern

```dart
Future<List<T>> fetchUpdatedSince(String userId, DateTime since) async {
  final results = <T>[];
  String? cursor;

  while (true) {
    final rows = await tablesDB.listRows(
      databaseId: dbId,
      tableId: tableId,
      queries: [
        Query.equal('user_id', userId),
        Query.updatedAfter(since.toUtc().toIso8601String()),
        if (cursor != null) Query.cursorAfter(cursor),
        Query.limit(100),
      ],
    );
    results.addAll(rows.rows.map(fromRow));
    if (rows.rows.length < 100) break;
    cursor = rows.rows.last.$id;
  }
  return results;
}
```

### Lightweight ID Fetch for Deletion Detection

```dart
Future<List<String>> fetchAllIds(String userId) async {
  final ids = <String>[];
  String? cursor;

  while (true) {
    final rows = await tablesDB.listRows(
      databaseId: dbId,
      tableId: tableId,
      queries: [
        Query.equal('user_id', userId),
        Query.select([r'$id']),
        if (cursor != null) Query.cursorAfter(cursor),
        Query.limit(100),
      ],
    );
    ids.addAll(rows.rows.map((r) => r.$id));
    if (rows.rows.length < 100) break;
    cursor = rows.rows.last.$id;
  }
  return ids;
}
```

### Sync Flow

1. Store per-table `lastSyncDate` locally after each sync
2. Next sync: call `fetchUpdatedSince(lastSyncDate)` — merge changed rows locally
3. Call `fetchAllIds()` — diff vs local IDs, delete missing
4. Store new `lastSyncDate`

**First sync fallback:** No per-table date → full `getAll()` pull once, then switch to delta.

### When to Use

| Scenario | Approach |
|----------|----------|
| Data rarely changes | Delta sync — fetches nothing on no change |
| Frequent small edits | Delta sync — fetches only changed rows |
| Full refresh needed | Full `getAll()` pull |
| Real-time updates | Realtime subscriptions (not delta sync) |

---

## Related

- [pagination-performance.md](pagination-performance.md) — Cursor patterns, generators
- [query-optimization.md](query-optimization.md) — Index strategy, spatial
- [atomic-operators.md](atomic-operators.md) — Thread-safe updates
- [bulk-operations.md](bulk-operations.md) — Mass operations
- [limits.md](limits.md) — Platform limits
