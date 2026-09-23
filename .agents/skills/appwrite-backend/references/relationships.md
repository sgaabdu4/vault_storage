# Relationships

## Relationship Types

| Type | Description | Example |
|------|-------------|---------|
| `oneToOne` | Single reference | User → Profile |
| `oneToMany` | Parent has many children | Post → Comments |
| `manyToOne` | Child references parent | Comment → Post |
| `manyToMany` | Both have many | Post ↔ Tags |

---

## Opt-In Loading

**Relationships return IDs by default.** `Query.select()` to expand.

### IDs Only (Default)

```dart
final posts = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'posts',
);
// posts[0]['author'] = 'user_123' (just the ID)
```

### Expanded (With Select)

```dart
final posts = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'posts',
    queries: [
        Query.select(['title', 'author.name', 'author.avatar']),
    ],
);
// posts[0]['author'] = {'name': 'Alice', 'avatar': '...'} (full object)
```

---

## Why This Matters

Post w/ 100 comments, each w/ author. No select → IDs only → 100+ queries for names.

```dart
// ❌ N+1 PROBLEM - 101 queries
final posts = await tablesDB.listRows(...);
for (final post in posts) {
    final author = await tablesDB.getRow(
        tableId: 'users',
        rowId: post['author'],
    ); // Separate query for each!
}

// ✅ CORRECT - 1 query
final posts = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'posts',
    queries: [
        Query.select(['title', 'author.name', 'author.avatar']),
    ],
);
// Author data included inline
```

---

## Creating Relationships

### One-to-One

```dart
await tablesDB.createRelationship(
    databaseId: 'db',
    tableId: 'users',
    relatedTableId: 'profiles',
    type: 'oneToOne',
    twoWay: true,
    key: 'profile',
    twoWayKey: 'user',
    onDelete: 'cascade',
);
```

### One-to-Many

```dart
await tablesDB.createRelationship(
    databaseId: 'db',
    tableId: 'posts',
    relatedTableId: 'comments',
    type: 'oneToMany',
    twoWay: true,
    key: 'comments',
    twoWayKey: 'post',
    onDelete: 'cascade',
);
```

### Many-to-Many

```dart
await tablesDB.createRelationship(
    databaseId: 'db',
    tableId: 'posts',
    relatedTableId: 'tags',
    type: 'manyToMany',
    twoWay: true,
    key: 'tags',
    twoWayKey: 'posts',
);
```

---

## On Delete Behavior

| Setting | Description |
|---------|-------------|
| `restrict` | Block delete if related rows exist |
| `cascade` | Delete related rows |
| `setNull` | Set foreign key to null |

---

## Nested Select

Expand nested rels up to 3 levels.

```dart
final posts = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'posts',
    queries: [
        Query.select([
            'title',
            'author.name',
            'comments.text',
            'comments.author.name', // 3 levels deep
        ]),
    ],
);
```

**Limit:** Max 3 levels nesting.

---

## Filtering on Relationships

Query through rels.

```dart
// Posts by specific author name
final posts = await tablesDB.listRows(
    databaseId: 'db',
    tableId: 'posts',
    queries: [
        Query.equal('author.name', 'Alice'),
        Query.select(['title', 'author.name']),
    ],
);
```

---

## Assigning Relationships

### One-to-One / Many-to-One

```dart
// Assign author to post
await tablesDB.updateRow(
    databaseId: 'db',
    tableId: 'posts',
    rowId: postId,
    data: {
        'author': authorId, // Just the ID
    },
);
```

### Many-to-Many

```dart
// Assign tags to post
await tablesDB.updateRow(
    databaseId: 'db',
    tableId: 'posts',
    rowId: postId,
    data: {
        'tags': [tagId1, tagId2, tagId3], // Array of IDs
    },
);
```

---

## Performance Tips

1. **Always use Query.select()** — control what loads
2. **Limit nested depth** — load only levels needed
3. **Index foreign keys** — speeds rel queries
4. **Prefer cursor pagination** — when loading related rows

---

## Common Patterns

### Blog with Authors and Tags

```dart
// Create tables
await tablesDB.createTable(
    databaseId: 'blog',
    tableId: 'posts',
    name: 'Posts',
);

await tablesDB.createTable(
    databaseId: 'blog',
    tableId: 'users',
    name: 'Users',
);

await tablesDB.createTable(
    databaseId: 'blog',
    tableId: 'tags',
    name: 'Tags',
);

// Author relationship (many posts to one user)
await tablesDB.createRelationship(
    databaseId: 'blog',
    tableId: 'posts',
    relatedTableId: 'users',
    type: 'manyToOne',
    key: 'author',
    onDelete: 'setNull',
);

// Tags relationship (many to many)
await tablesDB.createRelationship(
    databaseId: 'blog',
    tableId: 'posts',
    relatedTableId: 'tags',
    type: 'manyToMany',
    twoWay: true,
    key: 'tags',
    twoWayKey: 'posts',
);

// Query with relationships
final posts = await tablesDB.listRows(
    databaseId: 'blog',
    tableId: 'posts',
    queries: [
        Query.select([
            'title',
            'content',
            'author.name',
            'author.avatar',
            'tags.name',
            'tags.color',
        ]),
        Query.orderDesc('$createdAt'),
        Query.limit(10),
    ],
);
```

---

## Related

- Query optimization for select patterns
- Schema management for creating tables
