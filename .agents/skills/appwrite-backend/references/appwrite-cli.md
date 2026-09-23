# Appwrite CLI

Load this reference before any Appwrite CLI/wrapper command, deployment, schema
sync, function-variable operation, or CLI troubleshooting. Do not probe first.

## Route

- Init/pull/push/deploy/generate or interactive operator task → pinned CLI/wrapper
- One bounded read whose exact tested CLI output is sufficient → pinned CLI/wrapper
- Durable automation, exact response fields, pagination/retry, or multiple service calls → installed official Server SDK
- CLI presentation omits/transforms a required field or cannot express the request → official Server SDK; raw HTTP forbidden
- Function code deployment → function-only command
- Schema/resource reconciliation → Safety Gate → scoped push
- Data/ACL migration → [production-migrations.md](production-migrations.md) → SDK-first bounded runner
- Production schema push → inventory + backup/recovery + approval
- Destructive intent → dedicated delete command + exact resource approval
- CLI/wrapper failure → version + help/source + sanitized response shape → owner diagnosis

Choose once from the required outcome. Do not alternate CLI/SDK variants after a
failure. Recheck the original violation, diagnose the failed owner, then use a
materially different mechanism only when evidence proves the first owner cannot
meet the contract. Reuse an installed compatible official SDK; adding a package
when the pinned CLI already provides the exact proven operation is YAGNI.

## Install + Maintain

```shell
npm view appwrite-cli version
npm install -g appwrite-cli@25.0.0
appwrite --version
appwrite completion install
```

Repository-pinned wrapper/version wins. Registry latest observed on 2026-07-31 =
CLI `25.0.0`; its official README declares server `1.9.x` compatibility. Appwrite
`1.9.6` release-match = CLI `23.0.0`; [self-hosting.md](self-hosting.md) owns that
matrix. Releases `23.0.0` and `25.0.0` both remove or change commands/output.
Never float automation via `appwrite update` or unpinned install. Adopt a newer
CLI only after exact-tag help/source audit + read-only target probe + command-shape
contract update.

## Binding

```shell
appwrite --version
appwrite login                         # interactive account
appwrite login --endpoint "https://<SELF_HOSTED>/v1"
appwrite login --switch                # change active saved account
appwrite client \
  --endpoint "$APPWRITE_ENDPOINT" \
  --project-id "$APPWRITE_PROJECT_ID" \
  --key "$APPWRITE_API_KEY"
appwrite client --debug
appwrite --json project get
```

`appwrite whoami` reporting `https://cloud.appwrite.io/v1` is the expected Cloud account login endpoint. Do not rewrite it to a region. Only project config and project-scoped calls use `https://<REGION>.cloud.appwrite.io/v1`.

Required:

- endpoint = intended environment
- returned `$id` = intended project
- key = masked; `--show-secrets` forbidden
- mismatch/unknown → stop
- global reset → `appwrite client --reset`

Before command construction:

- repository-pinned binary/wrapper + version = authority; generic skill pin never overrides it
- inspect exact pinned command help: `appwrite <service> <command> --help`
- repository wrapper help is allowed only when its dispatcher explicitly owns help; unknown flags can execute a default deployment path
- classify command as read-only, additive, reconcile, data mutation, or delete
- no troubleshooting/mutation until target + version + command shape are known

Secret safety:

- `set -x`, shell trace, process-list diagnostics, verbose credential commands = forbidden
- bind with short-lived least-scope key + protected environment; capture only masked debug output
- `--show-secrets` = forbidden in an observable shell; an operation that must consume its own short-lived secret may use it only inside one non-logging process that parses the whole response, never emits the value, and discards it after the bounded operation
- unexpected secret in output/process evidence → stop command → revoke/rotate → replace every consumer → resume from read-back

## API Keys

