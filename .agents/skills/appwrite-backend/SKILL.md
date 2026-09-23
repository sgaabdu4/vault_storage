---
name: appwrite-backend
description: Appwrite backend development and operations, including destructive account/data erasure and MCP server wiring for coding agents. Use for Appwrite SDK work; any Appwrite CLI command or failure must route through the CLI safety branch.
license: MIT
metadata:
  author: sgaabdu4
  version: "2.1.4"
  tags: appwrite, backend, baas, dart, python, typescript
---

# Appwrite Development

## Route

Load the owner before acting. Unlisted detail = read the owner, never infer.

| Trigger | Owner |
|---|---|
| Any Appwrite CLI/wrapper command, deployment, schema sync, function/site variable operation, or CLI failure — before installing, binding, probing, diagnosing, or mutating | [appwrite-cli](references/appwrite-cli.md) |
| Production schema/data/ACL/function cutover | [production-migrations](references/production-migrations.md) + CLI owner when CLI participates |
| TablesDB transaction or cross-service consistency | [transactions](references/transactions.md) + [permissions](references/permissions.md) |
| Permanent account/subject-data erasure across TablesDB, Auth, Storage, provider data, or retained audit evidence | [destructive-erasure](references/destructive-erasure.md) + [transactions](references/transactions.md) |
| Mass row create/update/upsert/delete, transaction-limit pressure, per-row write loop | [bulk-operations](references/bulk-operations.md) + [transactions](references/transactions.md) when atomic scope spans requests/tables |
| Filter by more IDs than the deployed `Query.equal()` value cap | [chunked-queries](references/chunked-queries.md) |
| Table/column/index design, encryption at rest, auto-increment, timestamp override, CSV import/export | [schema-management](references/schema-management.md) |
| Query shape, `select`, spatial, time helpers, missing-index suspicion | [query-optimization](references/query-optimization.md) |
| Counter, array, string, or date field mutated concurrently | [atomic-operators](references/atomic-operators.md) |
| Relationship modeling or traversal | [relationships](references/relationships.md) |
| List, feed, infinite scroll, or large-offset paging | [pagination-performance](references/pagination-performance.md) |
| Slow path, caching, delta sync, bootstrap ordering | [performance](references/performance.md) |
| Bandwidth, execution, or storage cost | [cost-optimization](references/cost-optimization.md) |
| Sessions, MFA, SSR auth, JWT, user labels, security settings | [authentication](references/authentication.md) |
| OAuth, magic link, email OTP, phone, anonymous, custom token | [auth-methods](references/auth-methods.md) |
| ACL design, lockout, public-leak suspicion | [permissions](references/permissions.md) |
| Team, membership, or multi-tenancy | [teams](references/teams.md) |
| Upload, download, preview, transform, bucket config | [storage-files](references/storage-files.md) |
| Function authoring, handler, runtime, cold start, env vars | [functions](references/functions.md) |
| Function events, schedules, idempotency, binary payloads, CI/CD | [functions-advanced](references/functions-advanced.md) |
| Function execution SDK model or response-format parsing failure, execution mode, response retrieval or execution timeout | [functions-advanced](references/functions-advanced.md) |
| Realtime subscription, channel, presence, event filtering | [realtime](references/realtime.md) |
| Push, email, or SMS delivery | [messaging](references/messaging.md) |
| Outbound event delivery to an external system | [webhooks](references/webhooks.md) |
| Avatar, initials, QR, flag, favicon | [avatars](references/avatars.md) |
| `429`, retry, typed error, timeout, code-zero transport failure, client request burst, partial-sync report | [error-handling](references/error-handling.md) + [performance](references/performance.md) |
| Platform ceiling or limit error | [limits](references/limits.md) |
| Country, currency, language, or geo lookup | [locale](references/locale.md) |
| GraphQL endpoint | [graphql](references/graphql.md) |
| Appwrite MCP server setup for a coding agent, or Appwrite documentation lookup | [mcp-servers](references/mcp-servers.md) |
| Self-hosted install, config, security, scaling, SDK version pins | [self-hosting](references/self-hosting.md) |
| Self-hosted backup, restore, upgrade, data-loss incident | [self-hosting-ops](references/self-hosting-ops.md) |
| Health check, queue depth, uptime monitoring | [health](references/health.md) |

## Invariants

