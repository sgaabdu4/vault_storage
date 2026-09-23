# Schema Management

## Full Schema Creation

Create tables + columns + indexes one atomic call. Read/write immediate. Fail → rollback all.

### Why

- **Atomic:** all-or-nothing, no partial schema
- **Synchronous:** table ready on return
- **Reliable:** kills setup script fail + race

### Usage

```dart
// Dart - Create table with columns and indexes atomically
await tablesDB.createTable(
    databaseId: 'db',
    tableId: 'posts',
    name: 'Posts',
    columns: [
        ColumnVarchar(key: 'title', size: 255, required: true),
        ColumnText(key: 'content'),
        ColumnVarchar(key: 'status', size: 20, default: 'draft'),
        ColumnInteger(key: 'views', default: 0),
        ColumnDatetime(key: 'publishedAt'),
    ],
    indexes: [
        Index(key: 'status_idx', type: IndexType.key, columns: ['status']),
        Index(key: 'published_idx', type: IndexType.key, columns: ['publishedAt']),
    ],
);
```

```python
# Python — same structure with snake_case
tables_db.create_table(
    database_id='db', table_id='posts', name='Posts',
    columns=[ColumnVarchar(key='title', size=255, required=True),
             ColumnText(key='content'),
             ColumnVarchar(key='status', size=20, default='draft'),
             ColumnInteger(key='views', default=0),
             ColumnDatetime(key='published_at')],
    indexes=[Index(key='status_idx', type=IndexType.KEY, columns=['status'])]
)
```

TypeScript same pattern, camelCase.

---

## Column Types

### Text

| Type | Max Chars | Storage | Indexing | Use Case |
|------|-----------|---------|----------|----------|
| `varchar` | 16,383 | Inline (counts toward 64KB row size) | Fully indexable if size < 768 | Names, slugs, identifiers — query/sort/filter |
| `text` | 16,383 | Off-page (20-byte pointer in row) | Prefix indexing only | Descriptions, notes — no full indexing |
| `mediumtext` | 4,194,303 | Off-page | Prefix indexing only | Articles, blog posts |
| `longtext` | 1,073,741,823 | Off-page | Prefix indexing only | Large documents |

> **`string` deprecated.** Abstracted 4 storage types by size. Use explicit types.

#### Varchar vs Text

Same max, different storage:
- **`varchar`** — inline, counts toward 64KB row budget. Full index when size < 768. Use for short queryable strings.
- **`text`** — off-page, 20-byte pointer. No row budget hit, prefix index only. Use when full index not needed.

### Numeric

| Type | Range | Parameters |
|------|-------|------------|
| `integer` | signed 32-bit | `min`, `max`, `default` |
| `bigint` | signed 64-bit | `min`, `max`, `default` |
| `float` | 64-bit | `min`, `max`, `default` |

JavaScript cannot represent every 64-bit `bigint` exactly. For JS/TS schema
automation, any supplied integer `min`, `max`, or `default` must satisfy
`Number.isSafeInteger`. Optional full-range bounds → omit; rounded bounds →
forbidden. Use a different exact SDK representation only after target proof.

### Other

| Type | Description |
|------|-------------|
| `boolean` | true/false |
| `datetime` | ISO 8601 timestamp |
| `email` | Validated email format |
| `url` | Validated URL format |
| `ip` | IPv4 or IPv6 address |
| `enum` | Predefined values (max 100 elements) |

### Spatial (Geo)

| Type | Format |
|------|--------|
| `point` | `[longitude, latitude]` |
| `line` | `[[lon1,lat1], [lon2,lat2], ...]` |
| `polygon` | `[[[lon,lat], ...]]` (closed ring) |

### Encrypted String

Encrypt at rest via AES-128-GCM. Non-queryable.

```dart
// Dart - Encrypted varchar column
await tablesDB.createVarcharColumn(
    databaseId: 'db',
    tableId: 'users',
    key: 'ssn',
    size: 20,
    encrypt: true,  // AES-128-GCM encryption
);
```