- API keys = server/CLI credentials controlled by scopes, not resource ACL permissions.
- normal runtime/deploy key = only scopes required by the exact commands; full-scope default forbidden.
- repo-scoped project commands = configured API key wins over any saved cookie/account session; missing key fails before the CLI. Account sessions remain only for explicit account work or key bootstrap/rotation.
- one key may serve multiple trusted server consumers when that is the simplest maintainable owner, but its scope union must come from every real consumer call. Probe each representative service before updating every exact local/CI/runtime secret owner.
- secret cutover = enumerate exact consumer variable + secret-store names first; updating a similarly named unused secret is not a cutover.
- key-management caller = `keys.read` + `keys.write`; `keys.write` can mint any scope → bootstrap/rotation boundary only.
- no trusted key-management caller → create the first key in the Appwrite Console; never weaken auth or invent a raw-REST bypass.
- `project create-key|get-key|list-keys|update-key|delete-key` = CLI `23.0.0`; later versions may add `--project-id` but the bound project still requires read-back.
- short-lived work ≤1 hour → prefer `project create-ephemeral-key --scopes ... --duration ...` when the consumer accepts it.

Metadata inventory:

```shell
appwrite --raw project list-keys --limit 100 --offset 0
appwrite --raw project get-key --key-id "<KEY_ID>"
```

Create/rotate:

1. Bind + prove endpoint/project + pinned help + intended least scopes.
2. Run `appwrite --raw --show-secrets project create-key --key-id ... --name ... --expire ... --scopes ...` only inside one bounded non-logging process; stdout/stderr never reach terminal, CI log, artifact, or command trace.
3. Parse the whole response → require exact key ID/name/scopes/expiry + secret → write the secret directly to the approved consumer secret owner → clear the buffer.
4. Probe the actual consumer with the candidate key → fixed claim forbidden before PASS.
5. Read key metadata back with `--raw` without `--show-secrets` → cut over → delete the old key only after explicit destructive approval → prove old key rejected + new key accepted.

Failure handling:

- `401` = endpoint/project/key mismatch or revoked/invalid secret; do not add scopes first.
- `403` + `missing scopes ([...])` = compare the exact reported scope with intended operations → update/recreate only the missing required scope → consumer probe.
- key exists/listed ≠ usable; metadata output never proves the actual consumer received the secret.
- observable `--show-secrets`, shell command substitution, temp plaintext files, clipboard/log echo, or secret in argv/env diagnostics = forbidden.

## Config

`appwrite.config.json` = complete desired-state manifest for every pushed type.

```json
{
  "projectId": "<PROJECT_ID>",
  "endpoint": "https://<REGION>.cloud.appwrite.io/v1",
  "includes": {
    "functions": "appwrite/functions.json",
    "sites": "appwrite/sites.json",
    "webhooks": "appwrite/webhooks.json",
    "tablesDB": "appwrite/databases.json",
    "tables": "appwrite/tables.json"
  },
  "settings": { "services": {}, "protocols": {}, "auth": {} }
}
```

Include value = one relative JSON file containing one array. Glob/array/URL,
missing file, parent path, or inline + included duplicate owner → invalid.
Included function/site `path` resolves relative to the include file directory.

Pushed resource types: `settings` · `tablesDB` · `tables` · `buckets` · `teams`
· `topics` · `functions` · `sites` · `webhooks`. Every type participates in
reconciliation; a manifest missing one type is not a safe push input.

Function/site config fields: `enabled` · `logging` · `runtime`/`framework` ·
`buildSpecification` · `runtimeSpecification` · `buildRuntime` ·
`deploymentRetention` · `scopes` (execution-key API scopes) · `events` ·
`schedule` · `timeout` · `entrypoint`/`startCommand` · `commands`/`installCommand`/`buildCommand`
· `outputDirectory` · `adapter` · `fallbackFile` · `ignore` (newline-separated,
additive to `.gitignore`) · `path`.

Table config fields include `rowSecurity` (per-row ACL enforcement),
`$permissions`, `columns`, `indexes`. Flipping `rowSecurity` changes effective
access for every existing row → treat as an ACL migration, not a schema tweak.

### Tracked Config Integrity

