# Realtime

## Connection

Subscribe changes via WebSocket.

```dart
// Dart
final realtime = Realtime(client);

final subscription = realtime.subscribe([
    'tablesdb.products.tables.items.rows',
]);

subscription.stream.listen((event) {
    print('Event: ${event.events}');
    print('Payload: ${event.payload}');
});
```

```python
# Python (async)
from appwrite.realtime import Realtime
import asyncio

realtime = Realtime(client)

async def listen():
    async for event in realtime.subscribe(['tablesdb.products.tables.items.rows']):
        print(f'Event: {event.events}')
        print(f'Payload: {event.payload}')

asyncio.run(listen())
```

```typescript
// TypeScript (Node/Deno)
import { Client, Realtime } from 'node-appwrite';

const realtime = new Realtime(client);

realtime.subscribe(['tablesdb.products.tables.items.rows'], (event) => {
    console.log('Event:', event.events);
    console.log('Payload:', event.payload);
});
```

---

## Channel Patterns

### TablesDB

```
tablesdb.[DATABASE_ID].tables.[TABLE_ID].rows                # All rows
tablesdb.[DATABASE_ID].tables.[TABLE_ID].rows.[ROW_ID]       # Specific row
```

### Storage

```
buckets.[BUCKET_ID].files                # All files
buckets.[BUCKET_ID].files.[FILE_ID]      # Specific file
```

### Authentication

```
account                                  # Current user changes
```

### Teams

```
teams                                    # Teams the user belongs to
teams.[TEAM_ID]                          # Specific team
memberships                              # User's memberships
memberships.[MEMBERSHIP_ID]              # Specific membership
```

Membership channels drive live role changes — subscribe when UI capability
depends on team role, instead of re-fetching memberships on navigation.

### Functions

```
functions.[FUNCTION_ID].executions       # Function executions
```

Async `createExecution` reconciliation subscribes here rather than polling
`getExecution` — see Invariant 7 in [SKILL.md](../SKILL.md).

### Presences

```
presences                               # All readable presences
presences.[PRESENCE_ID]                 # Specific presence
```

---

## Channel Helpers (Type-Safe)

Use `Channel` class, not raw strings. Gives IDE autocomplete, compile-time validation, self-documenting subs. In the Web and Flutter client SDKs. Old string channels still work.

```typescript
// TypeScript (Client SDK)
import { Client, Realtime, Channel } from "appwrite";

const realtime = new Realtime(client);

// Specific row
const sub = await realtime.subscribe(
    Channel.tablesdb('<DATABASE_ID>').table('<TABLE_ID>').row('<ROW_ID>'),
    response => console.log(response)
);

// All rows in a table
Channel.tablesdb('<DATABASE_ID>').table('<TABLE_ID>').row()

// Only row updates (not creates/deletes)
Channel.tablesdb('<DATABASE_ID>').table('<TABLE_ID>').row().update()

// Account events
Channel.account()

// Storage files
Channel.files()

// Presences, when SDK supports it
Channel.presences()
```

```dart
// Dart (Client SDK)
import 'package:appwrite/appwrite.dart';

final realtime = Realtime(client);

final sub = await realtime.subscribe(
    Channel.tablesdb('<DATABASE_ID>').table('<TABLE_ID>').row('<ROW_ID>'),
    (response) => print(response),
);
```

### Event Filtering with Helpers

Chain `.create()`, `.update()`, `.delete()` to filter by event type:

```typescript
// Only row updates in a table
Channel.tablesdb('<DB>').table('<TABLE>').row().update()

// Only new files
Channel.files().create()
```

### Multiple Channels with Helpers

```typescript
const sub = await realtime.subscribe([
    Channel.tablesdb('<DB>').table('<TABLE>').row('<ROW_ID>'),
    Channel.files()
], response => console.log(response));
```

---

## Realtime Queries (Server-Side Filtering)

Pass `Query` helpers on subscribe to filter events server-side. Callback fires only on payload match. Same query syntax as TablesDB.

```typescript
import { Client, Realtime, Channel, Query } from "appwrite";

const realtime = new Realtime(client);

// All row events (no filter)
const all = await realtime.subscribe(
    Channel.tablesdb('<DB>').table('<TABLE>').row(),
    response => console.log(response.payload)
);

// Only events where person equals 'person1'
const filtered = await realtime.subscribe(
    Channel.tablesdb('<DB>').table('<TABLE>').row(),
    response => console.log(response.payload),
    [Query.equal('person', ['person1'])]
);

// Only events where person is NOT 'person1'
const excluded = await realtime.subscribe(
    Channel.tablesdb('<DB>').table('<TABLE>').row(),
    response => console.log(response.payload),
    [Query.notEqual('person', 'person1')]
);
```

