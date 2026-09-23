# Chunked ID Queries

`Query.equal()` max 100 IDs per call. Chunk bigger lists.

## Dart

```dart
/// Fetch rows by ID list, chunking to avoid 100-value limit.
Future<List<Map<String, dynamic>>> fetchByIds(
    String dbId, String tableId, List<String> ids,
    {List<String> select = const []}) async {
    if (ids.isEmpty) return [];

    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 100) {
        chunks.add(ids.skip(i).take(100).toList());
    }

    final results = await Future.wait(
        chunks.map((chunk) => tablesDB.listRows(
            databaseId: dbId, tableId: tableId,
            queries: [
                Query.equal('\$id', chunk),
                if (select.isNotEmpty) Query.select(select),
            ],
            total: false,
        )),
    );

    return results.expand((r) => r.rows).toList();
}

// Usage
final patients = await fetchByIds('db', 'patients', patientIds,
    select: ['name', 'email', 'phone']);
```

---

## Python

```python
import asyncio
from typing import List

async def fetch_by_ids(
    db_id: str, table_id: str, ids: List[str],
    select: List[str] = None,
) -> List[dict]:
    """Fetch rows by ID list, chunking to avoid 100-value limit."""
    if not ids:
        return []

    chunks = [ids[i:i + 100] for i in range(0, len(ids), 100)]

    async def fetch_chunk(chunk):
        queries = [Query.equal('$id', chunk)]
        if select:
            queries.append(Query.select(select))
        return tables_db.list_rows(
            database_id=db_id, table_id=table_id,
            queries=queries, total=False,
        )

    results = await asyncio.gather(*[fetch_chunk(c) for c in chunks])
    return [row for result in results for row in result['rows']]

# Sync version
def fetch_by_ids_sync(db_id, table_id, ids, select=None):
    if not ids:
        return []
    chunks = [ids[i:i + 100] for i in range(0, len(ids), 100)]
    rows = []
    for chunk in chunks:
        queries = [Query.equal('$id', chunk)]
        if select:
            queries.append(Query.select(select))
        result = tables_db.list_rows(
            database_id=db_id, table_id=table_id,
            queries=queries, total=False,
        )
        rows.extend(result['rows'])
    return rows
```

---

## TypeScript

```typescript
async function fetchByIds<T>(
    dbId: string, tableId: string, ids: string[],
    select?: string[],
): Promise<T[]> {
    if (ids.length === 0) return [];

    const chunks: string[][] = [];
    for (let i = 0; i < ids.length; i += 100) {
        chunks.push(ids.slice(i, i + 100));
    }

    const results = await Promise.all(
        chunks.map(chunk => tablesDB.listRows<T>({
            databaseId: dbId, tableId: tableId,
            queries: [
                Query.equal('$id', chunk),
                ...(select ? [Query.select(select)] : []),
            ],
            total: false,
        })),
    );

    return results.flatMap(r => r.rows);
}

// Usage
const patients = await fetchByIds<Patient>('db', 'patients', patientIds,
    ['name', 'email', 'phone']);
```

---

## When to Use

- Fetch specific rows by known IDs
- Load related data from ID refs
- Faster than fetch-all + in-memory filter

---

## Related

- [bulk-operations.md](bulk-operations.md) — Bulk create/update/delete
- [query-optimization.md](query-optimization.md) — Query patterns