Pinned CLI commands can pull after a push + rewrite the full local manifest with
their serializer. Protected closure = `appwrite.config.json` + every tracked
JSON file named by `includes`.

Each independent CLI caller/job:

1. Check out the exact release revision → require the full tracked checkout clean.
2. Before its first CLI invocation, capture each protected file byte-for-byte
   from that committed revision into a caller-owned, create-only `0600` snapshot.
3. Fail before invoking the CLI when any working file differs from the committed
   bytes; dirty input is not an acceptable snapshot.
4. Run every CLI invocation for that caller.
5. On success or failure, restore every protected file byte-for-byte from the
   snapshot before any downstream step.
6. Verify the full tracked checkout equals the committed revision; checking only
   `appwrite.config.json` is insufficient.
7. Remove the caller-owned snapshot.

Fresh job/caller = fresh capture before its first CLI invocation + its own
restore/clean-check. One earlier job's snapshot or restore never covers a later
finalizer. Newline-only repair, parsed-JSON equivalence, formatting normalization,
and capture after the first CLI call = forbidden.

## Command Shapes

- CLI option shapes vary by version → command help + official source before automation.
- Array options = variadic arguments, not one JSON-encoded array.

```shell
appwrite tables-db update-row \
  --database-id "<DATABASE_ID>" \
  --table-id "<TABLE_ID>" \
  --row-id "<ROW_ID>" \
  --permissions 'read("user:<USER_ID>")' 'update("user:<USER_ID>")'
```

- Omitted `--permissions` = inherit/preserve; explicit empty ACL = revoke all resource ACLs.
- Pinned CLI cannot encode `[]` → official Server SDK `permissions: []`; omission/skipping = forbidden.
- `ID.unique()` = SDK helper. CLI sentinel handling differs → verify pinned help/source; unsupported sentinel → create through official SDK and use returned ID.
- Required nullable-column contraction may need explicit JSON `null`; boolean/string stand-ins = forbidden.

## Init

```shell
appwrite init project
appwrite init functions
appwrite init sites
appwrite init tables
appwrite init buckets
appwrite init teams
appwrite init topics
```

Init = local manifest write. Existing project → preserve full manifest → init →
review diff → Schema Safety Gate before any push.

## Destructive Semantics

Official CLI behavior:

- `push tables` → remote database absent from `tablesDB` = delete database
- database deletion → all contained tables/data deleted
- remote table absent from `tables` = delete table
- `--force` → auto-accepts the settings-diff confirmation only
- `--all` → select every available resource
- `push settings` omission semantics vary by CLI version. Inspect pinned source
  before a partial settings push. CLI `24.1.0` submits only defined settings,
  although its change preview renders omitted remote fields as blank.
- `push functions`/`push sites` with `--with-variables` → key absent from `.env` = deleted variable
- no supported dry-run flag exists in CLI 22.4.0

Therefore:

- `appwrite push all` = production forbidden
- production `appwrite push tables --all --force` = forbidden
- narrowed/feature-only/schema-only manifest = forbidden push input
- warning text/interactive prompt = last defense, not proof
- schema deletion via omission = forbidden; use exact delete API/CLI command after
  backup + recovery proof + explicit approval

## Schema Safety Gate

Run before every production `push tables`:

```shell
# Set this to the absolute directory containing the loaded SKILL.md.
APPWRITE_SKILL_DIR="/absolute/path/to/appwrite-backend"

node "$APPWRITE_SKILL_DIR/scripts/appwrite-schema-guard.mjs" capture \
  --config appwrite.config.json \
  --output /tmp/appwrite-live-inventory.json

node "$APPWRITE_SKILL_DIR/scripts/appwrite-schema-guard.mjs" check \
  --config appwrite.config.json \
  --inventory /tmp/appwrite-live-inventory.json \
  --baseline <BASELINE_APPWRITE_CONFIG>
```

Run these commands from the target project root. The loaded skill's path is the
authority: its directory can be canonical `skills/appwrite-backend`, Hard Eng
`.agents/skills/appwrite-backend`, or another installed layout. Do not infer a
different path from the consumer repository.

