import assert from 'node:assert/strict';
import { chmodSync, existsSync, mkdirSync, mkdtempSync, realpathSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { captureInventory, checkManifest, loadManifest, writeExclusiveJson } from './appwrite-schema-guard.mjs';

const endpoint = 'https://example.invalid/v1';
const projectId = 'project';
const now = Date.parse('2026-07-16T00:10:00.000Z');

function root(name = 'appwrite-schema-guard-') {
  return mkdtempSync(join(realpathSync(tmpdir()), name));
}

function column(overrides = {}) {
  return {
    key: 'status',
    type: 'string',
    required: false,
    array: false,
    size: 64,
    format: 'varchar',
    default: null,
    encrypt: false,
    ...overrides,
  };
}

function index(overrides = {}) {
  return {
    key: 'status_idx',
    type: 'key',
    attributes: ['status'],
    lengths: [],
    orders: ['ASC'],
    ...overrides,
  };
}

function manifest({
  databases = ['primary'],
  tables = [['primary', 'users']],
  columns = [],
  indexes = [],
  rowSecurity = false,
  permissions = [],
} = {}) {
  return {
    capturedAt: '2026-07-16T00:00:00.000Z',
    endpoint,
    projectId,
    tablesDB: databases.map(($id) => ({ $id, enabled: true })),
    tables: tables.map(([databaseId, $id]) => ({
      databaseId,
      $id,
      enabled: true,
      rowSecurity,
      $permissions: permissions,
      columns: structuredClone(columns),
      indexes: structuredClone(indexes),
    })),
  };
}

function changed(base, update) {
  const value = structuredClone(base);
  update(value);
  return value;
}

test('complete normalized manifest passes live and baseline inventory', () => {
  const candidate = manifest({
    tables: [
      ['primary', 'users'],
      ['primary', 'orders'],
    ],
    columns: [column()],
    indexes: [index()],
  });
  const prior = manifest({ columns: [column()], indexes: [index()] });
  assert.equal(checkManifest(candidate, prior, prior, now).result, 'PASS');
});

test("float declarations match Appwrite's raw double model", () => {
  const candidate = manifest({ columns: [column({ type: 'float', size: null, format: null })] });
  const live = manifest({ columns: [column({ type: 'double', size: null, format: null })] });
  assert.equal(checkManifest(candidate, live, undefined, now).result, 'PASS');
});

test('conflicting permission aliases fail with a stable validation error', () => {
  const candidate = manifest();
  /** @type {any} */ (candidate.tables[0]).permissions = 'not-an-array';
  assert.throws(() => checkManifest(candidate, manifest(), undefined, now), /permissions must be an array/);
});

test('index over array column fails before Appwrite mutation', () => {
  const candidate = manifest({
    columns: [column({ key: 'labels', array: true }), column()],
    indexes: [index({ key: 'labels_status', attributes: ['labels', 'status'] })],
  });
  assert.throws(
    () => checkManifest(candidate, manifest(), undefined, now),
    /index primary\/users\/labels_status uses array column: labels/,
  );
});

test('optional non-relationship column and index additions are safe', () => {
  const prior = manifest({ columns: [column()] });
  const candidate = manifest({
    columns: [column(), column({ key: 'note', size: 256 })],
    indexes: [index()],
  });
  assert.deepEqual(checkManifest(candidate, prior, undefined, now).additiveChanges, [
    'column:primary/users/note',
    'index:primary/users/status_idx',
  ]);
});

test('new table access and relationship state fail closed', () => {
  const prior = manifest();
  const publicTable = manifest({
    tables: [
      ['primary', 'users'],
      ['primary', 'public'],
    ],
  });
  publicTable.tables[1].$permissions = ['read("any")'];
  assert.throws(() => checkManifest(publicTable, prior, undefined, now), /permission\/access new table/);
  const relatedTable = manifest({
    tables: [
      ['primary', 'users'],
      ['primary', 'related'],
    ],
  });
  relatedTable.tables[1].columns = [
    column({
      key: 'owner',
      type: 'relationship',
      size: null,
      format: null,
      relatedTable: 'users',
      relationType: 'manyToOne',
    }),
  ];
  assert.throws(() => checkManifest(relatedTable, prior, undefined, now), /relationship on new table/);
});

/** @type {Array<[string, (value: any) => void, RegExp]>} */
const incompatibleCases = [
  [
    'column deletion',
    (value) => {
      value.tables[0].columns = [];
    },
    /destructive removal.*column/,
  ],
  [
    'column type',
    (value) => {
      value.tables[0].columns[0].type = 'integer';
    },
    /incompatible column change/,
  ],
  [
    'required constraint',
    (value) => {
      value.tables[0].columns[0].required = true;
    },
    /incompatible column change/,
  ],
  [
    'default constraint',
    (value) => {
      value.tables[0].columns[0].default = 'open';
    },
    /incompatible column change/,
  ],
  [
    'index deletion',
    (value) => {
      value.tables[0].indexes = [];
    },
    /destructive removal.*index/,
  ],
  [
    'index order',
    (value) => {
      value.tables[0].indexes[0].orders = ['DESC'];
    },
    /incompatible index change/,
  ],
  [
    'row security',
    (value) => {
      value.tables[0].rowSecurity = true;
    },
    /permission\/access row-security change/,
  ],
  [
    'permission broadening',
    (value) => {
      value.tables[0].$permissions = ['read("any")'];
    },
    /permission\/access table permission change/,
  ],
  [
    'permission narrowing',
    (value) => {
      value.tables[0].$permissions = [];
    },
    /permission\/access table permission change/,
  ],
];
for (const [name, mutate, expected] of incompatibleCases) {
  test(`${name} fails closed`, () => {
    const prior = manifest({
      columns: [column()],
      indexes: [index()],
      permissions: name === 'permission narrowing' ? ['read("any")'] : [],
    });
    assert.throws(() => checkManifest(changed(prior, mutate), prior, undefined, now), expected);
  });
}

test('relationship metadata change fails closed', () => {
  const relation = column({
    key: 'owner',
    type: 'relationship',
    size: null,
    format: null,
    relatedTable: 'owners',
    relationType: 'manyToOne',
    onDelete: 'restrict',
    side: 'child',
  });
  const prior = manifest({ columns: [relation] });
  const candidate = changed(prior, (value) => {
    value.tables[0].columns[0].onDelete = 'cascade';
  });
  assert.throws(() => checkManifest(candidate, prior, undefined, now), /relationship change/);
});

test('unknown material schema field fails closed', () => {
  const candidate = manifest();
  /** @type {any} */ (candidate.tables[0]).unknownSetting = true;
  assert.throws(() => checkManifest(candidate, manifest(), undefined, now), /unknown material field/);
});

test('unknown column and index types fail closed', () => {
  assert.throws(
    () => checkManifest(manifest({ columns: [column({ type: 'mystery' })] }), manifest(), undefined, now),
    /unknown material column type/,
  );
  assert.throws(
    () => checkManifest(manifest({ indexes: [index({ type: 'mystery' })] }), manifest(), undefined, now),
    /unknown material index type/,
  );
});

test('resource omissions and target mismatches fail closed', () => {
  assert.throws(() => checkManifest(manifest({ databases: [], tables: [] }), manifest(), undefined, now), /destructive removal.*database/);
  assert.throws(() => checkManifest(manifest({ tables: [] }), manifest(), undefined, now), /destructive removal.*table/);
  assert.throws(() => checkManifest(manifest(), { ...manifest(), projectId: 'wrong' }, undefined, now), /project mismatch/);
});

test('duplicate, orphan, and stale inventories fail closed', () => {
  assert.throws(
    () => checkManifest(manifest({ databases: ['primary', 'primary'], tables: [] }), manifest(), undefined, now),
    /duplicate database/,
  );
  assert.throws(
    () => checkManifest(manifest({ tables: [['missing', 'users']] }), manifest(), undefined, now),
    /references missing database/,
  );
  assert.throws(() => checkManifest(manifest(), { ...manifest(), capturedAt: '2026-07-15T23:00:00.000Z' }, undefined, now), /stale/);
});

test('includes are arrays inside a no-symlink project path', () => {
  const directory = root();
  mkdirSync(join(directory, 'appwrite'));
  writeFileSync(join(directory, 'appwrite', 'databases.json'), '[{"$id":"primary"}]');
  writeFileSync(join(directory, 'appwrite', 'tables.json'), '[{"$id":"users","databaseId":"primary"}]');
  writeFileSync(
    join(directory, 'appwrite.config.json'),
    JSON.stringify({
      endpoint,
      projectId,
      includes: {
        tablesDB: 'appwrite/databases.json',
        tables: 'appwrite/tables.json',
      },
    }),
  );
  assert.equal(loadManifest(join(directory, 'appwrite.config.json')).tables[0].$id, 'users');
});

test('include symlink escape fails closed', () => {
  const directory = root();
  const outside = join(root('appwrite-outside-'), 'tables.json');
  writeFileSync(outside, '[]');
  symlinkSync(outside, join(directory, 'tables.json'));
  writeFileSync(
    join(directory, 'appwrite.config.json'),
    JSON.stringify({
      endpoint,
      projectId,
      tablesDB: [],
      includes: { tables: 'tables.json' },
    }),
  );
  assert.throws(() => loadManifest(join(directory, 'appwrite.config.json')), /symlink/);
});

test('capture output is private, exclusive, and no-follow', () => {
  const directory = root();
  const output = join(directory, 'inventory.json');
  writeExclusiveJson(output, { result: 'PASS' });
  assert.throws(() => writeExclusiveJson(output, { result: 'changed' }), /EEXIST/);
  const target = join(directory, 'target.json');
  const link = join(directory, 'link.json');
  writeFileSync(target, 'unchanged');
  symlinkSync(target, link);
  assert.throws(() => writeExclusiveJson(link, { result: 'changed' }), /EEXIST|symlink/);
});

function fakeCli(directory, behavior) {
  const executable = join(directory, 'appwrite');
  writeFileSync(
    executable,
    `#!/usr/bin/env node
const args = process.argv.slice(2);
const joined = args.join(" ");
const emit = (value) => process.stdout.write("notice\\n" + JSON.stringify(value));
${behavior}
`,
  );
  chmodSync(executable, 0o700);
  return executable;
}

function assertCleanupCausality(action, primaryPattern, causePattern = primaryPattern) {
  const originalKill = process.kill;
  process.kill = () => {
    throw Object.assign(new Error('simulated process-group cleanup failure'), { code: 'EPERM' });
  };
  try {
    assert.throws(action, (error) => {
      assert.ok(error instanceof AggregateError);
      assert.match(error.message, primaryPattern);
      assert.match(error.message, /process-group cleanup failed: EPERM/);
      assert.equal(error.errors.length, 2);
      assert.match(error.errors[0].message, causePattern);
      assert.match(error.errors[0].stack, causePattern);
      assert.equal(error.errors[1].code, 'EPERM');
      assert.match(error.errors[1].stack, /simulated process-group cleanup failure/);
      assert.equal(error.cause, error.errors[0]);
      return true;
    });
  } finally {
    process.kill = originalKill;
  }
}

const completeFake = `
if (joined === "client --debug") process.stdout.write("endpoint     ${endpoint}\\n");
else if (joined === "--raw project get") emit({$id:"${projectId}"});
else if (joined.startsWith("--raw tables-db list --limit")) emit({total:1,databases:[{$id:"primary"}]});
else if (joined === "--raw tables-db get --database-id primary") emit({$id:"primary",enabled:true,type:"sql"});
else if (joined.startsWith("--raw tables-db list-tables")) emit({total:1,tables:[{$id:"users"}]});
else if (joined === "--raw tables-db get-table --database-id primary --table-id users") emit({
  $id:"users",databaseId:"primary",enabled:true,rowSecurity:false,$permissions:[],
  columns:[{key:"status",type:"string",status:"available",error:"",required:false,array:false,size:64,default:null,encrypt:false}],
  indexes:[{key:"status_idx",type:"key",status:"available",error:"",attributes:["status"],lengths:[],orders:["ASC"]}]
});
else process.exit(2);
`;

test('capture uses complete raw project, database, table, column, and index data', () => {
  const directory = root();
  const inventory = captureInventory(manifest(), fakeCli(directory, completeFake));
  assert.equal(inventory.schemaVersion, 2);
  assert.equal(inventory.tables[0].columns[0].key, 'status');
  assert.equal(inventory.tables[0].indexes[0].key, 'status_idx');
});

test('CLI deadline fails closed', () => {
  const directory = root();
  const executable = fakeCli(directory, 'setTimeout(() => {}, 1000);');
  assert.throws(() => captureInventory(manifest(), executable, { timeoutMs: 25 }), /timed out/);
});

test('CLI timeout preserves cleanup failure details', { skip: process.platform === 'win32' }, () => {
  const directory = root();
  const executable = fakeCli(directory, 'setTimeout(() => {}, 1000);');
  assertCleanupCausality(
    () => captureInventory(manifest(), executable, { timeoutMs: 25 }),
    /Appwrite CLI timed out: client --debug/,
    /ETIMEDOUT/,
  );
});

test('CLI command failure remains primary when cleanup also fails', { skip: process.platform === 'win32' }, () => {
  const directory = root();
  const executable = fakeCli(directory, 'process.exit(2);');
  assertCleanupCausality(() => captureInventory(manifest(), executable), /Appwrite CLI failed: client --debug exit=2/);
});

test('CLI timeout removes descendant processes', { skip: process.platform === 'win32' }, () => {
  const directory = root();
  const marker = join(directory, 'descendant-survived');
  const child = `setTimeout(() => require("node:fs").writeFileSync(${JSON.stringify(marker)}, "leaked"), 150)`;
  const behavior = `
const {spawn} = process.getBuiltinModule("node:child_process");
spawn(process.execPath, ["-e", ${JSON.stringify(child)}], {stdio:"ignore"}).unref();
setTimeout(() => {}, 1000);
`;
  const executable = fakeCli(directory, behavior);
  assert.throws(() => captureInventory(manifest(), executable, { timeoutMs: 25 }), /timed out/);
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 250);
  assert.equal(existsSync(marker), false);
});

