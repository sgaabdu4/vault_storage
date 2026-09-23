# Platform Limits

## Query Limits

| Limit | Value | Notes |
|-------|-------|-------|
| `Query.equal()` array values | 100 max | Chunk larger ID lists |
| Query nesting depth | 3 levels | `Query.and([Query.or([...])])` |
| Queries per request | 100 max | Each 4096 chars max |
| Results per page | 25 default, no hard cap | Large pages slow performance |
| Relationship depth | 3 levels | Deepest supported depth |

### Chunking Large ID Lists

>100 values in `Query.equal()` throws. Chunk to 100, fetch parallel.

**Full patterns:** See [chunked-queries.md](chunked-queries.md).

---

## Authentication Limits

| Limit | Value | Config |
|-------|-------|--------|
| Sessions per user | 10 default, 100 max | Console → Auth → Security |
| Password length | 8-256 chars | — |
| Password history | 20 max | Console → Auth → Security |
| User name | 128 chars | — |
| User ID | 36 chars | a-z, A-Z, 0-9, `.`, `-`, `_` |
| Preferences size | 64KB | JSON object |
| JWT duration | 900s default, 3600s max | `account.createJWT({duration: 3600})` |
| OAuth scopes | 100 max, 4096 chars each | — |
| OTP validity | 15 minutes | Email token, phone token |
| Magic URL validity | 1 hour | — |
| Verification link | 7 days | Email verification |
| Recovery link | 1 hour | Password recovery |

### Preferences 64KB Limit

```dart
// ❌ May exceed 64KB
await account.updatePrefs(prefs: largeObject);

// ✅ Store large data in database row
await tablesDB.updateRow(
    databaseId: 'db',
    tableId: 'user_settings',
    rowId: userId,
    data: {'settings': largeObject},
);
```

### Session Limit Behavior

Over limit → oldest session auto-deleted.

```dart
// Check active sessions
final sessions = await account.listSessions();
print('Active: ${sessions.sessions.length}');

// Delete specific session
await account.deleteSession(sessionId: 'session_id');

// Delete all sessions except current
await account.deleteSessions();
```

---

## Storage Limits

| Limit | Value | Notes |
|-------|-------|-------|
| File extensions per bucket | 100 max | Leave blank for all types |
| Encryption/compression | Files <20MB | Appwrite skips both for larger files |
| Large file chunking | >5MB | Automatic in SDKs |
| Max file size | Bucket-configurable | Console → Storage → Bucket |

### Large File Upload

SDKs chunk >5MB auto.

```dart
// Dart - Works automatically for any size
await storage.createFile(
    bucketId: 'uploads',
    fileId: ID.unique(),
    file: InputFile.fromPath(path: '/large-file.zip'),
);
```

### Encryption/Compression Limits

```dart
// Files >20MB: Appwrite skips encryption even if the bucket enables it
// Files >20MB: Appwrite skips compression even if the bucket enables it

// For sensitive large files, encrypt before upload
final encrypted = await encryptLocally(largeFile);
await storage.createFile(file: InputFile.fromBuffer(encrypted));
```

---

## Database Limits

| Limit | Self-hosted `1.9.0` fallback | Notes |
|-------|------------------------------|-------|
| Relationship nesting | 3 levels | `Query.select(['a.*', 'a.b.*', 'a.b.c.*'])` |
| String column size | Increase only | Minimum stays at largest stored value |
| Indexes per table | — | Each query/order needs index |
| Bulk rows/request | 100 | Bind deployed source/config; create/update/upsert/delete; server SDK only |
| Transaction operations | 100 | Bind deployed source/config; bulk call = one staged operation; separate row/request cap still applies |
| Offset pagination | O(n) performance | Use cursor for large datasets |

Bulk update/delete with empty queries target every row. Bulk operations reject tables with relationship columns and are atomic per request. Multiple requests are not one atomic unit. See [bulk-operations.md](bulk-operations.md) + [transactions.md](transactions.md).

Source: Appwrite `1.9.0` [`APP_LIMIT_DATABASE_BATCH` + `APP_LIMIT_DATABASE_TRANSACTION`](https://github.com/appwrite/appwrite/blob/1.9.0/app/init/constants.php#L41-L42). Target source/config wins over this fallback.

### Relationship Depth

```dart
// ✅ Valid: 3 levels deep
Query.select(['*', 'author.*', 'author.company.*', 'author.company.ceo.*'])

// ❌ Invalid: 4+ levels
Query.select(['*', 'author.company.ceo.assistant.*'])
```

Cursor pagination for >1,000 rows. See [pagination-performance.md](pagination-performance.md).

---

## Function Limits

| Limit | Source of truth |
|-------|-----------------|
| Timeout | `timeout` in `appwrite.config.json` / Console |
| Memory + CPU | `runtimeSpecification` (build: `buildSpecification`) |
| Concurrent executions | Deployed plan/server config |
| Environment vars | `.env` in the function `path`; some resolve at build only |

Bind the deployed value before sizing a function path; never assume a ceiling.
Config fields = [appwrite-cli.md](appwrite-cli.md).

---

## Rate Limits

Rate-limit scope, `X-RateLimit-*` headers, 429 handling, and backoff are owned
by [error-handling.md](error-handling.md).

---

## Request Limits

| Limit | Value |
|-------|-------|
| Request body | 10MB default |
| API timeout | 15 seconds |
| Webhook timeout | 30 seconds |

---

## Common Limit Errors

| Error | Cause | Fix |
|-------|-------|-----|
| 400: Value must be at most 100 | Query.equal() >100 values | Chunk ID list |
| 400: Preferences size exceeded | >64KB prefs | Store in database |
| 400: ID already exists | Duplicate row ID | Use `ID.unique()` |
| 413: Request too large | >10MB body | Chunk upload |
| 429: Too many requests | Rate limited | Exponential backoff |
| 504: Gateway timeout | Query >15s | Add indexes, reduce scope |

---

## Related

- [error-handling.md](error-handling.md) — Rate limiting, backoff
- [performance.md](performance.md) — Optimization techniques
- [bulk-operations.md](bulk-operations.md) — Chunking patterns
- [pagination-performance.md](pagination-performance.md) — Cursor pagination