`capture` = read-only database/table inventory; names/data/secrets excluded.

PASS requires:

- endpoint + project binding verified
- inventory age ≤15 minutes
- complete includes resolved
- every include path component is non-symlink + capture output is new private `0600`
- raw full-model capture for every database + table, including complete columns + indexes
- deterministic normalization of missing/null fields + sorted identities/permissions
- no duplicate database/table identity
- every live/baseline database + table + column + index present locally
- unchanged enabled + row-security + permission + column constraint + relationship + index definitions
- optional non-relationship column additions + new indexes are the only automatic safe additions
- unknown material schema/access fields fail closed
- CLI calls have deadlines + pagination has progress, stable-total, page, and item ceilings
- recent backup/snapshot + tested recovery path recorded
- exact command + environment + revision approved

Any omitted/mismatched resource → FAIL; do not push.

Guard output proves binding/inventory/manifest completeness only. Backup,
recovery-test, command, environment, revision, and approval = separate operator
receipts; script PASS alone ≠ production gate PASS.

Backup evidence when server supports Appwrite Backups:

```shell
appwrite --json backups list-archives --limit 100 --offset 0
appwrite --json backups get-archive --archive-id "<ARCHIVE_ID>"
appwrite --json backups list-restorations --limit 100 --offset 0
appwrite --json backups get-restoration --restoration-id "<RESTORATION_ID>"
```

Archive existence ≠ recovery proof. Unsupported Backups API → verified
infrastructure/database snapshot + tested restore owner.

## Pull

```shell
appwrite pull settings
appwrite pull functions
appwrite pull sites
appwrite pull tables
appwrite pull buckets
appwrite pull teams
appwrite pull webhooks
appwrite pull topics
```

Pull may replace local manifest. Review diff + rerun Schema Safety Gate before
push. Pull is not a backup of row data.

## Scoped Push

```shell
appwrite push settings
appwrite push functions
appwrite push sites
appwrite push tables
appwrite push buckets
appwrite push teams
appwrite push webhooks
appwrite push topics
```

Rules:

- push one resource type only
- production tables → Schema Safety Gate PASS first
- `--force` only after the same gate; it answers the settings-diff confirm, never the activation prompt
- CI must run the gate before any non-interactive push
- failure after mutation → stop; inventory + recovery evidence; no blind retry

## List Query Flags

Prefer flags over raw `--queries` JSON on any list command. Flags are validated
by the CLI; hand-built query JSON is not.

```shell
appwrite --json tables-db list-rows \
  --database-id "<DATABASE_ID>" --table-id "<TABLE_ID>" \
  --where 'status=active' --where 'score>=10' \
  --sort-asc 'name' \
  --select '$id' --select 'name' \
  --limit 25 --cursor-after "<ROW_ID>"
```

- `--where` operators: `=` `!=` `>` `>=` `<` `<=`; values parse as string,
  number, boolean, `null`, or JSON array.
- `--sort-asc` · `--sort-desc` · `--limit` · `--offset` · `--cursor-after` ·
  `--cursor-before` apply to list commands; repeated `--select` applies to
  row/document list + get.
- Cursor flags over `--offset` for large tables; same O(1) vs O(n) rule as the SDK.
- Row list command = `appwrite tablesdb list-rows` (alias `tables-db`). `appwrite databases list-rows` does not exist in CLI `24.x`; `databases` is the legacy documents API.
- `--queries` remains for shapes flags cannot express; verify against pinned help. Each value = one non-array JSON object — a JSON array such as `'[{"method":"limit","values":[6]}]'` is rejected with `Invalid query: Invalid query method:`.
- Multiple queries = multiple space-separated values after one `--queries` flag, never an array: `--queries '{"method":"equal","attribute":"<ATTRIBUTE>","values":["<VALUE>"]}' '{"method":"limit","values":[2]}'`.
- `--queries` value = Appwrite query JSON, never the SDK string form. CLI `24.1.0`: `'equal("userId",["abc"])'` → `Invalid query: Syntax error`; working shape = `'{"method":"equal","attribute":"userId","values":["abc"]}'`.

