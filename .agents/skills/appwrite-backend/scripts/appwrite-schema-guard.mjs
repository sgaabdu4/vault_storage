#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { closeSync, constants, fsyncSync, lstatSync, openSync, readFileSync, realpathSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, parse, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const PAGE_SIZE = 100;
const MAX_INVENTORY_AGE_MS = 15 * 60 * 1000;
const MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;
const CLI_TIMEOUT_MS = 15_000;
const MAX_PAGES = 100;
const MAX_ITEMS = 10_000;
const MAX_OUTPUT_BYTES = 8 * 1024 * 1024;

const DATABASE_FIELDS = new Set(['$id', '$createdAt', '$updatedAt', 'name', 'enabled', 'type', 'policies', 'archives']);
const TABLE_FIELDS = new Set([
  '$id',
  '$createdAt',
  '$updatedAt',
  '$permissions',
  'permissions',
  'databaseId',
  'name',
  'enabled',
  'rowSecurity',
  'columns',
  'attributes',
  'indexes',
  'bytesMax',
  'bytesUsed',
]);
const COLUMN_FIELDS = new Set([
  '$id',
  '$createdAt',
  '$updatedAt',
  'key',
  'type',
  'status',
  'error',
  'required',
  'array',
  'size',
  'format',
  'default',
  'min',
  'max',
  'elements',
  'encrypt',
  'relatedTable',
  'relatedTableId',
  'relationType',
  'twoWay',
  'twoWayKey',
  'onDelete',
  'side',
]);
const INDEX_FIELDS = new Set([
  '$id',
  '$createdAt',
  '$updatedAt',
  'key',
  'type',
  'status',
  'error',
  'attributes',
  'columns',
  'lengths',
  'orders',
]);
const COLUMN_TYPES = new Set([
  'bigint',
  'boolean',
  'datetime',
  'double',
  'email',
  'enum',
  'integer',
  'ip',
  'line',
  'longtext',
  'mediumtext',
  'point',
  'polygon',
  'relationship',
  'string',
  'text',
  'url',
  'varchar',
]);
const INDEX_TYPES = new Set(['fulltext', 'key', 'primary', 'spatial', 'unique']);

function fail(message) {
  throw new Error(message);
}

function rejectSymlinkComponents(path, includeFinal = true) {
  const absolute = resolve(path);
  const root = parse(absolute).root;
  const parts = absolute.slice(root.length).split(sep).filter(Boolean);
  let current = root;
  const limit = includeFinal ? parts.length : Math.max(0, parts.length - 1);
  for (let index = 0; index < limit; index += 1) {
    current = resolve(current, parts[index]);
    if (lstatSync(current).isSymbolicLink()) fail(`path contains symlink: ${current}`);
  }
}

function readTextNoFollow(path) {
  rejectSymlinkComponents(path);
  const descriptor = openSync(path, constants.O_RDONLY | constants.O_NOFOLLOW);
  try {
    return readFileSync(descriptor, 'utf8');
  } finally {
    closeSync(descriptor);
  }
}

function readJson(path) {
  try {
    return JSON.parse(readTextNoFollow(path));
  } catch (error) {
    fail(`invalid JSON ${path}: ${error.message}`);
  }
}

function inside(root, child) {
  const path = relative(root, child);
  return path !== '' && !path.startsWith('..') && !isAbsolute(path);
}

export function loadManifest(path) {
  const configPath = resolve(path);
  rejectSymlinkComponents(configPath);
  const rootDir = dirname(configPath);
  const config = readJson(configPath);
  const includes = config.includes ?? {};
  if (!includes || Array.isArray(includes) || typeof includes !== 'object') {
    fail('config includes must be an object');
  }

  for (const key of ['tablesDB', 'tables']) {
    if (config[key] !== undefined && includes[key] !== undefined) {
      fail(`${key} cannot be inline and included`);
    }
    if (includes[key] !== undefined) {
      if (typeof includes[key] !== 'string' || !includes[key].endsWith('.json')) {
        fail(`${key} include must be one JSON file`);
      }
      const includedPath = resolve(rootDir, includes[key]);
      if (!inside(rootDir, includedPath)) fail(`${key} include escapes project`);
      rejectSymlinkComponents(includedPath);
      const value = readJson(includedPath);
      if (!Array.isArray(value)) fail(`${key} include must contain an array`);
      config[key] = value;
    }
  }

  if (typeof config.projectId !== 'string' || config.projectId === '') {
    fail('config projectId is required');
  }
  if (typeof config.endpoint !== 'string' || config.endpoint === '') {
    fail('config endpoint is required for target binding');
  }
  if (!Array.isArray(config.tablesDB) || !Array.isArray(config.tables)) {
    fail('complete tablesDB and tables arrays are required');
  }
  return config;
}

