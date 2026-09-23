# Bulk Operations

## Contract

- Surface = server SDK only. Client bulk need → validated, rate-limited Appwrite Function.
- Methods = `createRows` + `updateRows` + `upsertRows` + `deleteRows`; use the exact installed SDK signature.
- Atomicity = one bulk request is all-or-nothing. One invalid row → no row in that request mutates.
- Scope = TablesDB rows without relationship columns.
- Side effects = every affected row emits its own Realtime + Function + Webhook events.
- Limits = deployed server contract. Appwrite `1.9.0` self-hosted fallback = `100` rows/request; verify target source/config before design.
- Transaction = every bulk method accepts `transactionId`.

## Admission

- Before implementation = inventory every row mutation + query scope + row/request cap + transaction operation count.
- Compatible server bulk method exists → use it; per-row write loop = forbidden.
- Row-loop fallback = bulk unsupported because relationship columns or required semantics cannot be represented → full operation budget + atomic late-failure proof.
- Full plan exceeds the transaction cap → redesign the invariant or use the durable [Multi-Request Workflow](#multi-request-workflow).
- Never split one atomic invariant across committed batches; multiple commits require explicit progress + conflict controls + fixed-point proof.

## Select

| Need | Method | Guard |
|---|---|---|
| Create rows with different values | `createRows(rows)` | Preallocate + persist every `$id` before retry |
| Apply one patch to matching rows | `updateRows(data, queries)` | Empty queries update every row |
| Create-or-update rows with different values | `upsertRows(rows)` | Missing `$id` may create; use only when create-on-missing is valid |
| Delete matching rows | `deleteRows(queries)` | Empty queries delete every row |
| Different patch per existing row + create forbidden | Transaction operations or redesign | `upsertRows` is not a safe update-only substitute |
| Table has relationship columns | Individual row operations | Bulk is unsupported |

Prefer one query-based `updateRows`/`deleteRows` call over list IDs → per-row loop when every target receives the same mutation. Index every query column.

## Individual Delete Fallback

- `deleteRows` → N `deleteRow` calls changes one atomic request into N operations.
- All-or-nothing caller contract → create one transaction before the first delete + pass its `transactionId` to every `deleteRow` + commit explicitly.
- Budget = one transaction operation per `deleteRow` + every other staged operation; preflight the complete plan before transaction creation.
- Over transaction cap → [Multi-Request Workflow](#multi-request-workflow); starting a non-atomic loop or silently accepting partial deletion = forbidden.
- Failure + rollback causality → [transactions.md](transactions.md); injected late delete failure must leave every target row unchanged.

## Update-Only Guard

- Domain/adapter `update` → Appwrite `update`; method translation preserves create-forbidden semantics.
- Forbidden = `update` mapped to `upsertRow`/`upsertRows` + pre-read/existence check/full payload.
- Upsert still creates when the row is absent; transaction state + delete/rollback/concurrency can otherwise resurrect a row or validate an incomplete payload as a create.
- Heterogeneous per-row data/ACL → `createOperations` entries with `action: update` + exact `rowId`; `$permissions` belongs in each operation `data` when ACL changes.
- Each top-level update entry consumes one transaction operation → preflight exact count against the deployed cap.
- Over cap → redesign or split only at an invariant-safe boundary; never weaken update into upsert.

```json
{
  "action": "update",
  "databaseId": "main",
  "tableId": "tasks",
  "rowId": "task-123",
  "data": {
    "status": "cancelled",
    "$permissions": ["read(\"user:owner\")"]
  }
}
```

## Destructive Query Guard

Build + validate the complete query set before calling `updateRows` or `deleteRows`.

```typescript
const queries = [Query.equal("assigneeId", [departingStaffId])];
if (queries.length === 0) throw new Error("Refuse unscoped bulk mutation");

await tablesDB.updateRows({
  databaseId,
  tableId: tasksTableId,
  data: { assigneeId: replacementStaffId },
  queries,
});
```

- Empty queries = all rows; require an explicit, separately authorized all-rows path.
- Query predicate = stable indexed identity, not display name.
- Update/delete response size ≠ proof that no additional rows matched; perform exact postcondition queries.

## Chunk

Resolve limits from the deployed Appwrite version/config before work:

```text
chunkSize = min(deployedBulkRowLimit, deployedQueryEqualValueLimit)
transactionOps = ceil(targetRows / chunkSize) + otherStagedOperations
```

For Appwrite `1.9.0` self-hosted fallbacks, both values are `100`, so the safe ID-scoped chunk is at most `100`. Do not copy a larger Cloud/custom limit into self-hosted code.

### Create + Upsert

1. Preallocate + persist every `$id`.
2. Sort by stable `$id`.
3. Slice the durable input into `chunkSize`.
4. Call `createRows`/`upsertRows` for one slice.
5. Exact read-back every slice ID.
6. Persist checkpoint only after read-back.
7. Retry the same slice + IDs after ambiguous failure.

### Update + Delete

Use a fixed-point loop instead of one unbounded predicate:

1. Block/reroute writes that can recreate the source predicate.
2. List the first `chunkSize` matching rows ordered by stable `$id`; select only `$id`.
3. Mutate with both `Query.equal('$id', chunkIds)` + the original source predicate.
4. Exact read-back proves no chunk ID still matches the source predicate.
5. Persist progress + repeat from the first page of remaining matches.
6. Complete only when a fresh exact query returns zero source matches.

Re-reading the first page avoids cursoring after a row that the previous chunk updated or deleted. The original predicate prevents a stale candidate list from overwriting a row concurrently moved to a different valid state.

```dart
while (true) {
  final candidates = await tablesDB.listRows(
    databaseId: databaseId,
    tableId: tasksTableId,
    queries: [
      Query.equal('assigneeId', departingStaffId),
      Query.orderAsc('\$id'),
      Query.limit(chunkSize),
      Query.select(['\$id']),
    ],
    total: false,
  );
  if (candidates.rows.isEmpty) break;

  final ids = candidates.rows.map((row) => row.$id).toList();
  await tablesDB.updateRows(
    databaseId: databaseId,
    tableId: tasksTableId,
    data: {'assigneeId': replacementStaffId},
    queries: [
      Query.equal('\$id', ids),
      Query.equal('assigneeId', departingStaffId),
    ],
  );

  // Exact ID-scoped read-back must prove zero old assignments before checkpoint.
}
```

## Transactions + Operation Budget

Bulk row count and transaction operation count are separate limits.

| Staging path | Transaction operations charged |
|---|---|
| One row call with `transactionId` | `1` |
| One bulk call with `transactionId` | `1` |
| `createOperations(operations)` | Number of top-level operation objects |
| One `bulkCreate`/`bulkUpdate`/`bulkUpsert`/`bulkDelete` object inside `createOperations` | `1` |

The rows inside a bulk operation still must fit the separate bulk row/request limit. Bind this behavior to the deployed Appwrite version before relying on it; Appwrite `1.9.0` source increments the transaction counter once for a bulk call.

Count every chunk before creating the transaction. If `ceil(targetRows / chunkSize) + otherStagedOperations` exceeds the target transaction cap, do not partially stage it; redesign the invariant or run the durable multi-request workflow below.

```dart
final tx = await tablesDB.createTransaction();

await tablesDB.updateRows(
  databaseId: databaseId,
  tableId: tasksTableId,
  data: {'assigneeId': replacementStaffId},
  queries: [Query.equal('assigneeId', departingStaffId)],
  transactionId: tx.$id,
);

await tablesDB.updateRows(
  databaseId: databaseId,
  tableId: recurringTasksTableId,
  data: {'assigneeId': replacementStaffId},
  queries: [Query.equal('assigneeId', departingStaffId)],
  transactionId: tx.$id,
);

await tablesDB.updateTransaction(transactionId: tx.$id, commit: true);
```

This stages two transaction operations, not one operation per matched row.

## Multi-Request Workflow

One bulk request = atomic. Multiple bulk requests/chunks = not one atomic unit unless all are staged in one transaction that fits both transaction + bulk limits.

When the full change cannot fit:

1. Persist one stable operation/job ID + source + target + policy + status.
2. Block or reroute new writes that can recreate the old state.
3. Process deterministic, idempotent chunks from [Chunk](#chunk); checkpoint only after exact read-back.
4. Retry the same partition with the same IDs/predicate.
5. Reach fixed point: exact source-owner count `0` across every owned table.
6. Apply cross-service side effects only through [transactions.md](transactions.md) reconciliation.
7. Mark complete only after final source-of-truth read-back.

Do not keep row-loop + bulk implementations as parallel owners. Migrate callers + tests to the bulk owner, then delete the legacy path in the same change.

## Failure Handling

- Request failure = treat the request as not committed until exact read-back proves otherwise.
- Retriable create/upsert = reuse persisted `$id` values; never regenerate IDs on retry.
- Transaction conflict = discard staged assumptions → refetch → rebuild → new transaction.
- Event consumers = idempotent by row event + operation/job ID; bulk can produce an event storm.
- Cross-service Auth/Storage/Functions work = outside TablesDB atomicity; reconcile visibly.

## Proof

- Atomic failure = one invalid row leaves every row in that request unchanged.
- Budget = individual staging exceeds cap; equivalent bulk staging stays within transaction + row/request caps.
- Scope = empty-query path rejects before SDK call.
- Relationships = preflight routes away from bulk.
- Retry = repeated request converges without duplicate rows or regenerated IDs.
- Completion = exact query finds zero rows in the old state across every table.
- Events = duplicate delivery does not duplicate downstream effects.

## Primary Sources

- <https://appwrite.io/docs/products/databases/bulk-operations>
- <https://appwrite.io/docs/products/databases/transactions>
- <https://appwrite.io/docs/references/cloud/server-nodejs/tablesDB>
- Appwrite `1.9.0` source: [self-hosted fallback limits](https://github.com/appwrite/appwrite/blob/1.9.0/app/init/constants.php#L41-L42)
- Appwrite `1.9.0` source: [bulk create stages one operation](https://github.com/appwrite/appwrite/blob/1.9.0/src/Appwrite/Platform/Modules/Databases/Http/Databases/Collections/Documents/Create.php#L400-L424)
- Appwrite `1.9.0` source: [`createOperations` charges top-level operation count](https://github.com/appwrite/appwrite/blob/1.9.0/src/Appwrite/Platform/Modules/Databases/Http/Databases/Transactions/Operations/Create.php#L99-L104)