## Local Run

```shell
appwrite run functions
appwrite run functions --with-variables   # fetch values from function settings
```

Local run reads live variable values → treat the shell as secret-bearing.

## Function + Site Deployments

Code-only intent → avoid schema/resource push.

```shell
appwrite functions create-deployment --function-id "<FUNCTION_ID>"
appwrite functions list-deployments --function-id "<FUNCTION_ID>"
appwrite functions get-deployment \
  --function-id "<FUNCTION_ID>" \
  --deployment-id "<DEPLOYMENT_ID>"
appwrite functions update-deployment \
  --function-id "<FUNCTION_ID>" \
  --deployment-id "<DEPLOYMENT_ID>"
appwrite sites list-deployments --site-id "<SITE_ID>"
appwrite sites update-site-deployment --site-id "<SITE_ID>" --deployment-id "<DEPLOYMENT_ID>"
appwrite sites update-deployment-status --site-id "<SITE_ID>" --deployment-id "<DEPLOYMENT_ID>"  # cancel build
```

Staged rollout — build without switching live traffic, activate as a separate
approved step:

```shell
appwrite push function --function-id "<FUNCTION_ID>" --activate false
appwrite push function --function-id "<FUNCTION_ID>" --activate true
```

`function|functions`, `site|sites`, `table|tables` = command aliases.

Any cutover requiring backfill, contract, or consumer ordering uses
`--activate false` first — see
[production-migrations.md](production-migrations.md).

Function config/variables change → review full functions manifest before
`push function`. Secrets = environment/secret manager; never tracked config.

### Function Settings Integrity

Appwrite function update fields are destructive defaults, not patch semantics.
A partial `functions update` is forbidden.

Protected fields = `execute` + `events` + `schedule` + `scopes` + provider fields + build/runtime specifications + deployment retention + name + runtime + timeout + enabled + logging + entrypoint + commands + installation ID.

Code-only deployment:

1. Read the raw full function model before any settings mutation.
2. Require every protected field; missing protected field = fail before push.
3. Keep the snapshot outside tracked config.
4. Push code without a separate settings update.
5. Require snapshot before the push + exact protected-field read-back after it.
6. Drift/build/activation failure → rollback restores the full settings snapshot
   before the prior deployment, then requires terminal read-back.

Intentional settings change or rollback → official Server SDK
`Functions.update` + pass every protected field explicitly. Never reconstruct a
snapshot from filtered CLI JSON, selected fields, or local defaults. A forced
push requires complete intended function settings in the manifest; otherwise
fail before push.

### Non-Interactive Push

`push function` is interactive. CLI `24.1.0` raises two independent prompts and
each needs its own flag:

- settings-diff confirm (`Are you sure you want to apply these changes?`) = `--force`
- activation confirm (`Do you want to activate the deployment after it is ready?`) = `--activate <true|false>`
- prompt reached under closed stdin → `Error [ERR_USE_AFTER_CLOSE]: readline was closed` in `PromptUI.onForceClose`, exit `1`, nothing deployed
- `--with-variables` adds a further prompt → forbidden in scripts; mutate variables through the explicit variable commands

```shell
appwrite push function --function-id "<FUNCTION_ID>" --force --activate true
```

`--force` writes the local `appwrite.config.json` function settings over the
live ones, including `execute` permissions and `scopes`. The printed
remote-vs-local diff is the only checkpoint against a silent widening (live
`label:patients` → local `any`) → read it in one interactive run before
scripting the forced push.

### Function + Site Variables

