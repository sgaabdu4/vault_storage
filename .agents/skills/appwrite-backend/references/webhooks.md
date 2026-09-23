# Webhooks

## Overview

Webhooks send HTTP requests to external URLs when events occur.

---

## Create Webhook

Console → Project Settings → Webhooks → Add Webhook

Or via API:

```dart
// Dart (Server SDK)
final webhook = await webhooks.create(
    webhookId: ID.unique(),
    name: 'Order Notifications',
    url: 'https://api.example.com/webhooks/appwrite',
    events: [
        'databases.*.tables.orders.rows.*',
        'users.*.create',
    ],
    security: true,  // Enable signature verification
);
```

---

## Event Patterns

| Pattern | Description |
|---------|-------------|
| `users.*` | All user events |
| `users.*.create` | User creation only |
| `databases.*` | All database events |
| `databases.main.tables.orders.rows.*.create` | New orders in specific table |
| `storage.*.files.*.create` | New file uploads |
| `functions.*.executions.*` | Function executions |

### Wildcard Rules

- `*` matches any single segment
- Cannot use `**` for multi-level matching
- Be specific to reduce noise

---

## Signature Verification

When `security: true`, requests include HMAC signature.

### Headers

| Header | Description |
|--------|-------------|
| `X-Appwrite-Webhook-Id` | Webhook ID |
| `X-Appwrite-Webhook-Events` | Triggering events |
| `X-Appwrite-Webhook-Name` | Webhook name |
| `X-Appwrite-Webhook-Timestamp` | Unix timestamp |
| `X-Appwrite-Webhook-Signature` | HMAC-SHA-256 signature |

### Verify Signature

```typescript
// TypeScript - Express handler
import crypto from 'crypto';

app.post('/webhooks/appwrite', (req, res) => {
    const signature = req.headers['x-appwrite-webhook-signature'];
    const timestamp = req.headers['x-appwrite-webhook-timestamp'];

    // Recreate signature
    const payload = `${timestamp}.${JSON.stringify(req.body)}`;
    const expected = crypto
        .createHmac('sha256', process.env.WEBHOOK_SECRET)
        .update(payload)
        .digest('hex');

    if (signature !== expected) {
        return res.status(401).send('Invalid signature');
    }

    // Process webhook
    const event = req.body;
    console.log('Event:', event.event);
    console.log('Payload:', event.payload);

    res.status(200).send('OK');
});
```

```python
# Python - Flask handler
import hmac
import hashlib
from flask import request

@app.route('/webhooks/appwrite', methods=['POST'])
def handle_webhook():
    signature = request.headers.get('X-Appwrite-Webhook-Signature')
    timestamp = request.headers.get('X-Appwrite-Webhook-Timestamp')

    payload = f"{timestamp}.{request.data.decode()}"
    expected = hmac.new(
        WEBHOOK_SECRET.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(signature, expected):
        return 'Invalid signature', 401

    event = request.json
    print(f"Event: {event['event']}")

    return 'OK', 200
```

---

## Webhook Payload

```json
{
  "$id": "event_123",
  "event": "databases.main.tables.orders.rows.order_456.create",
  "timestamp": "2025-01-15T10:30:00.000Z",
  "payload": {
    "$id": "order_456",
    "$tableId": "orders",
    "$databaseId": "main",
    "$createdAt": "2025-01-15T10:30:00.000Z",
    "$updatedAt": "2025-01-15T10:30:00.000Z",
    "customer": "John Doe",
    "total": 99.99
  }
}
```

---

## Custom Headers

Add custom headers to webhook requests.

```dart
await webhooks.create(
    webhookId: ID.unique(),
    name: 'External API',
    url: 'https://api.example.com/webhook',
    events: ['databases.*.tables.*.rows.*'],
    httpUser: 'api_user',        // Basic auth username
    httpPass: 'api_password',    // Basic auth password
);
```

---

## Update Webhook

```dart
await webhooks.update(
    webhookId: 'webhook_123',
    name: 'Updated Name',
    events: ['databases.*.tables.orders.rows.*'],
    url: 'https://new-url.example.com/webhook',
    security: true,
    enabled: true,
);
```

---

## Disable/Enable

```dart
// Pause webhook temporarily
await webhooks.update(
    webhookId: 'webhook_123',
    enabled: false,
);

// Re-enable
await webhooks.update(
    webhookId: 'webhook_123',
    enabled: true,
);
```

---

## Delete Webhook

```dart
await webhooks.delete(webhookId: 'webhook_123');
```

---

## Best Practices

1. **Always verify signatures** — Prevent spoofed requests
2. **Respond quickly** — Return 200 within 30 seconds
3. **Process async** — Queue heavy work, respond immediately
4. **Handle duplicates** — Webhooks may retry on failure
5. **Use specific events** — Avoid wildcard spam

---

## Retry Behavior

Appwrite retries failed webhooks:
- 3 retry attempts
- Exponential backoff
- Failed = non-2xx response

---

## Webhook Logs

View in Console → Project Settings → Webhooks → Select webhook → Logs

Shows:
- Request timestamp
- Response status
- Response time
- Payload sent

---

## CLI Management

Webhooks are a pushed resource type in `appwrite.config.json` — commands and
reconciliation semantics live in [appwrite-cli.md](appwrite-cli.md). A webhook
absent from the manifest is deleted on push.

Keep webhook secrets out of tracked config. Store them in the deployment
environment or secret manager.

---

## Related

- [realtime.md](realtime.md) — client-side updates
- [functions-advanced.md](functions-advanced.md) — server-side event processing
- [appwrite-cli.md](appwrite-cli.md) — manifest + push semantics