function object(value, label) {
  if (!value || Array.isArray(value) || typeof value !== 'object') fail(`${label} must be an object`);
  return value;
}

function knownFields(value, allowed, label) {
  const unknown = Object.keys(value)
    .filter((key) => !allowed.has(key))
    .sort();
  if (unknown.length > 0) fail(`unknown material field at ${label}: ${unknown.join(', ')}`);
}

function text(value, label) {
  if (typeof value !== 'string' || value === '') fail(`${label} must be a non-empty string`);
  return value;
}

function boolean(value, fallback, label) {
  if (value === undefined) return fallback;
  if (typeof value !== 'boolean') fail(`${label} must be boolean`);
  return value;
}

function nullable(value) {
  return value === undefined ? null : value;
}

function stringArray(value, fallback, label, { sort = false } = {}) {
  const actual = value === undefined ? fallback : value;
  if (!Array.isArray(actual) || actual.some((item) => typeof item !== 'string')) {
    fail(`${label} must be an array of strings`);
  }
  const result = [...actual];
  return sort ? [...new Set(result)].sort() : result;
}

function lengths(value, label) {
  const actual = value ?? [];
  if (!Array.isArray(actual) || actual.some((item) => item !== null && (!Number.isSafeInteger(item) || item < 0))) {
    fail(`${label} must be an array of non-negative integers or null`);
  }
  return [...actual];
}

function ready(value, label) {
  if (value.status !== undefined && value.status !== 'available') {
    fail(`${label} is not available: ${String(value.status)}`);
  }
  if (value.error !== undefined && value.error !== null && value.error !== '') {
    fail(`${label} reports an error`);
  }
}

function normalizeDatabase(raw, label) {
  const value = object(raw, label);
  knownFields(value, DATABASE_FIELDS, label);
  return {
    $id: text(value.$id, `${label}.$id`),
    enabled: boolean(value.enabled, true, `${label}.enabled`),
    type: nullable(value.type),
  };
}

function normalizeColumn(raw, label) {
  const value = object(raw, label);
  knownFields(value, COLUMN_FIELDS, label);
  ready(value, label);
  const key = value.key ?? value.$id;
  if (value.key !== undefined && value.$id !== undefined && value.key !== value.$id) {
    fail(`${label} has conflicting key and $id`);
  }
  const declaredType = text(value.type, `${label}.type`);
  const type = declaredType === 'float' ? 'double' : declaredType;
  if (!COLUMN_TYPES.has(type)) fail(`unknown material column type at ${label}: ${type}`);
  return {
    key: text(key, `${label}.key`),
    type,
    required: boolean(value.required, false, `${label}.required`),
    array: boolean(value.array, false, `${label}.array`),
    size: nullable(value.size),
    format: nullable(value.format),
    default: nullable(value.default),
    min: nullable(value.min),
    max: nullable(value.max),
    elements: value.elements === undefined ? null : stringArray(value.elements, [], `${label}.elements`, { sort: true }),
    encrypt: boolean(value.encrypt, false, `${label}.encrypt`),
    relatedTable: nullable(value.relatedTable ?? value.relatedTableId),
    relationType: nullable(value.relationType),
    twoWay: boolean(value.twoWay, false, `${label}.twoWay`),
    twoWayKey: nullable(value.twoWayKey),
    onDelete: nullable(value.onDelete),
    side: nullable(value.side),
  };
}

function normalizeIndex(raw, label) {
  const value = object(raw, label);
  knownFields(value, INDEX_FIELDS, label);
  ready(value, label);
  const key = value.key ?? value.$id;
  if (value.key !== undefined && value.$id !== undefined && value.key !== value.$id) {
    fail(`${label} has conflicting key and $id`);
  }
  if (value.attributes !== undefined && value.columns !== undefined) {
    fail(`${label} has both attributes and columns`);
  }
  const type = text(value.type, `${label}.type`);
  if (!INDEX_TYPES.has(type)) fail(`unknown material index type at ${label}: ${type}`);
  return {
    key: text(key, `${label}.key`),
    type,
    attributes: stringArray(value.attributes ?? value.columns, [], `${label}.attributes`),
    lengths: lengths(value.lengths, `${label}.lengths`),
    orders: stringArray(value.orders, [], `${label}.orders`),
  };
}