1. Validate candidate values locally from secret/config owners; no value logging.
2. List active variables; normalize array or `{total, variables}` response.
3. Upsert exact manifest keys + secret flags before deployment.
4. Secret → non-secret = delete + recreate; secret status is one-way. `update-variable --secret false` fails with `Secret variables cannot be marked as non-secret. Please re-create the variable if this is your intention.` → omit `--secret` on every update.
5. Read back exact key/ID/count + `secret` metadata; values are unrecoverable — `functions get-variable --show-secrets` emits no `value` field at all.
6. Value change on an existing key takes effect on the next execution (Cloud `1.9.5`, no redeploy); key add/remove = deploy before any consumer relies on it.
7. Runtime smoke proves value availability; metadata read-back alone does not.

Variables are never declared in `appwrite.config.json`. They live in a `.env`
inside the configured `path`, and sync only on explicit request:

```shell
appwrite push functions --function-id "<FUNCTION_ID>" --with-variables
appwrite push sites --site-id "<SITE_ID>" --with-variables
appwrite push functions --function-id "<FUNCTION_ID>"   # code only, saved vars untouched
```

`--with-variables` creates, replaces, and removes remote variables to match the
local `.env` exactly. A key absent from `.env` is deleted. Verify the `.env`
against the secret owner before every `--with-variables` push.

Commands:

```shell
appwrite --json functions list-variables --function-id "<FUNCTION_ID>"
appwrite functions create-variable --function-id "<FUNCTION_ID>" \
  --variable-id "<VARIABLE_ID>" --key "<KEY>" --value "<VALUE>"
appwrite functions update-variable --function-id "<FUNCTION_ID>" \
  --variable-id "<VARIABLE_ID>" --key "<KEY>" --value "<VALUE>"
appwrite functions delete-variable --function-id "<FUNCTION_ID>" --variable-id "<VARIABLE_ID>"
```

- `--variable-id` = required on create (`required option '--variable-id <variable-id>' not specified`)
- create persists an EMPTY value even when `--value` is supplied → every create is followed by `update-variable` carrying `--key` + `--value`; there is no create-only path to a populated variable
- variable IDs are project-global, not per-function → reuse fails with `Variable with the same ID already exists in this project`; prefix the ID per function (`RECONCILE_APPWRITE_DATABASE_ID`) while `--key` stays the runtime name (`APPWRITE_DATABASE_ID`)
- empty-value symptom = function returns its missing-configuration branch (`503`) in ~0.2 s on every execution while `list-variables` still shows the key → prove the fix by execution read-back, never by value read-back

## Project Settings

Singular `project` service = current-bound project; no `--project-id`.

```shell
appwrite project update-service --service-id functions --enabled true
appwrite project update-protocol --protocol-id rest --enabled true
appwrite project list-o-auth-2-providers
appwrite project update-o-auth-2-git-hub --enabled true
appwrite project list-policies
appwrite project create-mock-phone --phone "+1<TEST_NUMBER>" --otp "<CODE>"
appwrite project create-ephemeral-key
```

- Service/protocol toggles remove an entire API surface project-wide → treat as
  destructive; inventory consumers first.
- `push settings` reconciles these from the manifest; a partial `settings` block
  disables what it omits.
- Ephemeral keys are short-lived and preferred over long-lived keys for one-off
  bounded automation. Mock phones are non-production test fixtures only.

### Nullable policy compatibility

CLI `24.1.0` + self-hosted Appwrite `1.9.6` cannot disable the user limit
through the direct command:

- `project update-user-limit-policy --total null` → CLI integer parser rejects
  `null`
- `project update-user-limit-policy --total 0` → server rejects numeric `0`;
  its endpoint accepts `1..5000 | null`
- `push settings` maps local `0 | null` to API `null`

Safe correction:

1. Read version + direct-command help/source + current `user-limit` policy.
2. Use an isolated minimal config containing only
   `settings.auth.security.limit: null`.
3. Prove pinned push source skips undefined settings + maps this value to
   `null`.
4. Run scoped `appwrite --force push settings`.
5. Read back `project get-policy --policy-id user-limit`; disabled = `total: 0`.

CLI success text without exact policy read-back = unknown. Different CLI/server
pairing → reverify both serializers before mutation.

## Read-Only Inventory + Diagnosis