test('non-progressing pagination fails closed', () => {
  const directory = root();
  const behavior = `
if (joined === "client --debug") process.stdout.write("endpoint     ${endpoint}\\n");
else if (joined === "--raw project get") emit({$id:"${projectId}"});
else if (joined.startsWith("--raw tables-db list --limit")) emit({
  total:200,databases:Array.from({length:100},(_,index)=>({$id:"db"+index}))
});
else process.exit(2);
`;
  assert.throws(() => captureInventory(manifest(), fakeCli(directory, behavior)), /did not progress/);
});

test('page and item ceilings fail closed', () => {
  const directory = root();
  const behavior = `
if (joined === "client --debug") process.stdout.write("endpoint     ${endpoint}\\n");
else if (joined === "--raw project get") emit({$id:"${projectId}"});
else if (joined.startsWith("--raw tables-db list --limit")) {
  const offset = Number(args.at(-1));
  emit({total:200,databases:Array.from({length:100},(_,index)=>({$id:"db"+(offset+index)}))});
} else process.exit(2);
`;
  const executable = fakeCli(directory, behavior);
  assert.throws(() => captureInventory(manifest(), executable, { maxPages: 1 }), /page ceiling/);
  assert.throws(() => captureInventory(manifest(), executable, { maxItems: 10 }), /item ceiling/);
});
