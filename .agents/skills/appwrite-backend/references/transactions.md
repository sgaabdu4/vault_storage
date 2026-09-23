# TablesDB Transactions

## Contract

- Transaction = staged TablesDB row operations + explicit commit/rollback.
- Atomic scope = supported row/bulk/operator operations across tables/databases.
- Excluded = schema + Auth + Storage + Functions + external providers.
- Read-own-writes = every dependent read/write carries the same `transactionId`.
- Client context = one authenticated client/transaction owner; independent helper client = stale-read risk.
- Operation cap = deployed server contract. Appwrite `1.9.0` self-hosted fallback = `100`; verify target source/config before transaction creation.
- Budget unit = staged operation/log, not HTTP request count or affected-row count.
- TTL unit = seconds. Appwrite `1.9.6` accepts `60..3600`; use `60` for one-row commit + `300` for multi-step commands.
- TTL below `60` is not fail-fast: transaction creation returns `400 general_argument_invalid` before any row operation runs.

## Sequence

1. Create transaction → retain exact `$id`.
2. Stage related operations with `transactionId`.
3. Read dependent rows with the same `transactionId`.
4. Validate invariant against staged state.
5. Commit explicitly; failure/decision change → roll back explicitly.
6. Exact post-commit read-back → side-effect reconciliation.

```typescript
const tx = await tablesDB.createTransaction({ttl: 300});

await tablesDB.updateRow({
  databaseId: 'main',
  tableId: 'accounts',
  rowId: sourceId,
  data: {credits: Operator.decrement(amount)},
  transactionId: tx.$id,
});

await tablesDB.updateRow({
  databaseId: 'ledger',
  tableId: 'accounts',
  rowId: targetId,
  data: {credits: Operator.increment(amount)},
  transactionId: tx.$id,
});

const staged = await tablesDB.getRow({
  databaseId: 'ledger',
  tableId: 'accounts',
  rowId: targetId,
  transactionId: tx.$id,
});

await tablesDB.updateTransaction({transactionId: tx.$id, commit: true});
```

SDK signature = installed target version. Generated SDK/source wins over copied syntax.

## Staged Reads

- Staged read = `listRows` carrying the same `transactionId`; the returned `rows` array performs read-own-writes and includes rows with staged operations.
- Measured on Cloud TablesDB: the same call with `total: true` returns a `total` that excludes every row carrying a staged uncommitted operation in that transaction, while `rows` still returns it.
- Reproduction = filtered query matching two rows returns `total=2` + `rows.length=2` → stage `updateRow` on one of them with the same `transactionId` → identical query returns `total=1` + `rows.length=2`.
- `total != rows.length` inside a transaction = expected staged-count skew, never a corruption signal.
- Forbidden = `total`-based completeness/uniqueness guard inside a transaction (`total != rows.length`, `total != 1`); staging a write on a queried member makes the guard throw permanently, observed as a hard `503` retry loop in a deployed Function.
- Completeness guard = `total: false` + `Query.limit(bound + 1)` → assert on `rows.length`.
- Singularity guard = `total: false` + `Query.limit(2)` → assert `rows.length != 1`.
- Undocumented upstream; transaction-scoped counting is a measured production observation, not a published contract.

```dart
final rows = await tablesDB.listRows(
  databaseId: db,
  tableId: table,
  queries: [...filters, Query.limit(65)],
  transactionId: transactionId,
  total: false,
);

if (rows.rows.length > 64) {
  throw StateError('Inventory is incomplete.');
}
```

## Conflicts + Retries