**Use for:** SSN, admin notes, IP addresses, sensitive IDs.

**Encrypted = store/retrieve only** — no query/filter/index.

---

## Index Types

| Type | Use Case |
|------|----------|
| `key` | WHERE, ORDER BY queries |
| `fulltext` | `Query.search()` text search |
| `unique` | Enforce uniqueness constraint |
| `spatial` | Geo queries on Point/Line/Polygon |

### Create Index

```dart
// Dart - Composite index (order by selectivity)
await tablesDB.createIndex(
    databaseId: 'db',
    tableId: 'posts',
    key: 'status_created_idx',
    type: IndexType.key,
    columns: ['status', '$createdAt'],  // Most selective first
    orders: [OrderBy.asc, OrderBy.desc],
);
```

### Index Rules

- Order by selectivity (most selective first)
- Scalar columns only (no arrays/relationships)
- `Query.search()` needs fulltext index
- Geo queries need spatial index
- `unique` violation surfaces as `409` `row_already_exists` naming the requested row ID, not the conflicting one → [error-handling.md](error-handling.md#409-row_already_exists)
- A counter feeding a `unique` tuple derives from the highest **retained** value across every row in that index scope; deriving it from the current owner's row resets after that row is purged and collides with a retained row owned by someone else

---

## Auto-Increment

Auto `$sequence` column, bumps each insert. Use for:

- Invoice numbers
- Activity logs
- Ordered timelines
- Paginated datasets

```dart
// Dart - Enable auto-increment on table
await tablesDB.createTable(
    databaseId: 'db',
    tableId: 'invoices',
    name: 'Invoices',
    autoIncrement: true,  // Adds $sequence column
    columns: [...],
);

// Query by sequence
final invoices = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'invoices',
    queries: [
        Query.orderAsc('$sequence'),
    ],
);
```

---

## Timestamp Overrides

Manual set `$createdAt`/`$updatedAt` for migrations. Keeps original timestamps.

```dart
// Dart - Import with original timestamps
await tablesDB.createRow(
    databaseId: 'db',
    tableId: 'orders',
    rowId: ID.unique(),
    data: {
        'product': 'Widget',
        '$createdAt': '2024-01-15T10:30:00.000Z',  // Original date
        '$updatedAt': '2024-01-15T10:30:00.000Z',
    },
);
```

```python
# Python
tables_db.create_row(
    database_id='db', table_id='orders', row_id=ID.unique(),
    data={'product': 'Widget',
          '$createdAt': '2024-01-15T10:30:00.000Z',
          '$updatedAt': '2024-01-15T10:30:00.000Z'})
```

**Use for:**
- Migration from other systems
- Backfill historical data
- Audit trail preservation

---

## Upsert

Create or update one call. Exist → update. Else → create.

```dart
// Dart - Upsert row
await tablesDB.upsertRow(
    databaseId: 'db',
    tableId: 'sessions',
    rowId: 'session_abc',
    data: {
        'userId': 'user_123',
        'lastActive': DateTime.now().toIso8601String(),
    },
);
```

Python `upsert_row()`, TypeScript `upsertRow()` — same params.

**Benefits:**
- One network call
- No race
- Cleaner (no if-exists)

---

## CSV Import/Export

### Import

Import CSV rows, no custom scripts.

```dart
// Via Appwrite Console or CLI
// Supports: column mapping, type validation
```

**Use for:**
- Data migration
- Seed test envs
- Bulk import

### Export

Export filtered data → CSV from Console.

**Features:**
- Queries before export
- Pick columns
- Custom delimiter
- Background execution
- Email on done

---

## Related

- Transactions — atomic multi-table ops
- Bulk ops — batch inserts
- Relationships — table connections
- [Production migrations](production-migrations.md) — expand/backfill/deploy/contract + readiness polling
