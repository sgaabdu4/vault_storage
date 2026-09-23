# Teams

## Overview

Teams enable multi-tenancy, collaboration, and role-based permissions.

---

## Create Team

```dart
// Dart
final team = await teams.create(
    teamId: ID.unique(),
    name: 'Acme Corp',
    roles: ['owner', 'admin', 'member'],  // Custom roles
);
```

```python
# Python
team = teams.create(
    team_id=ID.unique(),
    name='Acme Corp',
    roles=['owner', 'admin', 'member'],
)
```

```typescript
// TypeScript
const team = await teams.create({
    teamId: ID.unique(),
    name: 'Acme Corp',
    roles: ['owner', 'admin', 'member'],
});
```

---

## Invite Members

```dart
// Dart - Email invitation
await teams.createMembership(
    teamId: 'team_123',
    roles: ['member'],
    email: 'new@example.com',
    url: 'https://your-app.example.com/accept-invite',  // Your app's invite handler
);
```

```python
# Python
teams.create_membership(
    team_id='team_123',
    roles=['member'],
    email='new@example.com',
    url='https://your-app.example.com/accept-invite',  # Your app's invite handler
)
```

```typescript
// TypeScript
await teams.createMembership({
    teamId: 'team_123',
    roles: ['member'],
    email: 'new@example.com',
    url: 'https://your-app.example.com/accept-invite',  // Your app's invite handler
});
```

---

## Accept Invitation

```dart
// Dart - User accepts
await teams.updateMembershipStatus(
    teamId: 'team_123',
    membershipId: 'membership_123',
    userId: currentUser.$id,
    secret: 'invite_secret_from_url',  // From invitation link
);
```

---

## Update Member Roles

```dart
// Dart - Promote to admin
await teams.updateMembership(
    teamId: 'team_123',
    membershipId: 'membership_123',
    roles: ['admin'],
);
```

---

## Remove Member

```dart
await teams.deleteMembership(
    teamId: 'team_123',
    membershipId: 'membership_123',
);
```

---

## List Members

```dart
final members = await teams.listMemberships(
    teamId: 'team_123',
    queries: [Query.limit(25)],
);

for (final member in members.memberships) {
    print('${member.userName}: ${member.roles}');
}
```

---

## Team Preferences

Store team-wide settings (max 64KB).

```dart
// Dart
await teams.updatePrefs(
    teamId: 'team_123',
    prefs: {
        'plan': 'pro',
        'features': ['analytics', 'exports'],
    },
);

final prefs = await teams.getPrefs(teamId: 'team_123');
```

---

## Permissions with Teams

```dart
// Team members can read
Permission.read(Role.team('team_123'))

// Only admins can update
Permission.update(Role.team('team_123', 'admin'))

// Owners can delete
Permission.delete(Role.team('team_123', 'owner'))
```

---

## Multi-Tenancy Pattern

Each tenant gets a team. Data isolated by permissions.

```dart
// Create tenant team
final tenant = await teams.create(
    teamId: ID.unique(),
    name: 'Tenant: ${company.name}',
    roles: ['owner', 'admin', 'member'],
);

// Create tenant data with team permissions
await tablesDB.createRow(
    databaseId: 'db',
    tableId: 'projects',
    rowId: ID.unique(),
    data: {'name': 'Project 1', 'tenantId': tenant.$id},
    permissions: [
        Permission.read(Role.team(tenant.$id)),
        Permission.write(Role.team(tenant.$id, 'admin')),
    ],
);

// Users can only see their tenant's data
```

---

## List User's Teams

```dart
final userTeams = await teams.list(
    queries: [Query.limit(25)],
);

for (final team in userTeams.teams) {
    print('${team.name}: ${team.total} members');
}
```

---

## Delete Team

```dart
await teams.delete(teamId: 'team_123');
// Removes all memberships
// Doesn't delete team-permissioned data
```

---

## Performance Tips

1. **Cache team membership** — Avoid repeated lookups
2. **Use labels for simple cases** — Teams overhead not always needed
3. **Limit custom roles** — Keep role list manageable

---

## Related

- Permissions for access control
- Labels for simpler user grouping
