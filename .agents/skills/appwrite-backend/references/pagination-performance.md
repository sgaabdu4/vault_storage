# Pagination Performance

## The Rule

**Always use cursor pagination for paginated lists.**

## Why

Offset pagination degrades linear. DB reads N rows before return. At offset 10,000, reads 10,000 rows to skip.

Cursor jumps direct to target row via index. Constant perf regardless of position.

| Records | Offset 10,000 | Cursor |
|---------|---------------|--------|
| 10,000 | ~100ms | ~5ms |
| 100,000 | ~1,000ms | ~5ms |
| 1,000,000 | ~10,000ms | ~5ms |

## The Pattern

### Wrong (O(n))

```dart
// Slow - reads 10,000 rows to skip them
Query.offset(10000)
Query.limit(25)
```

```python
# Slow - scans rows sequentially
Query.offset(10000)
Query.limit(25)
```

```typescript
// Slow - performance degrades with position
Query.offset(10000)
Query.limit(25)
```

### Correct (O(1))

```dart
// Dart - Constant time regardless of position
final response = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'items',
    queries: [
        Query.cursorAfter(lastRowId),
        Query.limit(25),
    ],
    total: false,  // Skip counting for extra speed
);

// Store last ID for next page
final nextCursor = response.rows.last.$id;
```

```python
# Python - O(1) lookup
response = tables_db.list_rows(
    database_id='db',
    table_id='items',
    queries=[
        Query.cursor_after(last_row_id),
        Query.limit(25),
    ],
    total=False
)

next_cursor = response['rows'][-1]['$id']
```

```typescript
// TypeScript - Constant performance
const response = await tablesDB.listRows({
    databaseId: 'db',
    tableId: 'items',
    queries: [
        Query.cursorAfter(lastRowId),
        Query.limit(25),
    ],
    total: false,
});

const nextCursor = response.rows[response.rows.length - 1].$id;
```

## Combine with Skip Totals

`total=false` skips COUNT query — another full table scan. Combine w/ cursor for max perf.

```dart
// Maximum performance - cursor + skip total
final response = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'logs',
    queries: [
        Query.cursorAfter(lastId),
        Query.limit(100),
        Query.orderDesc('$createdAt'),
    ],
    total: false,  // response.total = 0, but rows returned normally
);
```

## When Offset is Acceptable

Small lookup tables <1,000 rows:
- Countries, currencies, categories
- Static config data
- Dropdown options

## Complete Pagination Pattern

```typescript
// TypeScript - Async generator for all rows
async function* fetchAllRows<T>(
    dbId: string,
    tableId: string,
    baseQueries: string[] = []
): AsyncGenerator<T[]> {
    let cursor: string | undefined;

    while (true) {
        const queries = [
            ...baseQueries,
            Query.limit(100),
        ];

        if (cursor) {
            queries.push(Query.cursorAfter(cursor));
        }

        const response = await tablesDB.listRows<T>({
            databaseId: dbId,
            tableId: tableId,
            queries,
            total: false,
        });

        if (response.rows.length === 0) break;

        yield response.rows;

        cursor = response.rows[response.rows.length - 1].$id;

        if (response.rows.length < 100) break;
    }
}

// Usage
for await (const batch of fetchAllRows('db', 'users')) {
    await processBatch(batch);
}
```

```dart
// Dart - Stream-based pagination
Stream<List<Map<String, dynamic>>> fetchAllRows(
    String dbId,
    String tableId,
    List<String> baseQueries,
) async* {
    String? cursor;

    while (true) {
        final queries = [
            ...baseQueries,
            Query.limit(100),
            if (cursor != null) Query.cursorAfter(cursor),
        ];

        final response = await tablesDB.listRows(
            databaseId: dbId,
            tableId: tableId,
            queries: queries,
            total: false,
        );

        if (response.rows.isEmpty) break;

        yield response.rows;

        cursor = response.rows.last.$id;

        if (response.rows.length < 100) break;
    }
}
```

```python
# Python - Generator for memory efficiency
def fetch_all_rows(db_id: str, table_id: str, base_queries: list = []):
    cursor = None

    while True:
        queries = base_queries.copy()
        queries.append(Query.limit(100))

        if cursor:
            queries.append(Query.cursor_after(cursor))

        response = tables_db.list_rows(
            database_id=db_id,
            table_id=table_id,
            queries=queries,
            total=False
        )

        rows = response['rows']
        if not rows:
            break

        yield rows

        cursor = rows[-1]['$id']

        if len(rows) < 100:
            break
```

## Flutter Mixin Pattern

Multiple datasources repeat same cursor loop. Mixin extracts once.

```dart
mixin AppwritePaginationMixin {
  TablesDB get tablesDB;

  static const _pageSize = 100;

  /// Fetches all rows from [tableId] matching [queries] via cursor pagination.
  /// Do not include Query.cursorAfter or Query.limit in [queries].
  /// Returns empty list on 404.
  Future<List<T>> fetchAllRows<T>({
    required String tableId,
    required List<String> queries,
    required T Function(Row row) mapRow,
  }) async {
    try {
      final results = <T>[];
      String? cursor;

      while (true) {
        final response = await tablesDB.listRows(
          databaseId: AppwriteConfig.databaseId,
          tableId: tableId,
          queries: [
            ...queries,
            if (cursor != null) Query.cursorAfter(cursor),
            Query.limit(_pageSize),
          ],
          total: false,
        );

        results.addAll(response.rows.map(mapRow));

        if (response.rows.length < _pageSize) break;
        cursor = response.rows.last.$id;
      }

      return results;
    } on AppwriteException catch (e) {
      if (e.code == 404) return [];
      rethrow;
    }
  }

  /// Fetches all row IDs from [tableId] matching [queries].
  Future<List<String>> fetchAllIds({
    required String tableId,
    required List<String> queries,
  }) =>
      fetchAllRows(
        tableId: tableId,
        queries: [...queries, Query.select([r'$id'])],
        mapRow: (row) => row.$id,
      );
}
```

### Usage

```dart
class ExerciseRemoteDatasource with AppwritePaginationMixin {
  ExerciseRemoteDatasource(this._tablesDB);
  final TablesDB _tablesDB;

  @override
  TablesDB get tablesDB => _tablesDB;

  Future<List<Exercise>> getAll(String userId) => fetchAllRows(
        tableId: AppwriteConfig.exercisesTableId,
        queries: [Query.equal('user_id', userId)],
        mapRow: (row) => Exercise.fromRow(row),
      );

  Future<List<String>> getAllIds(String userId) => fetchAllIds(
        tableId: AppwriteConfig.exercisesTableId,
        queries: [Query.equal('user_id', userId)],
      );
}
```

### Design decisions

- **Mixin over inheritance** — datasources may extend other class; mixins no conflict
- **Generic `mapRow` callback** — each datasource maps own types; mixin handles pagination only
- **404 → empty list** — table/rows may not exist yet for new user
- **`total: false` always** — skips COUNT query (see above)
- **Centralized `databaseId`** — reads from `AppwriteConfig` not param

## Impact

- **Latency:** 10-100x faster on large datasets
- **Cost:** less DB CPU
- **DRY:** ~50 lines removed per datasource w/ mixin

## Related

- Skip totals for count elimination
- Indexes for query perf
- Query.select() for payload reduction
