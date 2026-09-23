# Functions Best Practices

## Architecture

**Group functions by domain.** Each function own one domain — not one operation, not everything.
Use official SDK packages only. For self-hosted Appwrite `1.9.x`, use the release-matched Dart Functions/server pin in [self-hosting.md](self-hosting.md); for Appwrite Cloud, use the latest stable SDK supported by the runtime.

```
✅ api-users          — all user endpoints (CRUD, profile, settings)
✅ api-orders         — order creation, status, cancellation
✅ api-notifications  — email, push, SMS triggers
✅ process-images     — resize, convert, thumbnail
✅ scheduled-cleanup  — daily/weekly maintenance tasks
❌ handle-everything  — one monolith doing all domains
❌ create-user        — one function per operation
```

**Warm-start advantage:** More requests per function = instances stay warm. Function handling 50 user ops gets 50x traffic vs one handling just "create user" — rarely cold-starts.

### Route Handling Inside Domain Functions

Extract request values at the runtime entrypoint; pass typed inputs to domain handlers.

```dart
Future<Object?> routeRead(String method, String path) async {
    if (method == 'GET' && path == '/users') return listUsers();
    if (method == 'GET' && path.startsWith('/users/')) return getUser(path);
    return {'error': 'Not found'};
}
```

### When to Split

Split when domain function has ops w/ vastly different resource needs, exceeds timeout, or needs different API key scopes.

---

## Cold Start Optimization

### Language Choice

Cloud runtime note: Appwrite Cloud supports Dart `3.12` for Functions. Self-hosted runtimes depend on the installed Appwrite image and `_APP_FUNCTIONS_RUNTIMES`.

Runtime SDK floor binds the whole pubspec, dev dependencies included:

- runtime `dart-3.5` builds with Dart SDK `3.5.4`
- the remote build resolves `dev_dependencies` → any dev-only package demanding a higher SDK fails the build in `dart pub get` with `version solving failed`
- `lints: ^6.1.0` requires SDK `^3.8.0` → pin `lints: ^5.0.0` while the configured runtime is `dart-3.5`
- a newer local toolchain resolves the lower pin unchanged, so the pin costs nothing locally
- lower every function-local constraint to the runtime floor before deploying, not after the build fails

| Language | Cold Start | Use When |
|----------|-----------|----------|
| Dart | Fastest | User-facing (compiled, native SDK) |
| Node.js + ESBuild | Fast | npm ecosystem needed |
| Python | Slowest | Data processing, ML |

**Bundle interpreted languages** to single file:

```bash
npx esbuild src/index.ts --bundle --platform=node --outfile=dist/index.js
```

**Keep deps minimal.** Every dep adds cold start time.

### Specifications

| Workload | CPU | Memory |
|----------|-----|--------|
| Text processing, CRUD | Low | 128MB |
| Image processing | High | 512MB+ |
| ML inference | High | 1GB+ |

---

## Handler Pattern

Init SDK + services **outside handler** (warm-start). Refresh dynamic API key each call — changes per execution.

### Dart

Open Runtimes constructs `RuntimeContext` in its generated server; the user function package cannot import that private type. Use `Future<Object?> main(Object rawContext)`. Reuse an existing verified bridge when one exists. Otherwise, one local ABI boundary may perform only the dynamic operations necessary to read the private request, write logs, and serialize the private response. Document each operation-specific lint exception; file-wide ignores, nominal interface casts, and application-data casts through `dynamic` are invalid.

