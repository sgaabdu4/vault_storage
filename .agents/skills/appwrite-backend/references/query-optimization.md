# Query Optimization

## Query.select() Rule

**Always use Query.select(). Controls payload size, expands relationships.**

- Select fields = ordered + non-empty + unique; duplicate attribute = local contract FAIL before Appwrite.
- Reusable oracle = `scripts/appwrite-query-contract.mjs`; project test owns its adapter/query decoding.

### Why

No select:
- Returns all columns (waste bandwidth)
- Relationships return IDs only (useless)

With select:
- Returns only requested columns (smaller payload)
- Relationships return full objects (12-18x faster vs N+1)

### Example

```dart
// ❌ WRONG - All columns, relationships as IDs
final posts = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'posts',
);
// posts[0]['author'] = 'user_123' (ID string, not useful)
```

```dart
// ✅ CORRECT - Selected columns, expanded relationships
final posts = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'posts',
    queries: [
        Query.select(['title', 'author.name', 'author.avatar']),
    ],
);
// posts[0]['author'] = {'name': 'Alice', 'avatar': '...'} (full object)
```

---

## Inversion Queries

Filter by exclusion. No client-side fetch+filter.
Use `contains/notContains` only on real string/array/spatial fields. For JSON/text identity/dedupe, query indexed scalars. Dart Row: avoid user column `data`; legacy schemas need scalar selects or isolated SDK `Client.call`.

| Query | Description |
|-------|-------------|
| `Query.notSearch(attr, value)` | Text no match search |
| `Query.notContains(attr, value)` | Array/string no contain |
| `Query.notBetween(attr, start, end)` | Value outside range |
| `Query.notStartsWith(attr, value)` | No start with prefix |
| `Query.notEndsWith(attr, value)` | No end with suffix |

### Example

```dart
// Dart - Exclude archived posts
final activePosts = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'posts',
    queries: [
        Query.notEqual('status', 'archived'),
        Query.notContains('tags', 'hidden'),
    ],
);
```

```python
# Python - Exclude premium content for free users
free_content = tables_db.list_rows(
    database_id='db',
    table_id='content',
    queries=[
        Query.not_contains('tier', 'premium'),
        Query.not_between('price', 1, 1000),  # Only free items
    ]
)
```

---

## Time Helper Queries

Cleaner time filter.

| Query | Description |
|-------|-------------|
| `Query.createdBefore(datetime)` | Created before timestamp |
| `Query.createdAfter(datetime)` | Created after timestamp |
| `Query.updatedBefore(datetime)` | Updated before timestamp |
| `Query.updatedAfter(datetime)` | Updated after timestamp |

Combine `createdAfter` + `createdBefore` for range.

### Example

```dart
// Dart - Posts from last 7 days
final recentPosts = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'posts',
    queries: [
        Query.createdAfter(DateTime.now().subtract(Duration(days: 7)).toIso8601String()),
    ],
);
```

```python
# Python - Orders updated today
from datetime import datetime, timedelta

today = datetime.now().replace(hour=0, minute=0, second=0).isoformat()
orders = tables_db.list_rows(
    database_id='db',
    table_id='orders',
    queries=[
        Query.updated_after(today),
    ]
)
```

---

## Spatial Queries

Geo filter via spatial index.

### Distance Queries

| Query | Description |
|-------|-------------|
| `Query.distanceLessThan(attr, [lon,lat], meters)` | Within radius |
| `Query.distanceGreaterThan(attr, [lon,lat], meters)` | Outside radius |
| `Query.distanceEqual(attr, [lon,lat], meters)` | At exact distance |
| `Query.distanceNotEqual(attr, [lon,lat], meters)` | Not at distance |

### Geometry Queries

| Query | Description |
|-------|-------------|
| `Query.intersects(attr, geometry)` | Share space |
| `Query.notIntersects(attr, geometry)` | No shared space |
| `Query.overlaps(attr, geometry)` | Partial overlap |
| `Query.notOverlaps(attr, geometry)` | No partial overlap |
| `Query.touches(attr, geometry)` | Boundaries touch |
| `Query.notTouches(attr, geometry)` | Boundaries no touch |
| `Query.crosses(attr, geometry)` | Line crosses geometry |
| `Query.notCrosses(attr, geometry)` | Line no cross |

Spatial columns also support: `Query.equal`, `Query.notEqual`, `Query.contains`, `Query.notContains`.

### Examples

```dart
// Dart - Stores within 5km radius
final nearbyStores = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'stores',
    queries: [
        Query.distanceLessThan('location', [-122.4194, 37.7749], 5000),
    ],
);

// Stores between 1-5km (combine two distance queries)
final midRangeStores = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'stores',
    queries: [
        Query.distanceGreaterThan('location', [-122.4194, 37.7749], 1000),
        Query.distanceLessThan('location', [-122.4194, 37.7749], 5000),
    ],
);

// Delivery zones that touch
final adjacentZones = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'zones',
    queries: [
        Query.touches('boundary', currentZonePolygon),
    ],
);
```

```typescript
// TypeScript - Routes crossing restricted area
const violations = await tablesDB.listRows({
    databaseId: 'db',
    tableId: 'routes',
    queries: [
        Query.crosses('path', restrictedArea),
    ],
});
```

**Requirements:**
- Column type: `point`, `line`, or `polygon`
- Geo queries need spatial index for perf

---

## SDK Query Method Names

The concepts are shared, but method casing differs by SDK.

| Concept | Dart / TypeScript | Python |
|---------|-------------------|--------|
| Not equal | `Query.notEqual()` | `Query.not_equal()` |
| Less than/equal | `Query.lessThanEqual()` | `Query.less_than_equal()` |
| Greater than/equal | `Query.greaterThanEqual()` | `Query.greater_than_equal()` |
| Cursor after | `Query.cursorAfter()` | `Query.cursor_after()` |
| Cursor before | `Query.cursorBefore()` | `Query.cursor_before()` |
| OR | `Query.or()` | `Query.or_queries()` |
| AND | `Query.and()` | `Query.and_queries()` |

Python SDK calls should use keyword arguments:

```python
rows = tables_db.list_rows(
    database_id='db',
    table_id='orders',
    queries=[
        Query.not_equal('status', 'archived'),
        Query.cursor_after(last_id),
    ],
    total=False,
)
```

---

## Logical Operators

Combine via AND/OR.

```dart
// Dart - Complex conditions
final results = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'products',
    queries: [
        Query.or([
            Query.equal('category', 'electronics'),
            Query.and([
                Query.equal('category', 'accessories'),
                Query.greaterThan('price', 50),
            ]),
        ]),
    ],
);
```

**Nest limit:** 3 levels max

---

## Query Limits

Owned by [limits.md](limits.md).

---

## Index Requirements

| Query Type | Index Required |
|------------|----------------|
| `Query.equal()` | key |
| `Query.search()` | fulltext |
| `Query.orderAsc/Desc()` | key |
| `Query.distanceLessThan()` | spatial |
| `Query.intersects()` | spatial |

No index → scan whole table.

---

## Related

- [performance.md](performance.md) — Optimization checklist
- [schema-management.md](schema-management.md) — Index creation
- [relationships.md](relationships.md) — Joins