function normalizedSchema(document, label) {
  const source = object(document, label);
  if (!Array.isArray(source.tablesDB) || !Array.isArray(source.tables)) {
    fail(`${label} requires complete tablesDB and tables arrays`);
  }
  const databases = source.tablesDB.map((value, index) => normalizeDatabase(value, `${label}.tablesDB[${index}]`));
  databases.sort((left, right) => left.$id.localeCompare(right.$id));
  const databaseIds = new Set();
  for (const database of databases) {
    if (databaseIds.has(database.$id)) fail(`${label} duplicate database ${database.$id}`);
    databaseIds.add(database.$id);
  }
  const tables = source.tables.map((raw, index) => {
    const value = object(raw, `${label}.tables[${index}]`);
    knownFields(value, TABLE_FIELDS, `${label}.tables[${index}]`);
    const id = text(value.$id, `${label}.tables[${index}].$id`);
    const databaseId = text(value.databaseId, `${label}.tables[${index}].databaseId`);
    if (!databaseIds.has(databaseId)) {
      fail(`${label} table ${id} references missing database ${databaseId}`);
    }
    if (value.columns !== undefined && value.attributes !== undefined) {
      fail(`${label} table ${databaseId}/${id} has both columns and attributes`);
    }
    const columnValues = value.columns ?? value.attributes ?? [];
    if (!Array.isArray(columnValues) || !Array.isArray(value.indexes ?? [])) {
      fail(`${label} table ${databaseId}/${id} has invalid columns/indexes`);
    }
    const columns = columnValues.map((column, columnIndex) =>
      normalizeColumn(column, `${label} table ${databaseId}/${id} column[${columnIndex}]`),
    );
    columns.sort((left, right) => left.key.localeCompare(right.key));
    const columnKeys = new Set();
    for (const column of columns) {
      if (columnKeys.has(column.key)) fail(`${label} duplicate column ${databaseId}/${id}/${column.key}`);
      columnKeys.add(column.key);
    }
    const indexes = (value.indexes ?? []).map((item, itemIndex) =>
      normalizeIndex(item, `${label} table ${databaseId}/${id} index[${itemIndex}]`),
    );
    indexes.sort((left, right) => left.key.localeCompare(right.key));
    const indexKeys = new Set();
    for (const item of indexes) {
      if (indexKeys.has(item.key)) fail(`${label} duplicate index ${databaseId}/${id}/${item.key}`);
      indexKeys.add(item.key);
      const arrayColumns = item.attributes.filter((key) => columns.some((column) => column.key === key && column.array));
      if (arrayColumns.length > 0) {
        fail(`${label} index ${databaseId}/${id}/${item.key} uses array column: ${arrayColumns.join(', ')}`);
      }
    }
    const dollarPermissions =
      value.$permissions === undefined
        ? undefined
        : stringArray(value.$permissions, [], `${label} table ${databaseId}/${id}.$permissions`, { sort: true });
    const plainPermissions =
      value.permissions === undefined
        ? undefined
        : stringArray(value.permissions, [], `${label} table ${databaseId}/${id}.permissions`, { sort: true });
    if (dollarPermissions !== undefined && plainPermissions !== undefined && !same(dollarPermissions, plainPermissions)) {
      fail(`${label} table ${databaseId}/${id} has conflicting permission fields`);
    }
    return {
      $id: id,
      databaseId,
      enabled: boolean(value.enabled, true, `${label} table ${databaseId}/${id}.enabled`),
      rowSecurity: boolean(value.rowSecurity, false, `${label} table ${databaseId}/${id}.rowSecurity`),
      permissions: dollarPermissions ?? plainPermissions ?? [],
      columns,
      indexes,
    };
  });
  tables.sort((left, right) => `${left.databaseId}/${left.$id}`.localeCompare(`${right.databaseId}/${right.$id}`));
  const tableIds = new Set();
  for (const table of tables) {
    const id = `${table.databaseId}/${table.$id}`;
    if (tableIds.has(id)) fail(`${label} duplicate table ${id}`);
    tableIds.add(id);
  }
  return { tablesDB: databases, tables };
}

function maps(schema) {
  return {
    databases: new Map(schema.tablesDB.map((database) => [database.$id, database])),
    tables: new Map(schema.tables.map((table) => [`${table.databaseId}/${table.$id}`, table])),
  };
}