Convert request values immediately to typed application data, return typed application results to that boundary, and keep SDK, authorization, validation, and error handling free of runtime dynamic dispatch. Verify the boundary against the actual [runtime context](https://github.com/open-runtimes/open-runtimes/blob/main/runtimes/dart/versions/latest/src/function_types.dart) and [server invocation](https://github.com/open-runtimes/open-runtimes/blob/main/runtimes/dart/versions/latest/src/server.dart) with real runtime HTTP requests: success, authorization rejection, missing/malformed input, upstream failure, response status/body/headers, and error/log secrecy. Matching mocks alone are insufficient.

### Python

```python
client = None
tables_db = None

def _ensure_init(context):
    global client, tables_db
    api_key = context.req.headers.get('x-appwrite-key', '')

    if client is not None:
        client.set_key(api_key)
        return

    client = Client()
    client.set_endpoint(os.environ['APPWRITE_FUNCTION_API_ENDPOINT'])
    client.set_project(os.environ['APPWRITE_FUNCTION_PROJECT_ID'])
    client.set_key(api_key)
    tables_db = TablesDB(client)

def main(context):
    _ensure_init(context)
    rows = tables_db.list_rows(
        database_id='db', table_id='items',
        queries=[Query.limit(10)], total=False)
    return context.res.json({'items': rows['rows']})
```

### TypeScript

```typescript
let client: Client | null = null;
let tablesDB: TablesDB | null = null;

function ensureInit(context: any) {
    const apiKey = context.req.headers['x-appwrite-key'] ?? '';

    if (client) {
        client.setKey(apiKey);
        return;
    }

    client = new Client()
        .setEndpoint(process.env.APPWRITE_FUNCTION_API_ENDPOINT!)
        .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID!)
        .setKey(apiKey);
    tablesDB = new TablesDB(client);
}

export default async ({ req, res }: any) => {
    ensureInit({ req });
    const rows = await tablesDB!.listRows({
        databaseId: 'db', tableId: 'items',
        queries: [Query.limit(10)], total: false});
    return res.json({ items: rows.rows });
};
```

---

## Request/Response API

Appwrite Function handlers expose the same concepts across Dart, Python, and
TypeScript:

| Concept | Dart | Python | TypeScript |
|---------|------|--------|------------|
| Raw body | `context.req.body` | `context.req.body` | `req.body` |
| JSON body | `context.req.bodyJson` | `context.req.body_json` | `req.bodyJson` |
| Headers | `context.req.headers` | `context.req.headers` | `req.headers` |
| Method | `context.req.method` | `context.req.method` | `req.method` |
| Path | `context.req.path` | `context.req.path` | `req.path` |
| Query | `context.req.query` | `context.req.query` | `req.query` |
| JSON response | `context.res.json(...)` | `context.res.json(...)` | `res.json(...)` |
| Text response | `context.res.text(...)` | `context.res.text(...)` | `res.text(...)` |
| Empty response | `context.res.empty()` | `context.res.empty()` | `res.empty()` |
| Redirect | `context.res.redirect(...)` | `context.res.redirect(...)` | `res.redirect(...)` |

Validate every body/query/header value before using it.

---

## Input Validation & Responses

> **Security:** All user input from `context.req.bodyJson` untrusted. Always validate types, sanitize strings, enforce length limits before processing.

```dart
Future<Object?> main(Object rawContext) async {
    final FunctionContext context = adaptFunctionContext(rawContext);
    if (context.req.method != 'POST') {
        return context.res.json({'error': 'Method not allowed'}, status: 405);
    }

    // ⚠️ UNTRUSTED INPUT — validate before use
    final Object? body = context.req.bodyJson;
    if (body is! Map<String, Object?>) {
        return context.res.json({'error': 'Invalid body'}, status: 400);
    }
    final email = _sanitizeString(body['email']);
    if (email == null || !_isValidEmail(email)) {
        return context.res.json({'error': 'Invalid email'}, status: 400);
    }

    final password = body['password'];
    if (password is! String || password.length < 8 || password.length > 128) {
        return context.res.json({'error': 'Invalid password'}, status: 400);
    }

    try {
        final user = await account.create(
            userId: ID.unique(), email: email, password: password);
        return context.res.json({'userId': user.$id});
    } on AppwriteException catch (e) {
        return context.res.json({'error': e.message}, status: e.code ?? 500);
    }
}

// Sanitization helpers
String? _sanitizeString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.length <= 1000 ? trimmed : null;
}

bool _isValidEmail(String email) {
    return email.length <= 254 && RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
}
```

---

## Security

### API Keys

Appwrite auto-generates short-lived API key per execution from function's **scopes** (Console → Settings → Scopes). Use `context.req.headers['x-appwrite-key']` — no manual key mgmt.

```
✅ rows.read only for a read function
✅ teams.read + teams.write + rows.read + rows.write for squad ops
❌ All scopes for every function
```

### Execute Permissions

```
['users']              — any authenticated user
['user:abc123']        — specific user only
['team:teamABC']       — team members
[]                     — server/event/schedule only
```

### Enforce Authorization Server-Side

```dart
Future<Object?> main(Object rawContext) async {
    final FunctionContext context = adaptFunctionContext(rawContext);
    final userId = context.req.headers['x-appwrite-user-id'];
    if (userId == null || userId.isEmpty) {
        return context.res.json({'error': 'Unauthorized'}, status: 401);
    }

    final row = await tablesDB.getRow(
        databaseId: 'db', tableId: 'orders', rowId: orderId);
    if (row.data['userId'] != userId) {
        return context.res.json({'error': 'Forbidden'}, status: 403);
    }
}
```

---

## Environment Variables

Use variables for configuration + secrets; never track values in source/manifests.

- scope precedence = project → function/site → Appwrite-injected
- secret value = unreadable from Console/API after creation
- secret status = one-way; secret → non-secret requires delete + recreate
- value change on an existing key = next execution (Cloud `1.9.5`, no redeploy); key add/remove = redeploy; runtime smoke required either way
- read-back = exact key/ID/count + secret metadata, never secret value
- deployment workflow = validate candidate → upsert metadata → deploy → smoke
- multi-resource bootstrap → [dependency-aware bounded waves](performance.md#dependency-aware-bootstrap)

CLI workflow → [appwrite-cli.md](appwrite-cli.md#function--site-variables).
Production sequencing → [production-migrations.md](production-migrations.md#function--variable-cutover).

```dart
final stripeKey = Platform.environment['STRIPE_SECRET_KEY']!;
```

### Built-In Variables & Headers

| Name | Source | Description |
|------|--------|-------------|
| `APPWRITE_FUNCTION_API_ENDPOINT` | Env var | API endpoint (auto-injected) |
| `APPWRITE_FUNCTION_PROJECT_ID` | Env var | Project ID (auto-injected) |
| `x-appwrite-key` | `req.headers` | Dynamic API key (scoped, short-lived) |
| `x-appwrite-user-id` | `req.headers` | Caller's user ID (empty for server calls) |
| `x-appwrite-user-jwt` | `req.headers` | Caller's JWT (client-SDK executions) |

Injected-JWT claim/validation contract → [authentication.md](authentication.md#function-injected-user-jwt).

---

## Related

- [functions-advanced.md](functions-advanced.md) — Caching, events, scheduling, CI/CD, anti-patterns
- [realtime.md](realtime.md) — Event-driven subscriptions
- [cost-optimization.md](cost-optimization.md) — Reducing execution costs