- Commit conflict = affected row changed outside transaction.
- Retry = re-read current source → rebuild every staged decision → new transaction.
- Replaying stale operations or reusing an expired transaction = forbidden.
- Keep transaction short; no provider/network work while holding staged decisions.
- Preflight = remove no-op/scoped work → count every staged operation → compare with bound target cap + headroom before transaction creation.
- One row call with `transactionId` = one operation.
- One bulk row call with `transactionId` = one operation; rows remain bounded by the separate bulk request cap.
- `createOperations` = number of top-level objects; each top-level bulk action = one operation.
- Chunked bulk staging budget = `ceil(targetRows / chunkSize) + otherStagedOperations`; calculate before transaction creation.
- Same patch/predicate across rows → use `updateRows`; same deletion predicate → use `deleteRows`. See [bulk-operations.md](bulk-operations.md).
- Over budget = split only at invariant-safe boundaries OR redesign ownership; partial transaction construction = forbidden.
- Multiple committed chunks are not globally atomic. Persist progress + block/reroute conflicting writes + reconcile to a fixed point.

## Cross-Service Side Effects

| Side effect | Owner |
|---|---|
| TablesDB rows | transaction |
| Storage file ACL/content | compensation + exact file read-back |
| Auth user/team | compensation + reconciliation |
| Function/provider/email | outbox/idempotency key + convergence worker |
| Schema | [production-migrations.md](production-migrations.md) expand/contract |

- Database commit + Storage mutation cannot be one Appwrite transaction.
- Safe order = stage rows → perform required pre-commit checks → commit → apply post-commit side effects → reconcile/compensate failures.
- Security revocation spanning rows/files = deny stale access on every surface; partial success must remain visible as failure until converged.

## Failure Causality

- Primary operation failure = canonical cause; capture its exception + stack trace before cleanup, compensation, or rollback.
- Cleanup/compensation/rollback failure = secondary cause; capture separately with execution ID + transaction ID + affected resource IDs.
- Forbidden = secondary failure replaces, rethrows over, or erases the primary failure.
- Outcome = operation remains failed until exact read-back proves the intended postcondition; log/report both causes as one incident chain.
- Error transport = native chained/aggregate error when supported; otherwise structured fields `primaryError` + `recoveryError` + their stack traces.
- Regression proof = injected primary failure + injected recovery failure exposes both causes and preserves the primary as the top-level operation failure.

## Proof

- Success test = all staged writes visible after commit.
- Failure test = injected late row failure leaves no committed row mutation.
- Staged-read test = helper observes prior staged change through same transaction.
- Staged-count test = stage a write on one member of a filtered set → same transaction-scoped query keeps `rows.length` while `total` drops → bounded `rows.length` guard stays green.
- Conflict test = concurrent change rejects commit + fresh rebuild succeeds.
- TTL test = `60` + `3600` pass; `59` + `3601` fail before any row operation.
- Budget test = exact-cap fixture passes; cap+1 fails before transaction creation; equivalent bulk staging fits when row/request cap also fits.
- Multi-chunk test = interrupted job resumes from durable checkpoint + exact final query proves old state count `0`.
- Cross-service test = Storage failure restores/finishes ACL state deterministically.
- Dual-failure test = primary mutation failure + rollback failure retains both stack traces and reports the primary cause first.

## Sources

- <https://appwrite.io/docs/products/databases/transactions>
- <https://appwrite.io/docs/products/databases/bulk-operations>
- <https://appwrite.io/docs/references/cloud/server-nodejs/tablesDB>
- Appwrite `1.9.6` constants: <https://github.com/appwrite/appwrite/blob/1.9.6/app/init/constants.php#L69-L71>
- Appwrite `1.9.6` TablesDB create validation: <https://github.com/appwrite/appwrite/blob/1.9.6/src/Appwrite/Platform/Modules/Databases/Http/TablesDB/Transactions/Create.php#L46>
- Appwrite `1.9.0` source: <https://github.com/appwrite/appwrite/blob/1.9.0/src/Appwrite/Platform/Modules/Databases/Http/Databases/Transactions/Operations/Create.php#L99-L104>
- Transaction-scoped `total` excluding staged rows = measured against Cloud `fra` TablesDB; absent from the transactions doc, which states only read-own-writes + uncommitted target table.