```shell
appwrite --json project get
appwrite --json tables-db list --limit 100 --offset 0
appwrite --json tables-db list-tables \
  --database-id "<DATABASE_ID>" --limit 100 --offset 0
appwrite --json tables-db get-table \
  --database-id "<DATABASE_ID>" --table-id "<TABLE_ID>"
appwrite --json tables-db list-indexes \
  --database-id "<DATABASE_ID>" --table-id "<TABLE_ID>"
appwrite --json tables-db list-rows \
  --database-id "<DATABASE_ID>" --table-id "<TABLE_ID>"
appwrite --json storage list-files --bucket-id "<BUCKET_ID>"
appwrite --json functions list-executions --function-id "<FUNCTION_ID>"
appwrite --raw users list --limit 100 --offset 0
```

- pagination = bounded `--limit` + `--offset` until complete
- global output flags precede the service command: `appwrite --json ...` or `appwrite --raw ...`
- short flags are case-sensitive: filtered JSON = `-j`; full redacted response = `-R`; `-J` is unsupported
- `--json`/`-j` = filtered presentation; CLI `23.0.0` + `25.0.0` source drops null/blank values and nested object/array fields → omitted field ≠ empty/missing server value
- `--json`/`--raw` stdout is not parseable as-is: human notices precede the payload (CLI `24.1.0`: `ℹ Warning: This CLI is using a legacy cookie session.`), so `json.loads(stdout)` fails. Slice from the first `{`, or capture to a file and parse that; a fixed line-count offset is forbidden.
- exact field evidence (`labels`, `$permissions`, preferences, status, nested arrays) = `--raw`/`-R` + whole-response parse + required-field presence assertion
- proven failure shape: `users list -j` can omit non-empty `labels`; user-label inventory therefore requires `users list -R`
- `--raw` remains secret-redacted unless `--show-secrets` is explicitly supplied; never combine them in an observable command
- `--verbose` = sanitized error triage only; credential-bearing invocation/output = forbidden
- row/file output may contain PII → bounded destination + redact before sharing
- missing `$permissions` in list/bulk rows = unknown; ACL proof → exact `get-row`/`get-file`
- row writes do not invalidate cached list responses; verification → `ttl: 0`, exact GET, or explicit table purge

### Function Execution Triage

First stop for any failing function — cheaper and more exact than redeploying.

```shell
appwrite --json functions list --limit 100
appwrite functions list-executions --function-id "<FUNCTION_ID>" \
  --limit 3 --sort-desc '$createdAt'
```

- `--function-id` = the function `$id`, frequently an opaque hex string unequal to the display name; `functions list` prints both
- output carries `status` + `responseStatusCode` + full `logs` + `errors` + `duration`
- sub-second `duration` + 5xx = early configuration-guard return, not failing work → inspect variables/scopes before reading the handler

## Diagnosis

1. Capture pinned binary/wrapper version + exact help without secrets.
2. Reproduce with smallest read-only or disposable command shape.
3. Separate wrapper dispatch, CLI serialization, server validation, transport, and application failure.
4. Inspect official CLI/SDK source for that exact tag; generic latest behavior = insufficient.
5. Recheck the original observable violation; a filtered `--json` omission never proves server state.
6. Add command-shape regression → use official SDK for an unsupported CLI shape.
7. Mutation may have started → inventory current state; never rerun from assumption.

Bounded transport route:

- `429|502|503|504` + idempotent operation → exponential backoff + jitter + one absolute deadline
- empty/non-JSON response = transport failure, never proof of missing resource
- unknown status after write → exact resource read-back before retry
- per-row CLI process in migration = N+1 failure mode → SDK/client pool + bounded chunks

## Explicit Deletes

```shell
appwrite tables-db delete-table \
  --database-id "<DATABASE_ID>" --table-id "<TABLE_ID>"
appwrite tables-db delete --database-id "<DATABASE_ID>"
```

Required before delete:

- exact endpoint/project/resource IDs
- dependency + data-retention review
- restorable backup/snapshot + recovery test
- explicit destructive approval
- post-delete inventory verification

