# Cost Optimization

## Metered Resources

| Resource | Consumed by |
|----------|-------------|
| Bandwidth | every API request/response, including row reads and writes |
| Storage | bucket files + database storage |
| Executions | each function invocation |
| MAU | unique logged-in users per month |

Quotas and prices change per plan and per billing period — read the deployed
values from Console → Organization → Billing before any cost estimate; never
quote a remembered tier figure.

An "unlimited" count of databases/buckets/functions is a count, not unlimited
reads/writes; those still meter bandwidth. Overage bills as an add-on until the
budget cap.

---

## Cost Reduction Strategies

Every technique in the [performance.md](performance.md) quick reference also cuts
spend — less transferred data, fewer requests. Bill-specific levers on top of it:

| Lever | Bill effect |
|-------|-------------|
| Batch function operations | 1 execution instead of N (below) |
| Stable transformation URLs | Cache hits instead of recomputes (below) |
| Budget cap + alerts | Bounds overage (below) |

### Batch Function Operations

1 exec doing 10 ops beats 10 execs.

```python
# ❌ 10 function calls (10 executions)
for item in items:
    functions.create_execution(function_id='process', body=item)

# ✅ 1 function call (1 execution)
functions.create_execution(
    function_id='process-batch',
    body=json.dumps(items)
)
```

---

## Image Transformation Cache

Appwrite caches transformed images. Identical URLs = cache hit.

```dart
// First request: computed
// Second request: cached (minimal cost)
storage.getFilePreview(bucketId: 'img', fileId: 'id', width: 400, output: 'webp');
```

Consistent URLs maximize cache hits.

---

## Budget Protection

Console → Organization → Billing → Budget cap

At quota, a metered plan auto-buys overage until the cap; a non-metered plan
hard-stops instead — bandwidth denies API access, storage disables uploads,
executions disable functions. Confirm which behavior the deployed plan has
before relying on either. Set a cap to bound surprise charges.

### Budget Alerts

Console → Organization → Billing → Budget Alerts

Alerts warn before cap stops services. Set at 50%, 75%, 90% of cap to react before hard limits.

---

## Monitor Usage

Console → Organization → Usage

Track bandwidth, storage, executions, MAU vs limits.

---

## Related

- [performance.md](performance.md) — Optimization checklist
- [storage-files.md](storage-files.md) — Image formats
- [limits.md](limits.md) — Platform limits