function same(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function compareTable(candidate, prior, id, label, additions) {
  if (candidate.enabled !== prior.enabled) fail(`incompatible table enabled change: ${label}:${id}`);
  if (candidate.rowSecurity !== prior.rowSecurity) fail(`permission/access row-security change: ${label}:${id}`);
  if (!same(candidate.permissions, prior.permissions)) fail(`permission/access table permission change: ${label}:${id}`);
  const candidateColumns = new Map(candidate.columns.map((column) => [column.key, column]));
  for (const column of prior.columns) {
    const replacement = candidateColumns.get(column.key);
    if (!replacement) fail(`destructive removal: ${label}:column:${id}/${column.key}`);
    if (!same(replacement, column)) {
      const relationship = column.relationType !== null || replacement.relationType !== null;
      fail(`${relationship ? 'relationship' : 'incompatible column'} change: ${label}:${id}/${column.key}`);
    }
  }
  const priorColumns = new Set(prior.columns.map((column) => column.key));
  for (const column of candidate.columns) {
    if (priorColumns.has(column.key)) continue;
    if (column.required || column.relationType !== null || column.relatedTable !== null) {
      fail(`unknown material column addition: ${label}:${id}/${column.key}`);
    }
    additions.add(`column:${id}/${column.key}`);
  }
  const candidateIndexes = new Map(candidate.indexes.map((item) => [item.key, item]));
  for (const item of prior.indexes) {
    const replacement = candidateIndexes.get(item.key);
    if (!replacement) fail(`destructive removal: ${label}:index:${id}/${item.key}`);
    if (!same(replacement, item)) fail(`incompatible index change: ${label}:${id}/${item.key}`);
  }
  const priorIndexes = new Set(prior.indexes.map((item) => item.key));
  for (const item of candidate.indexes) {
    if (!priorIndexes.has(item.key)) additions.add(`index:${id}/${item.key}`);
  }
}

export function checkManifest(config, inventory, baseline, now = Date.now()) {
  if (inventory.projectId !== config.projectId) fail('inventory project mismatch');
  if (inventory.endpoint !== config.endpoint) fail('inventory endpoint mismatch');
  const capturedAt = Date.parse(inventory.capturedAt);
  if (!Number.isFinite(capturedAt)) fail('inventory capturedAt is required');
  if (capturedAt > now + MAX_CLOCK_SKEW_MS) fail('inventory capturedAt is in the future');
  if (now - capturedAt > MAX_INVENTORY_AGE_MS) fail('inventory is stale');
  const candidateSchema = normalizedSchema(config, 'candidate');
  const candidate = maps(candidateSchema);
  const additions = new Set();
  /** @type {Array<[ReturnType<typeof maps>, string]>} */
  const required = [[maps(normalizedSchema(inventory, 'inventory')), 'inventory']];
  if (baseline) {
    if (baseline.projectId !== config.projectId) fail('baseline project mismatch');
    required.push([maps(normalizedSchema(baseline, 'baseline')), 'baseline']);
  }
  const priorDatabaseIds = new Set();
  const priorTableIds = new Set();
  for (const [source, label] of required) {
    for (const [id, database] of source.databases) {
      priorDatabaseIds.add(id);
      const replacement = candidate.databases.get(id);
      if (!replacement) fail(`destructive removal: ${label}:database:${id}`);
      if (replacement.enabled !== database.enabled) fail(`incompatible database enabled change: ${label}:${id}`);
      if (replacement.type !== null && database.type !== null && replacement.type !== database.type) {
        fail(`unknown material database type change: ${label}:${id}`);
      }
    }
    for (const [id, table] of source.tables) {
      priorTableIds.add(id);
      const replacement = candidate.tables.get(id);
      if (!replacement) fail(`destructive removal: ${label}:table:${id}`);
      compareTable(replacement, table, id, label, additions);
    }
  }
  for (const [id] of candidate.databases) {
    if (!priorDatabaseIds.has(id)) additions.add(`database:${id}`);
  }
  for (const [id, table] of candidate.tables) {
    if (priorTableIds.has(id)) continue;
    if (table.permissions.length > 0) fail(`permission/access new table permissions: ${id}`);
    if (table.columns.some((column) => column.relationType !== null || column.relatedTable !== null)) {
      fail(`unknown material relationship on new table: ${id}`);
    }
    additions.add(`table:${id}`);
  }
  return {
    result: 'PASS',
    databases: candidate.databases.size,
    tables: candidate.tables.size,
    additiveChanges: [...additions].sort(),
  };
}

function stopProcessGroup(pid) {
  if (process.platform === 'win32' || !Number.isSafeInteger(pid) || pid <= 0) return;
  try {
    process.kill(-pid, 'SIGKILL');
  } catch (error) {
    if (errorCode(error) !== 'ESRCH') throw error;
  }
}

function errorCode(error) {
  return /** @type {{code?: string} | undefined} */ (error)?.code;
}

function cleanupFailureSuffix(error) {
  return error ? `; process-group cleanup failed: ${errorCode(error) ?? 'unknown'}` : '';
}

function errorValue(value, fallback) {
  return value instanceof Error ? value : new Error(fallback, { cause: value });
}

function failWithCleanup(message, primaryError, cleanupError) {
  const primary = errorValue(primaryError, message);
  if (cleanupError) {
    const cleanup = errorValue(cleanupError, 'process-group cleanup failed');
    throw new AggregateError([primary, cleanup], `${message}${cleanupFailureSuffix(cleanup)}`, { cause: primary });
  }
  throw new Error(message, { cause: primary });
}

function failCleanup(error) {
  const cleanup = errorValue(error, 'process-group cleanup failed');
  throw new Error(`Appwrite CLI process-group cleanup failed: ${errorCode(cleanup) ?? 'unknown'}`, {
    cause: cleanup,
  });
}

function spawnBounded(executable, args, options) {
  const spawnOptions = {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout: options.timeoutMs ?? CLI_TIMEOUT_MS,
    maxBuffer: MAX_OUTPUT_BYTES,
    killSignal: 'SIGKILL',
    detached: process.platform !== 'win32',
  };
  const result = spawnSync(executable, args, /** @type {any} */ (spawnOptions));
  let cleanupError;
  try {
    stopProcessGroup(result.pid);
  } catch (error) {
    cleanupError = error;
  }
  return { result, cleanupError };
}

function runCli(executable, args, options = {}) {
  const { result, cleanupError } = spawnBounded(executable, args, options);
  if (errorCode(result.error) === 'ETIMEDOUT' || result.signal) {
    failWithCleanup(`Appwrite CLI timed out: ${args.slice(0, 3).join(' ')}`, result.error, cleanupError);
  }
  if (result.error) {
    failWithCleanup(`Appwrite CLI could not start: ${errorCode(result.error) ?? 'unknown'}`, result.error, cleanupError);
  }
  if (result.status !== 0) {
    failWithCleanup(`Appwrite CLI failed: ${args.slice(0, 3).join(' ')} exit=${String(result.status)}`, undefined, cleanupError);
  }
  const output = String(result.stdout);
  for (let index = 0; index < output.length; index += 1) {
    if (output[index] !== '{' && output[index] !== '[') continue;
    let value;
    try {
      value = JSON.parse(output.slice(index).trim());
    } catch {
      continue;
    }
    if (cleanupError) failCleanup(cleanupError);
    return value;
  }
  failWithCleanup(`Appwrite CLI returned non-JSON: ${args.slice(0, 3).join(' ')}`, undefined, cleanupError);
}

function debugEndpoint(executable, options = {}) {
  const { result, cleanupError } = spawnBounded(executable, ['client', '--debug'], options);
  if (errorCode(result.error) === 'ETIMEDOUT' || result.signal) {
    failWithCleanup('Appwrite CLI timed out: client --debug', result.error, cleanupError);
  }
  if (result.error) {
    failWithCleanup(`Appwrite CLI could not start: ${errorCode(result.error) ?? 'unknown'}`, result.error, cleanupError);
  }
  if (result.status !== 0) {
    failWithCleanup(`Appwrite CLI failed: client --debug exit=${String(result.status)}`, undefined, cleanupError);
  }
  const endpoint = String(result.stdout)
    .match(/^endpoint\s+(.+)$/m)?.[1]
    ?.trim();
  if (!endpoint) failWithCleanup('Appwrite CLI failed: client --debug missing endpoint', undefined, cleanupError);
  if (cleanupError) failCleanup(cleanupError);
  return endpoint;
}

function paged(executable, command, key, options = {}) {
  const all = [];
  let expectedTotal;
  let previousPage;
  const pageLimit = options.maxPages ?? MAX_PAGES;
  const itemLimit = options.maxItems ?? MAX_ITEMS;
  for (let pageIndex = 0; pageIndex < pageLimit; pageIndex += 1) {
    const offset = pageIndex * PAGE_SIZE;
    const page = runCli(executable, ['--raw', ...command, '--limit', String(PAGE_SIZE), '--offset', String(offset)], options);
    if (!Array.isArray(page[key])) fail(`Appwrite response lacks ${key} array`);
    if (!Number.isSafeInteger(page.total) || page.total < 0) fail(`Appwrite response has invalid ${key} total`);
    if (expectedTotal === undefined) expectedTotal = page.total;
    if (page.total !== expectedTotal) fail(`Appwrite ${key} pagination total changed`);
    if (page[key].length > PAGE_SIZE) fail(`Appwrite ${key} page exceeds limit`);
    const pageIdentity = JSON.stringify(page[key]);
    if (page[key].length > 0 && pageIdentity === previousPage) {
      fail(`Appwrite ${key} pagination did not progress`);
    }
    previousPage = pageIdentity;
    all.push(...page[key]);
    if (all.length > itemLimit || expectedTotal > itemLimit) fail(`Appwrite ${key} inventory exceeds item ceiling`);
    if (all.length > expectedTotal) fail(`Appwrite ${key} pagination exceeded total`);
    if (all.length === expectedTotal) return all;
    if (page[key].length === 0 || page[key].length < PAGE_SIZE) {
      fail(`Appwrite ${key} pagination ended before total`);
    }
  }
  fail(`Appwrite ${key} pagination exceeds page ceiling`);
}

export function captureInventory(config, executable = 'appwrite', options = {}) {
  const endpoint = debugEndpoint(executable, options);
  if (endpoint !== config.endpoint) fail(`active endpoint mismatch: expected ${config.endpoint}; got ${endpoint ?? 'unknown'}`);
  const project = runCli(executable, ['--raw', 'project', 'get'], options);
  if (project.$id !== config.projectId) fail('active project mismatch');
  const databaseRows = paged(executable, ['tables-db', 'list'], 'databases', options);
  const databases = databaseRows.map((database) =>
    runCli(executable, ['--raw', 'tables-db', 'get', '--database-id', text(database.$id, 'database.$id')], options),
  );
  const tables = [];
  for (const database of databases) {
    const rows = paged(executable, ['tables-db', 'list-tables', '--database-id', database.$id], 'tables', options);
    for (const row of rows) {
      const table = runCli(
        executable,
        ['--raw', 'tables-db', 'get-table', '--database-id', database.$id, '--table-id', text(row.$id, 'table.$id')],
        options,
      );
      tables.push({ ...table, databaseId: database.$id });
    }
  }
  const schema = normalizedSchema({ tablesDB: databases, tables }, 'inventory');
  return {
    schemaVersion: 2,
    capturedAt: new Date().toISOString(),
    endpoint: config.endpoint,
    projectId: config.projectId,
    ...schema,
  };
}

export function writeExclusiveJson(path, value) {
  const output = resolve(path);
  rejectSymlinkComponents(output, false);
  const descriptor = openSync(output, constants.O_WRONLY | constants.O_CREAT | constants.O_EXCL | constants.O_NOFOLLOW, 0o600);
  try {
    writeFileSync(descriptor, `${JSON.stringify(value, null, 2)}\n`);
    fsyncSync(descriptor);
  } finally {
    closeSync(descriptor);
  }
  const parent = openSync(dirname(output), constants.O_RDONLY);
  try {
    fsyncSync(parent);
  } finally {
    closeSync(parent);
  }
}

function argsMap(values) {
  const parsed = { command: values[0] };
  for (let index = 1; index < values.length; index += 2) parsed[values[index].replace(/^--/, '')] = values[index + 1];
  return parsed;
}

function main(values) {
  const args = argsMap(values);
  if (args.command === 'capture') {
    if (!args.config || !args.output) fail('capture requires --config and --output');
    const inventory = captureInventory(loadManifest(args.config), args.appwrite ?? 'appwrite');
    writeExclusiveJson(args.output, inventory);
    console.log(JSON.stringify({ result: 'PASS', output: args.output }));
    return;
  }
  if (args.command === 'check') {
    if (!args.config || !args.inventory) fail('check requires --config and --inventory');
    const config = loadManifest(args.config);
    const baseline = args.baseline ? loadManifest(args.baseline) : undefined;
    console.log(JSON.stringify(checkManifest(config, readJson(args.inventory), baseline)));
    return;
  }
  fail('usage: appwrite-schema-guard.mjs capture|check ...');
}

if (process.argv[1] && fileURLToPath(import.meta.url) === realpathSync(process.argv[1])) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    console.error(JSON.stringify({ result: 'FAIL', error: error.message }));
    process.exitCode = 1;
  }
}
