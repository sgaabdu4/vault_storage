# Functions Advanced

## Error Handling & Idempotency

> **Security:** `context.req.bodyJson` + event payload untrusted. Validate+sanitize all fields before DB ops. See [functions.md](functions.md) sanitization patterns.

### Always Return Valid Responses

```dart
Future<Object?> main(Object rawContext) async {
    final FunctionContext context = adaptFunctionContext(rawContext);
    try {
        // ⚠️ Validate bodyJson before passing to processOrder
        final Object? body = context.req.bodyJson;
        if (body is! Map<String, Object?>) {
            return context.res.json({'error': 'Invalid payload'}, status: 400);
        }
        final result = await processOrder(body);
        return context.res.json({'success': true, 'data': result});
    } catch (e) {
        context.error('Function failed: $e');
        return context.res.json({'error': 'Internal error'}, status: 500);
    }
}
```

### Design for Idempotency

- Duplicate or concurrent delivery = same durable operation key; validate its producer and payload. Enforce key uniqueness in the completion table. A pre-read alone cannot prevent duplicate effects.
- TablesDB-only effects = stage every mutation and the unique completion record in the **same transaction**, carrying its `transactionId` through helpers; commit together. Use [transactions](transactions.md) for SDK calls, conflicts, rollback and failure causality. A separately committed marker before work loses retries; one after work permits duplicate effects.
- Conflict or uncertain commit = read the exact committed completion record and business postcondition; return already processed only when both agree. Otherwise rebuild from current state in a fresh transaction. Never treat every `409` as successful processing.
- External effects (email, payment, Storage, Auth) are outside that transaction. Use the existing [cross-service guidance](transactions.md#cross-service-side-effects): durable intent plus the downstream provider's idempotency key and reconciliation. Without downstream deduplication or observable reconciliation, do not claim exactly-once effects.
- Proof = concurrent duplicate deliveries apply one business effect; failure before commit leaves no effect or completion record; retry after an uncertain commit reconciles the original result. External-effect tests cover a crash after provider success but before local acknowledgement.

---

## Caching

Global vars persist across warm invocations.

```dart
Map<String, dynamic> _cache = {};
DateTime? _cacheTime;
const _cacheTTL = Duration(minutes: 5);

Future<Object?> main(Object rawContext) async {
    final FunctionContext context = adaptFunctionContext(rawContext);
    if (_cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTTL) {
        return context.res.json(_cache);
    }

    final rows = await tablesDB.listRows(
        databaseId: 'db', tableId: 'config',
        queries: [Query.limit(100)], total: false);

    _cache = {'config': rows.rows};
    _cacheTime = DateTime.now();
    return context.res.json(_cache);
}
```

**Cache:** config, lookup tables, rate-limit counters.
**Skip:** user-specific, frequently changing.

---

## Logging

`context.log()` info, `context.error()` errors. Disable in prod for perf; re-enable to debug.

Console → Functions → Settings → Logging

---

## Event Triggers

**Prefer over polling.** One trigger replace thousands of requests.

| Event | Use Case |
|-------|----------|
| `databases.*.tables.orders.rows.*.create` | Process new orders |
| `users.*.create` | Send welcome email |
| `storage.*.files.*.create` | Process uploads |
| `users.*.sessions.*.create` | Log new sign-ins |

```dart
Future<Object?> main(Object rawContext) async {
    final FunctionContext context = adaptFunctionContext(rawContext);
    final event = context.req.headers['x-appwrite-event'];
    final payload = context.req.bodyJson;

    if (event?.contains('rows') == true && event?.endsWith('.create') == true) {
        await sendOrderConfirmation(payload);
    }
    return context.res.json({'processed': true});
}
```

---

## Timeout Strategy

| Workload | Timeout |
|----------|---------|
| API response (CRUD) | 15s |
| Image processing | 30s |
| Report generation | 60s |
| Data migration | 300s |

These are workload budgets; synchronous executions have a 30-second hard limit. Long-running work uses async execution and stores any required result in an authorized durable resource:

```dart
final execution = await functions.createExecution(
    functionId: 'heavy-report', async: true,
    body: jsonEncode({'reportId': 'abc'}));

// Check execution status; the response body is not retained.
final status = await functions.getExecution(
    functionId: 'heavy-report', executionId: execution.$id);
```

### Execution Result Read

| Mode | Status and result source |
|------|------------------------|
| Sync (async flag false/omitted; Dart client `xasync`) | the `createExecution` response itself — `status` + `responseStatusCode` + `responseBody` |
| Async | Status only through realtime `functions.<FUNCTION>.executions` or bounded `getExecution`; read application results from the authorized durable resource |

- Appwrite does not store response bodies or headers; only synchronous calls return them. Switching a data-returning call to async + polling cannot recover its JSON response, even when execution status is `completed`. [Execution modes](https://appwrite.io/docs/products/functions/execute#execution-modes).
- Before changing execution mode, prove the caller receives its required result through the selected path. Test doubles must preserve the absent async body; a mocked completed execution containing response JSON is not valid integration proof.

- Sync execution + follow-up `getExecution` from a client (user session) context = `404`; the execution row is not readable by the session that created it. Symptom = a function that succeeded reported as failed by the poller. Cloud `1.9.5` proof.
- Polling a sync execution is forbidden; the create response is already terminal.
- Unavoidable status poll (resume after app restart) → treat `getExecution` `404` as terminal-unknown, reconcile source-of-truth state, never surface it as an execution error.

### SDK Response-Format Drift

Symptom = Appwrite records the Function execution or its durable effect, but `createExecution` throws while decoding the SDK `Execution` model. The execution may already have completed → reconcile the source-of-truth state before any retry.

1. Inspect the exact installed SDK tag → default `X-Appwrite-Response-Format` + required model fields + deployed Appwrite compatibility filter.
2. Proven mismatch → use public `Client.addHeader` at the shared client owner + choose a response format the deployed Appwrite target supports.
3. Add a client configuration regression + run one execution against the real deployed target → model parse + durable effect PASS.
4. Do not start with an SDK downgrade, private SDK imports, parser-error suppression, or raw HTTP. Official SDK release aligns its response header and model → remove the override.

Known version-bound case:

- Flutter `appwrite` `26.1.0` defaults to `1.9.6`; its `Execution.fromMap` requires `Execution.resourceType`.
- Appwrite removes `resourceType` for response formats before `2.0.0`.
- Version-bound workaround for that exact pair = public `Client.addHeader` with `X-Appwrite-Response-Format: 2.0.0`, after target support proof. Re-check every SDK or Appwrite upgrade.
- Primary proof = [Flutter client header](https://github.com/appwrite/sdk-for-flutter/blob/26.1.0/lib/src/client_io.dart) + [Flutter execution model](https://github.com/appwrite/sdk-for-flutter/blob/26.1.0/lib/src/models/execution.dart) + [Appwrite response compatibility change](https://github.com/appwrite/appwrite/pull/13209).

---

## Scheduled Executions

### One-Time / Delayed

```dart
await functions.createExecution(
    functionId: 'send-report',
    scheduledAt: DateTime.parse('2025-01-15T09:00:00Z').toIso8601String(),
);
```

### Cron (Recurring)

```dart
await functions.update(functionId: 'daily-cleanup', schedule: '0 0 * * *');
```

| Pattern | Description |
|---------|-------------|
| `0 * * * *` | Every hour |
| `0 0 * * *` | Daily at midnight |
| `0 0 * * 0` | Weekly on Sunday |
| `0 0 1 * *` | Monthly on 1st |

---

## Binary Payloads

```dart
final bytes = await File('image.png').readAsBytes();
await functions.createExecution(
    functionId: 'process-image', body: base64Encode(bytes),
    headers: {'content-type': 'application/octet-stream'});
```

---

## CI/CD Deployment

**Git (recommended):** Console → Functions → Settings → Connect Git Repository. Push branch → auto deploy.

**CLI:** staged rollout, variables, config fields, local run, and deployment
commands are owned by [appwrite-cli.md](appwrite-cli.md). Load it before any
deploy; do not reconstruct command shapes here.

Deployment ordering when a release also changes schema or data:
[production-migrations.md](production-migrations.md).

---

## Function Domains

Map custom domain: `https://api.example.com/path` → function execution.

Console → Functions → Settings → Domains.

---

## Anti-Patterns

| Wrong | Right | Why |
|-------|-------|-----|
| Init SDK inside handler | Init outside | Repeated setup |
| One function does everything | Domain grouping | Hard to scale/debug |
| Full admin API key | Minimal scope key | Blast radius |
| Trust client auth only | Validate in function | Easily bypassed |
| No error handling | Try-catch + structured errors | Silent failures |
| Log everything in prod | Disable, enable for debug | Performance |
| Process same event twice | Idempotency check | Duplicates |
| Long single function | Break into async tasks | Timeout risk |
| Poll for changes | Event triggers / Realtime | Wasted executions |
| Poll `getExecution` after a sync execution | Read the `createExecution` response | Session cannot read the execution row → `404` on a success |
| Import unused deps | Minimal imports | Slower cold starts |

---

## Related

- [functions.md](functions.md) — Architecture, cold starts, handler pattern
- [realtime.md](realtime.md) — Event-driven subscriptions
- [error-handling.md](error-handling.md) — Retry patterns
- [cost-optimization.md](cost-optimization.md) — Reducing execution costs