1. **Official SDK only** — raw Appwrite HTTP (`fetch`, `requests`, `dio`, `package:http`, `curl`) is a violation unless the SDK lacks the endpoint or an isolated, tested `Client.call` works around SDK model parsing.
2. **Pin SDKs by target and call shape** — Cloud: latest stable official SDK. Self-hosted `1.9.x`: exact release-matched pins in [self-hosting](references/self-hosting.md). “Compatible with `1.9.x`” does not mean release-matched. Before changing a pin, audit every intervening breaking change and prove the repository's real SDK calls against the candidate; version resolution alone is insufficient. Repository-pinned binary/wrapper version always outranks a skill pin.
3. **TablesDB, not Collections** — Collections/Documents API deprecated 1.8.0.
4. **Allocate Appwrite IDs once with `ID.unique()`** — retryable create: call `ID.unique()` before the first attempt → persist the returned ID in the durable draft/intent → reuse that exact ID for every retry/reconciliation. A fresh `ID.unique()` on retry creates a second resource. Business/natural identity remains in indexed columns; never derive resource IDs from names, timestamps, slugs, hashes, or custom generators.
5. **Explicit ACL** — server SDK/Console create = empty resource ACL; client SDK create = creator read/update/delete. Pass explicit `Permission`/`Role` whenever ACL correctness matters.
6. **Bind limits to the deployed target** — page size, bulk rows/request, transaction operations, and `Query.equal()` value cap come from the deployed server source/config, never from memory.
7. **Choose execution mode by the required result** — response data → synchronous `createExecution` within its 30-second limit. Async background work → bounded status monitoring + source-of-truth reconciliation; execution polling/realtime cannot return the response body or headers. Long-running results need an authorized durable result read. Report destructive failure only after reconciliation proves the entity still exists. Consume synchronous responses directly; ambiguous status/`404` → reconcile before retrying. Use [functions-advanced](references/functions-advanced.md).
8. **Guard schema pushes** — `appwrite push tables` reconciles remote TablesDB against the complete local manifest; omission means deletion. Production push requires [appwrite-cli](references/appwrite-cli.md) inventory + manifest guard PASS. `push all`, `--all`, and `--force` never substitute for that gate.
9. **Stage production migrations** — additive expand → type-aware resumable backfill → compatible deployment → contract/read-back → consumer activation. Partial data/schema never activates downstream code. Use [production-migrations](references/production-migrations.md).
10. **Preserve write intent before optimizing** — update-only work never routes through `upsertRow`/`upsertRows`; a pre-read, existence check, or full payload does not remove create-on-missing semantics. Same patch across rows → `updateRows`; heterogeneous per-row updates → `createOperations` with `action: update` inside the verified transaction budget, or redesign. Transaction pressure never authorizes upsert. Use [bulk-operations](references/bulk-operations.md).
11. **Batch collection writes before coding** — target count can exceed one or is data-dependent → inventory the full mutation set + deployed limits before implementation. Compatible server bulk method exists → per-row write loop is forbidden. Bulk is unsupported → complete operation budget + atomic late-failure proof required. Full plan over cap → redesign or resumable fixed-point workflow; never split one atomic invariant across committed batches. Use [bulk-operations](references/bulk-operations.md) + [transactions](references/transactions.md).
12. **Preserve failure causality** — cleanup, compensation, or rollback failure never replaces the primary exception. Retain both errors + stack traces + execution/transaction IDs, report the operation failed, then reconcile the exact postcondition. Use [transactions](references/transactions.md).
13. **Coordinate client demand and uncertain outcomes** — one endpoint/project-scoped coordinator owns foreground, sync, auth, and retry traffic. Bound concurrency; share 429/transport cooldowns; classify code-zero network failures; retry reads within one deadline; reconcile writes/transactions before any repeat; report one incident per failed operation; and never advance a sync checkpoint after partial failure. Use [error-handling](references/error-handling.md).

## SDK Routing

| Runtime | Package |
|---|---|
| Web TypeScript/JavaScript/React | `appwrite` |
| Node.js/Deno/TypeScript SSR/Functions | `node-appwrite` |
| Flutter client | `appwrite` |
| Dart server/Functions | `dart_appwrite` |
| Python server/Functions | `appwrite` |

- Call style: TypeScript object parameters, Python keyword arguments, Dart named parameters. Positional only when matching existing code or on explicit request.
- Client SDKs use account sessions and user-scoped APIs. Server SDKs use API keys. SSR uses two clients: a reusable admin client for session creation, and a per-request session client via `setSession(...)` — never shared.
- Cloud project endpoint = `https://<REGION>.cloud.appwrite.io/v1`. The CLI account login endpoint stays `https://cloud.appwrite.io/v1`; do not rewrite it to a region.
- Initialize clients outside warm Function handlers where the runtime allows.

## Resources

Docs <https://appwrite.io/docs> · API <https://appwrite.io/docs/references> · SDKs <https://github.com/appwrite>