## Generate

```shell
appwrite generate
appwrite generate --output ./src/generated
appwrite generate --language typescript
appwrite generate --appwrite-import-source node-appwrite --import-extension .js
```

Emits `types.ts` + `databases.ts` + `constants.ts` + `index.ts`. Regenerate after
every accepted schema change/pull; stale generated types compile against a schema
that no longer exists.

Generated client collapses IDs and query builders into typed calls:

```typescript
import { databases } from './generated/appwrite';

const customers = databases.use('main').use('customers');
const page = await customers.list({
    queries: (q) => [q.equal('status', 'active'), q.orderDesc('$createdAt'), q.limit(25)],
});
await customers.createMany([{ name: 'A' }, { name: 'B' }]);
```

`createMany` is the generated bulk path and carries the same atomic-per-request
contract as `createRows` — see [bulk-operations.md](bulk-operations.md).

## Sources

- Commands: <https://appwrite.io/docs/tooling/command-line/commands>
- Installation/config includes: <https://appwrite.io/docs/tooling/command-line/installation>
- Tables CLI: <https://appwrite.io/docs/tooling/command-line/tables>
- Non-interactive flags: <https://appwrite.io/docs/tooling/command-line/non-interactive>
- API-key scopes + rotation: <https://appwrite.io/docs/advanced/platform/api-keys>
- Appwrite 1.9.6 release-compatible CLI matrix:
  <https://github.com/appwrite/website/blob/0c28c9a3f7a3b866c38d7762904981de45760c07/src/routes/docs/advanced/self-hosting/installation/%2Bpage.markdoc>
- CLI 23.0.0 + 25.0.0 filtered/raw output implementation:
  <https://github.com/appwrite/sdk-for-cli/blob/23.0.0/lib/parser.ts>
  <https://github.com/appwrite/sdk-for-cli/blob/25.0.0/lib/parser.ts>
- CLI 25.0.0 global output flags:
  <https://github.com/appwrite/sdk-for-cli/blob/25.0.0/cli.ts>
- CLI 23.0.0 + 25.0.0 project/API-key commands:
  <https://github.com/appwrite/sdk-for-cli/blob/23.0.0/lib/commands/services/project.ts>
  <https://github.com/appwrite/sdk-for-cli/blob/25.0.0/lib/commands/services/project.ts>
- CLI 25.0.0 server-line declaration + breaking release:
  <https://github.com/appwrite/sdk-for-cli/blob/25.0.0/README.md>
  <https://github.com/appwrite/sdk-for-cli/releases/tag/25.0.0>
- CLI 23.0.0 breaking release:
  <https://github.com/appwrite/sdk-for-cli/releases/tag/23.0.0>
- CLI source (`push.ts`, `database-sync.ts`, `change-approval.ts`):
  <https://github.com/appwrite/sdk-for-cli/tree/master/lib/commands>
- CLI 22.4.0 schema push/pull write-back:
  <https://github.com/appwrite/sdk-for-cli/blob/22.4.0/lib/commands/schema.ts>
- CLI 22.4.0 four-space config/include serialization:
  <https://github.com/appwrite/sdk-for-cli/blob/22.4.0/lib/config.ts>
- CLI 24.1.0 user-limit command parser:
  <https://github.com/appwrite/sdk-for-cli/blob/24.1.0/lib/commands/services/project.ts>
- CLI 24.1.0 nullable settings push:
  <https://github.com/appwrite/sdk-for-cli/blob/24.1.0/lib/commands/push.ts>
- Appwrite 1.9.6 user-limit endpoint:
  <https://github.com/appwrite/appwrite/blob/1.9.6/src/Appwrite/Platform/Modules/Project/Http/Project/Policies/UserLimit/Update.php>
- Exact pinned CLI tag/source = command-shape owner; reverify after version change.

## Related

- [schema-management.md](schema-management.md)
- [functions-advanced.md](functions-advanced.md)
- [self-hosting-ops.md](self-hosting-ops.md)
