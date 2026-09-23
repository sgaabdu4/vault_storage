# Production Migrations

## Contract

- Goal = one compatible live state across schema + rows + ACLs + Storage + Functions.
- Order = bind → preflight → expand → backfill → verify → deploy-compatible → contract → activate → final read-back.
- Each phase = idempotent owner + exact target + bounded deadline + machine-readable receipt.
- Any mutation failure → stop → inventory current state → resume from proof; blind retry = forbidden.
- CLI participates → load [appwrite-cli.md](appwrite-cli.md) before command construction or diagnosis.

## Sequence

| Phase | Required completion |
|---|---|
| Bind | Exact endpoint + project + server + SDK/CLI versions verified; secrets masked. |
| Preflight | Fresh schema inventory + backup/recovery proof + row counts + uniqueness + tenant + ACL invariants pass. |
| Expand | Add only backward-compatible tables/columns/indexes; poll each object to ready/available; additive guard only. |
| Backfill | Stable cursor/chunks + target-type check + exact no-op detection + deterministic accounting + bounded workers. |
| Verify | Zero failures + exact row/file ACL reads + semantic counts + no missing required data. |
| Deploy | Candidate variables validated → metadata read back → compatible/inert deployment ready → runtime smoke. |
| Contract | Required/delete/rename constraints only after every live writer/reader uses the expanded contract. |
| Activate | Function/worker/consumer release only after contract + smoke receipts PASS. |
| Final | Active deployment + schema + data + ACL + cleanup read-back bound to one revision/environment. |

## Expand + Contract

- Schema operations ∉ TablesDB transactions → expand/contract sequence owns compatibility.
- Old writer needs nullable/legacy field → keep it through expand + backfill + deployment.
- Required constraint or deletion before writer replacement → outage/data-loss risk → FAIL.
- Expand-time guard enforcing final required/deleted state before backfill → rollout deadlock → FAIL.
- Partial additive failure → preserve safe additions + resume forward; rollback-by-deletion requires separate destructive proof/approval.
- Column/index create/update = asynchronous on some targets → success response ≠ ready; poll status with one deadline.
- `429|502|503|504` on idempotent inspection → bounded exponential backoff + jitter; empty/malformed response = transport failure, not resource absence.
- JavaScript integer `min|max|default` outside `Number.isSafeInteger` → omit when optional or use an SDK/API representation proven exact; rounded 64-bit bounds = forbidden.

## Resumable Backfill

- Checkpoint = phase + stable cursor/chunk + source digest + counts + failures.
- Resume = re-read current row/data/ACL → exact match skips → mismatch reconciles → receipt updates.
- Optional/new field = omitted OR explicit `null`; skip only when live value has required target type + exact target value.
- Verification = `missing + explicit-null + wrong-type + wrong-value` counts; any nonzero count = FAIL.
- Idempotent ≠ resumable unless completed work is detected and skipped.
- Per-row CLI process = N+1 startup + timeout risk → official SDK/client pool + bounded chunks.
- Concurrency = independent resources only + deterministic result order + reduced on throttling/transient failure.
- Failure report = every selected row accounted once; silent skip/truncation/partial aggregate PASS = forbidden.
- Logs/reports = IDs pseudonymized + counts/status only; row/file payloads may contain PII.

## ACL Proof

- Missing `$permissions` in list/bulk output = `Unknown`, never `[]`.
- Exact ACL proof = `getRow`/`getFile` for every affected resource or deterministic bounded sample + aggregate owner.
- Post-write list cache = unsafe proof; Appwrite row writes do not invalidate cached lists. Use `ttl: 0`, exact GET, or explicit table-cache purge.
- Revocation = explicit empty ACL when intended; omitted permissions inherit/preserve current permissions.
- TablesDB row mutation + Storage file ACL mutation ≠ one atomic transaction → transaction for rows + compensation/rollback for files + post-commit exact file read-back.
- Disposable smoke = dedicated actors/resources + grant/revoke cases + aggregate cleanup errors + final absence/read denial proof.

## Transaction Boundary

- All staged reads/writes that must observe each other carry the same `transactionId` and client context.
- Helper/store with an independent TablesDB client can read pre-transaction state → forbidden inside one invariant.
- Commit conflict → re-read source state + rebuild operations; replaying stale decisions = forbidden.
- Schema + Auth + Storage + Functions stay outside TablesDB transaction → name compensation and reconciliation owners.

## Function + Variable Cutover

- Validate candidate secret/config values before writing; never depend on secret-value API read-back.
- Active variable read-back = exact key/ID/count + `secret` metadata; wrapper response may be `{total, variables}`.
- Secret status = one-way. Secret → non-secret requires delete + recreate; value replacement may update or recreate per target contract.
- Variable changes apply on next deployment → deployment + runtime smoke required.
- Capture prior active deployment before mutation; new deployment failure → prior remains/returns active.
- Function-only deployment against missing schema/backfill = forbidden; schema-only contract against old function = forbidden.
- Deployment ready + execution `completed` = transport proof only.
- Pre-activation smoke = real authenticated critical route + expected `responseStatusCode` + parsed application payload + empty execution errors + bounded duration.
- HTTP/synchronous success with `{ok:false}` or equivalent failure payload = FAIL; downstream activation waits for smoke PASS.

## Failure Route

| Evidence | Action |
|---|---|
| Failure before mutation | Fix command/contract owner → focused proof → restart phase. |
| Failure after partial mutation | Freeze writers → read current state → resume exact incomplete work. |
| CLI/parser/serialization mismatch | Read pinned command help + official source → regression fixture → SDK fallback only for unsupported shape. |
| SQL/backup rows exist but Appwrite API cannot see them | Treat metadata/cache/runtime as inconsistent → self-host incident route. |
| ACL list disagrees with exact GET | Exact GET wins for proof; repair verifier, not correct backend behavior. |
| Same root recurs | Stop retries → durable regression + owner correction. |

## Sources

- Transactions: <https://appwrite.io/docs/products/databases/transactions>
- Rows/cache: <https://appwrite.io/docs/products/databases/rows>
- Permissions: <https://appwrite.io/docs/advanced/security/permissions>
- Function variables: <https://appwrite.io/docs/advanced/security/environment-variables>
- Function execution model: <https://appwrite.io/docs/references/cloud/models/execution>
- Synchronous execution: <https://appwrite.io/docs/products/functions/execute>
- Tables CLI: <https://appwrite.io/docs/tooling/command-line/tables>
