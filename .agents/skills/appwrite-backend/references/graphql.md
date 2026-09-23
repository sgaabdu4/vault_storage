# GraphQL API

## Endpoint

```
POST /v1/graphql
```

Headers required:
- `X-Appwrite-Project: <project-id>`
- `X-Appwrite-Key: <api-key>` (server) or `X-Appwrite-JWT: <jwt>` (client)

---

## Introspection

Explore types + ops.

```graphql
query {
  __schema {
    types {
      name
      fields {
        name
        type { name }
      }
    }
  }
}
```

---

## Query Tables (TablesDB)

```graphql
# List rows with filters
query {
  tablesdbListRows(
    tableId: "products"
    queries: ["category.equal('electronics')", "price.lessThan(500)"]
  ) {
    total
    rows {
      id
      name
      price
    }
  }
}

# Get single row
query {
  tablesdbGetRow(
    tableId: "products"
    rowId: "product_123"
  ) {
    id
    name
    price
    inventory
  }
}
```

---

## Mutations (TablesDB)

```graphql
# Create row
mutation {
  tablesdbCreateRow(
    tableId: "products"
    data: {
      name: "Widget"
      price: 29.99
      category: "gadgets"
    }
  ) {
    id
  }
}

# Update row
mutation {
  tablesdbUpdateRow(
    tableId: "products"
    rowId: "product_123"
    data: { price: 24.99 }
  ) {
    id
    price
  }
}

# Delete row
mutation {
  tablesdbDeleteRow(
    tableId: "products"
    rowId: "product_123"
  ) {
    id
  }
}
```

---

## Batching

Combine ops in one request.

```graphql
query BatchedQueries {
  products: tablesdbListRows(tableId: "products", queries: ["limit(10)"]) {
    rows { id name }
  }

  categories: tablesdbListRows(tableId: "categories") {
    rows { id title }
  }

  stats: tablesdbListRows(tableId: "stats", queries: ["limit(1)"]) {
    rows { totalSales }
  }
}
```

---

## File Uploads via GraphQL

Use the official Storage SDK for uploads.

---

## Rate Limits

Appwrite API limits apply.

---

## SDK Usage

Use official SDK service clients. Do not hand-roll Appwrite HTTP calls in TypeScript, Dart, Flutter, Python, or shell.

---

## When to Use GraphQL

✅ **Allowed only with explicit approval:**
- SDK has no supported equivalent
- One-off admin/debug task, not app code

❌ **Use SDK instead:**
- File up/download
- Bulk ops
- Transactions
- Realtime subs
- TablesDB CRUD/queries
