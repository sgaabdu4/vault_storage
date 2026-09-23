# Self-Hosting

Prod setup, scaling, security.

---

## System Requirements

| Resource | Minimum |
|----------|---------|
| CPU | 2 cores |
| RAM | 4 GB |
| Swap | 2 GB |
| Docker Compose | v2+ |

---

## Installation

### Quick Install

```bash
docker run -it --rm \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume "$(pwd)"/appwrite:/usr/src/code/appwrite:rw \
    --entrypoint="install" \
    appwrite/appwrite:1.9.6
```

### Manual Install

1. Grab [docker-compose.yml](https://appwrite.io/install/compose) + [.env](https://appwrite.io/install/env)
2. Put both in `appwrite/` dir
3. Run: `docker compose up -d --remove-orphans`

After `.env` change: `docker compose up -d` then `docker compose exec appwrite vars` to verify.

Appwrite `1.9.x` self-hosted supports MariaDB or MongoDB during setup. Pin image + SDK versions; never use `latest` tags in prod.

### Release-Matched Pins for Appwrite 1.9.6

| Target | Package | Version |
|--------|---------|---------|
| Dart Functions/server | `dart_appwrite` | `26.0.0` |
| Flutter client app | `appwrite` | `25.3.0` |
| Node.js Functions/server | `node-appwrite` | `27.0.0` |
| Browser/Web client | `appwrite` | `26.2.0` |
| Python Functions/server | `appwrite` | `22.1.0` |
| CLI | `appwrite-cli` | `23.0.0` |

- Table = release-matched versions; floating `latest` forbidden.
- Older SDK declaring `1.9.x` compatibility ≠ `1.9.6` release-match.
- Repository pin wins only after server line + real call shapes are proven.
- Pin change = every intervening changelog → service-call/result-access inventory → breaking signature/model migration → exact isolated dependency resolution → owned tests → read-only target probe.
- Python `16.0.0+` = typed Pydantic models, not dictionaries; requirements-only upgrade leaves `result["total"]` + `result["$id"]` callers broken.
- Raw HTTP to Appwrite APIs = violation.

Source: <https://github.com/appwrite/website/blob/0c28c9a3f7a3b866c38d7762904981de45760c07/src/routes/docs/advanced/self-hosting/installation/%2Bpage.markdoc>

---

## Production Security

### Encryption Key

Set `_APP_OPENSSL_KEY_V1` right after install — encrypts sensitive data. Change later = destroy existing encrypted data. Store in secrets manager.

### Force HTTPS

```bash
_APP_OPTIONS_ROUTER_FORCE_HTTPS=enabled
```

### Console Access

| Variable | Effect |
|----------|--------|
| `_APP_CONSOLE_WHITELIST_ROOT` | First user signs up; rest by invite |
| `_APP_CONSOLE_WHITELIST_EMAILS` | Comma-sep allowed emails |
| `_APP_CONSOLE_WHITELIST_IPS` | Comma-sep allowed IPs |

### Rate Limiting

```bash
_APP_OPTIONS_ABUSE=enabled   # production (default)
_APP_OPTIONS_ABUSE=disabled  # development only
```

Client SDK rate-limited. Server SDK w/ API keys bypass.

---

## Email Delivery (SMTP)

Auth emails need SMTP. Use 3rd-party (Mailgun, SendGrid, AWS SES) — self-hosted SMTP = spam folder risk.

```bash
_APP_SMTP_HOST=smtp.mailgun.org
_APP_SMTP_PORT=587
_APP_SMTP_SECURE=tls
_APP_SMTP_USERNAME=postmaster@yourdomain.com
_APP_SMTP_PASSWORD=your-smtp-password
_APP_SYSTEM_EMAIL_ADDRESS=noreply@yourdomain.com
_APP_SYSTEM_EMAIL_NAME=YourApp
```

---

## Error Monitoring

```bash
_APP_ENV=production
_APP_LOGGING_CONFIG=sentry://PUBLIC_KEY@HOST:PORT/PROJECT_ID
```

Others: Raygun, AppSignal, LogOwl.

---

## Scaling

### Container Types

| Container | Stateless? | How to Scale |
|-----------|-----------|--------------|
| API (appwrite) | Yes | Replicate + load balancer |
| Realtime/Function/Other workers | Yes | Replicate freely |
| MariaDB | No | Primary-replica |
| Redis | No | Sentinel or Cluster |
| Storage volumes | No | NFS or S3-compatible |

### Scale Stateless Containers

```bash
docker compose up --scale appwrite-worker-functions=4 -d
```

### Performance Tuning

```bash
_APP_WORKER_PER_CORE=6  # default; raise for I/O, drop for CPU
```

### Log Rotation

```yaml
x-logging: &x-logging
  logging:
    driver: 'json-file'
    options:
      max-file: '5'
      max-size: '10m'
```

### Redis Memory

```bash
maxmemory 256mb
maxmemory-policy allkeys-lru
```

---

## Related

- [self-hosting-ops.md](self-hosting-ops.md) — Backups, updates, maintenance, storage adapters, runtimes
- [health.md](health.md) — Health checks + monitoring
- [performance.md](performance.md) — Optimization checklist
