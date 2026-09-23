# Health

Health checks self-hosted Appwrite.

---

## Overall Health

```dart
// Dart (Server SDK with admin privileges)
final health = await health.get();

print(health.status);  // 'pass' or 'fail'
```

---

## Service Checks

### Database

```dart
final dbHealth = await health.getDB();
print(dbHealth.status);  // 'pass'
print(dbHealth.ping);    // Response time in ms
```

### Cache (Redis)

```dart
final cacheHealth = await health.getCache();
print(cacheHealth.status);
print(cacheHealth.ping);
```

### Storage

```dart
final storageHealth = await health.getStorage();
print(storageHealth.status);
```

### Antivirus

```dart
final avHealth = await health.getAntivirus();
print(avHealth.status);  // 'pass' if ClamAV running
```

---

## Queue Monitoring

Check bg job queues.

```dart
// All queues
final queuesHealth = await health.getQueues();

for (final queue in queuesHealth.queues) {
    print('${queue.name}: ${queue.size} jobs');
}
```

### Specific Queues

```dart
final webhooks = await health.getQueueWebhooks();
final functions = await health.getQueueFunctions();
final builds = await health.getQueueBuilds();
final messaging = await health.getQueueMessaging();
final migrations = await health.getQueueMigrations();
```

---

## Certificate Check

Verify SSL cert valid.

```dart
final certHealth = await health.getCertificate(domain: 'cloud.appwrite.io');

print(certHealth.valid);        // true
print(certHealth.domain);       // cloud.appwrite.io
print(certHealth.signatureType); // RSA
print(certHealth.validFrom);    // ISO date
print(certHealth.validTo);      // ISO date
```

---

## Time Sync

Check server time accuracy.

```dart
final timeHealth = await health.getTime();

print(timeHealth.remoteTime);      // NTP server time
print(timeHealth.localTime);       // Server time
print(timeHealth.diff);            // Difference in ms
```

Time diff >30s break auth.

---

## Public Cloud Note

Health endpoints need admin API key. Cloud managed internally — endpoints self-hosted only.

---

## Monitoring Integration

Health check uses:

- **Uptime monitors:** Pingdom, UptimeRobot
- **Kubernetes probes:** Liveness/readiness
- **Alerting:** PagerDuty, Slack notifications
- **Dashboards:** Grafana, Datadog

### Example Endpoint

```typescript
// TypeScript - Express health endpoint
app.get('/health', async (req, res) => {
    try {
        const db = await health.getDB();
        const cache = await health.getCache();

        if (db.status === 'pass' && cache.status === 'pass') {
            res.status(200).json({ status: 'healthy' });
        } else {
            res.status(503).json({ status: 'degraded', db, cache });
        }
    } catch (e) {
        res.status(503).json({ status: 'unhealthy', error: e.message });
    }
});
```

---

## Scaled Deployments

Scaling topology, container types, and tuning variables are owned by
[self-hosting.md](self-hosting.md). Health-check consequences of scaling:

- Probe each container instance, not only the load-balancer VIP — a single
  healthy node masks failed replicas behind round-robin.
- Route load-balancer health checks at `/v1/health` so bad nodes drain
  automatically.
- Queue depth is cluster-wide; rising depth with healthy nodes = worker
  starvation, not a node failure.

---

## Related

- [self-hosting.md](self-hosting.md) — scaling, tuning, security
- [self-hosting-ops.md](self-hosting-ops.md) — backup, restore, upgrade
- [functions-advanced.md](functions-advanced.md) — scheduled health automation
- [webhooks.md](webhooks.md) — alerting
- [performance.md](performance.md) — Redis caching patterns