### Supported Realtime Queries

**Comparison:** `Query.equal()` | `Query.notEqual()` | `Query.greaterThan()` | `Query.greaterThanEqual()` | `Query.lessThan()` | `Query.lessThanEqual()`

**Null checks:** `Query.isNull()` | `Query.isNotNull()`

**Logical:** `Query.and()` | `Query.or()`

---

## Presences API

Use Presences for ephemeral online/typing/active state. Presences have status, optional metadata, permissions, Realtime events, and `expiresAt` auto-expiry. Prefer this over durable table rows + cleanup cron for short-lived user status.

Patterns:
- Upsert on focus, route change, heartbeat, or typing state.
- Set short `expiresAt`; max is 30 days.
- Subscribe with `Channel.presences()` / `presences` and Realtime queries when supported.
- Scope permissions so only intended users can read presence state.

---

## Event Types

| Event | Description |
|-------|-------------|
| `*.create` | Row/file/resource created |
| `*.update` | Row/file/resource updated |
| `*.delete` | Row/file/resource deleted |
| `*.upsert` | Presence created or refreshed |

### Filter by Event

```dart
// Dart - Listen only to creates
subscription.stream
    .where((e) => e.events.any((ev) => ev.endsWith('.create')))
    .listen((event) {
        print('New row: ${event.payload}');
    });
```

---

## Multiple Channels

Subscribe many channels at once.

```dart
// Dart
final subscription = realtime.subscribe([
    'tablesdb.main.tables.orders.rows',
    'tablesdb.main.tables.products.rows',
    'account',
]);
```

---

## Unsubscribe

```dart
// Dart
subscription.close();
```

```typescript
// TypeScript
subscription.close();
```

---

## Bulk Operation Events

Realtime fires for bulk ops too.

```dart
// Bulk update triggers events for each affected row
await tablesdb.updateRows(
    databaseId: 'main',
    tableId: 'products',
    queries: [Query.equal('category', 'electronics')],
    data: {'onSale': true},
);
// Each row fires update event
```

---

## Permissions

Users get events only for resources they can read.

```dart
// User A subscribes to orders
// User B creates order with permissions for User B only
// User A receives nothing - no permission
```

---

## Connection Management

### Reconnection

SDKs auto-reconnect on disconnect.

### Connection Status

```typescript
// TypeScript - Monitor connection
realtime.on('connected', () => console.log('Connected'));
realtime.on('disconnected', () => console.log('Disconnected'));
```

---

## Rate Limits

| Limit | Value |
|-------|-------|
| Connections per IP | 100 |
| Subscriptions per connection | 1000 |

---

## Versioning Pattern (Cache Invalidation)

Make version row, subscribe to it instead of poll. Re-fetch on version update.

```dart
// 1. Create a version row (one per table/resource group)
await tablesdb.createRow(
    databaseId: 'main',
    tableId: 'versions',
    rowId: 'products-version',
    data: {'version': 1},
);

// 2. Subscribe to the version row
final subscription = realtime.subscribe([
    'tablesdb.main.tables.versions.rows.products-version',
]);

// 3. Re-fetch products only when version changes
subscription.stream.listen((event) {
    if (event.events.any((e) => e.endsWith('.update'))) {
        // Version changed — data is stale, re-fetch
        refreshProducts();
    }
});

// 4. Bump version when products change (server-side function)
await tablesdb.updateRow(
    databaseId: 'main',
    tableId: 'versions',
    rowId: 'products-version',
    data: {'version': currentVersion + 1},
);
```

Versioning swaps periodic polling for one light sub. Clients idle til data change.

---

## Performance Tips

1. **Subscribe specific channels** — No broad subs
2. **Filter server-side** — Realtime queries cut callback noise
3. **Use Channel helpers** — Type-safe, compile-time errors
4. **Unsubscribe when done** — Clean up subs
5. **Batch UI updates** — Debounce rapid events
6. **Use versioning pattern** — One sub replaces repeat polling

---

## SSR Considerations

Realtime needs WebSocket. For SSR:

```typescript
// TypeScript - Check for browser
if (typeof window !== 'undefined') {
    const subscription = realtime.subscribe(['tablesdb.main.tables.data.rows']);
}
```

---

## Related

- TablesDB for data ops
- Functions for event processing
