# Permissions and Roles

## Overview

Use `Permission` + `Role` helpers. `write` grants `create + update + delete`.

---

## Default Deny + Inheritance

Server SDK/Console create without explicit permissions → empty resource ACL.
Client SDK create without explicit permissions → creator read/update/delete.
ACL-sensitive code → pass the complete permissions set explicitly.

Use row/file perms when access differs per resource.
If all resources share same rules, set perms on table/bucket and leave row/file perms empty.

Mutation semantics:

- omitted permissions on update/upsert = inherit/preserve current ACL
- explicit `permissions: []` = revoke all resource-level ACLs
- missing `$permissions` in a response = unknown, never equivalent to `[]`

---

## Actions

| Action | Meaning |
|--------|---------|
| `read` | View resource |
| `create` | Create resource |
| `update` | Modify resource |
| `delete` | Remove resource |
| `write` | `create + update + delete` |

---

## Common Patterns

```dart
permissions: [
    Permission.read(Role.any()),
    Permission.create(Role.users()),
    Permission.update(Role.user(userId)),
    Permission.delete(Role.team('team_123', 'admin')),
    Permission.read(Role.label('premium')),
]
```

```python
permissions = [
    Permission.read(Role.any()),
    Permission.create(Role.users()),
    Permission.update(Role.user(user_id)),
    Permission.delete(Role.team('team_123', 'admin')),
    Permission.read(Role.label('premium')),
]
```

```typescript
permissions: [
    Permission.read(Role.any()),
    Permission.create(Role.users()),
    Permission.update(Role.user(userId)),
    Permission.delete(Role.team('team_123', 'admin')),
    Permission.read(Role.label('premium')),
]
```

---

## Resource-Level Examples

Set row/file-level permissions only when ACL differs per resource.

```typescript
await tablesDB.createRow({
    databaseId: 'db',
    tableId: 'posts',
    rowId: ID.unique(),
    data: {title: 'Hello'},
    permissions: [
        Permission.read(Role.user(userId)),
        Permission.update(Role.user(userId)),
        Permission.read(Role.team(teamId)),
    ],
});

await storage.createFile({
    bucketId: 'docs',
    fileId: ID.unique(),
    file,
    permissions: [
        Permission.read(Role.any()),
        Permission.update(Role.user(userId)),
        Permission.delete(Role.user(userId)),
    ],
});
```

If every row/file shares the same rules, set table/bucket permissions and leave
row/file permissions empty.

---

## Common Mistakes

- Forgetting perms. Resource becomes inaccessible to all users, including creator.
- `Role.any()` with `write`/`update`/`delete`. Guests can mutate or delete.
- `Permission.read(Role.any())` on sensitive rows/files. Data becomes public.
- Repeating row/file perms everywhere when table/bucket perms already fit. Harder ACL maintenance.

---

## Storage Note

File-level perms need `fileSecurity: true` on bucket. Otherwise bucket perms apply to all files.

TablesDB transactions do not include Storage. Row + file ACL change → row
transaction + file compensation/rollback + exact post-commit read-back.

---

## ACL Verification

1. Compute expected ACL from the canonical authorization policy.
2. Write the complete replacement ACL; grant-only updates leave stale access.
3. Read the exact row/file after acknowledgement.
4. Compare normalized sets; missing field, duplicate, extra grant, or stale grant = FAIL.
5. Exercise both grant + final revocation with disposable resources.

`listRows`/bulk output is inventory, not ACL proof. Some self-hosted response
shapes omit `$permissions`; fetch each decision-bearing resource with `getRow`
or `getFile`. Appwrite row writes also do not invalidate cached list responses,
so use `ttl: 0`, exact GET, or explicit table-cache purge for post-write proof.

Migration verification → [production-migrations.md](production-migrations.md).

---

## Related

- [storage-files.md](storage-files.md)
- [teams.md](teams.md)
- [authentication.md](authentication.md)
