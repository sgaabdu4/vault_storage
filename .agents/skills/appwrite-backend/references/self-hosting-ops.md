# Self-Hosting Operations

## Storage Adapters

Default local disk. External storage for multi-node.

| Adapter | Variable | Use When |
|---------|----------|----------|
| Local | `_APP_STORAGE_DEVICE=local` | Single server (default) |
| AWS S3 | `_APP_STORAGE_DEVICE=s3` | Multi-node, large files |
| DigitalOcean Spaces | `_APP_STORAGE_DEVICE=dospaces` | DO infrastructure |
| Backblaze B2 | `_APP_STORAGE_DEVICE=backblaze` | Cost-effective backup |
| Akamai (Linode) | `_APP_STORAGE_DEVICE=linode` | Akamai infrastructure |
| Wasabi | `_APP_STORAGE_DEVICE=wasabi` | S3-compatible, cheap storage |

Each adapter needs access key, secret, region, bucket env vars. Local = single node only.

---

## Function Runtimes

Enable only runtimes needed:

```bash
_APP_FUNCTIONS_RUNTIMES=dart-3.12,node-22.0,python-3.12
```

Use only runtimes available in your installed Appwrite image. Appwrite Cloud supports Dart `3.12` for Functions; self-hosted availability can lag Cloud.

### Resource Limits

| Variable | Effect |
|----------|--------|
| `_APP_COMPUTE_CPUS` | Max CPU cores per function |
| `_APP_COMPUTE_MEMORY` | Max memory in MB per function |
| `_APP_FUNCTIONS_TIMEOUT` | Max timeout in seconds (default: 900) |
| `_APP_COMPUTE_INACTIVE_THRESHOLD` | Idle container cleanup (default: 60s) |

### Function Domain SSL

Wildcard SSL certs for function domains:

**Manual:** `docker compose exec appwrite ssl --domain="<id>.functions.yourdomain.com"`

**Automated:** Configure DNS provider (Cloudflare, DigitalOcean) in docker-compose.yml for wildcard cert gen.

---

## Backups

### What to Back Up

| Component | Tool |
|-----------|------|
| Database (MariaDB) | mysqldump |
| Storage volumes | tar / Docker volume |
| `.env` file | `cp .env .env.backup.$(date +"%Y%m%d")` |

### Database Backup

```bash
# Backup
docker compose exec mariadb sh -c \
  'exec mysqldump --all-databases --add-drop-database \
   --single-transaction --routines --triggers \
   -uroot -p"$MYSQL_ROOT_PASSWORD"' > ./dump.sql

# Restore (fresh installation only)
docker compose exec -T mariadb sh -c \
  'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' < dump.sql
```

DBs >5 GB: use `mariabackup` for faster physical backups.

### Volume Backup

```bash
docker compose stop

docker run --rm \
  -v appwrite-uploads:/data \
  -v $(pwd)/backup:/backup \
  ubuntu tar czf "/backup/uploads.tar.gz" -C /data .

docker compose start
```

Key volumes: `appwrite-uploads`, `appwrite-functions`, `appwrite-builds`,
`appwrite-sites`, `appwrite-certificates`, `appwrite-config`,
`appwrite-cache`, `appwrite-redis`, and the selected database volume.

### Critical

`_APP_OPENSSL_KEY_V1` encrypts all sensitive data. Copy exact value when restoring or lose encrypted data forever.

3-2-1 rule: 3 copies, 2 media, 1 offsite. Test restores quarterly.

### Incident Recovery

1. Stop schema/data/deploy writers; preserve failed command + timestamps + target.
2. Capture read-only API inventory + database/volume snapshot before repair.
3. Restore the pre-incident backup into an isolated Appwrite/database clone first.
4. Verify schema + row counts + critical invariants without exposing row payloads.
5. Shared server → never restore the full live database over unrelated projects.
6. Recovery plan must include Appwrite metadata/registry + database + Storage + config + cache consistency; raw business tables alone are insufficient.
7. Apply the smallest complete recovery through the infrastructure owner; version-specific internal SQL/table names = forbidden runbook API.
8. Restart/clear affected cache/runtime components only after persistent state is coherent.
9. Prove Console/API inventory + exact critical reads; SQL counts alone = incomplete.
10. Keep backup + isolated clone + recovery receipt until every API read-back passes.

Official full-dump restore = fresh installation only. Surgical shared-instance
recovery requires an isolated rehearsal + exact infrastructure approval; never
improvise against the live metadata database.

Failure pattern:

- SQL rows present + API `table not found` → metadata/registry/cache mismatch,
  not missing business rows → restore coherent component state before retry.
- Partial desired-state manifest caused loss → remove that deployment path +
  install the schema guard before resuming feature delivery.

---

## Updates

### Upgrade Path

Upgrade through each minor version's latest patch: `1.5.1` → `1.5.11` → `1.6.2` → `1.7.4` → `1.8.1` → `1.9.5`. Pin version — never `latest`.

```bash
docker run -it --rm \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume "$(pwd)"/appwrite:/usr/src/code/appwrite:rw \
    --entrypoint="upgrade" \
    appwrite/appwrite:1.9.5
```

Appwrite `1.9.x` can use MongoDB or MariaDB. Test database-engine choice and migrations in non-prod before upgrading prod.

### Run Migration

```bash
cd appwrite/
docker compose exec appwrite migrate
```

Run migration for `1.9.0` → `1.9.5`; review generated compose before restoring custom Caddy/proxy edits.

**Before every upgrade:** back up, review changelog, test non-prod first.

---

## Maintenance

| Variable | Default | Effect |
|----------|---------|--------|
| `_APP_MAINTENANCE_INTERVAL` | 86400s | Cleanup cycle |
| `_APP_MAINTENANCE_RETENTION_CACHE` | 2592000s (30d) | Max cache age |
| `_APP_MAINTENANCE_RETENTION_EXECUTION` | 1209600s (14d) | Max execution log age |
| `_APP_MAINTENANCE_RETENTION_AUDIT` | 1209600s (14d) | Max audit log age |
| `_APP_MAINTENANCE_RETENTION_ABUSE` | 86400s (1d) | Max abuse log age |

Health API (admin key) monitors services. See [health.md](health.md).

---

## Related

- [self-hosting.md](self-hosting.md) — Install, security, scaling
- [health.md](health.md) — Health checks, monitoring
- [functions.md](functions.md) — Cold starts, function arch
- [production-migrations.md](production-migrations.md) — safe schema/data/function rollout

Official backup owner: <https://appwrite.io/docs/advanced/self-hosting/production/backups>
