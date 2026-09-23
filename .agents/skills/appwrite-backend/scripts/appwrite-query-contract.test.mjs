import assert from 'node:assert/strict';
import test from 'node:test';

import { uniqueSelectFields } from './appwrite-query-contract.mjs';

test('unique select fields preserve order', () => {
  assert.deepEqual(uniqueSelectFields(['$id', 'priority', 'status']), ['$id', 'priority', 'status']);
});

test('duplicate select field fails locally', () => {
  assert.throws(() => uniqueSelectFields(['$id', 'priority', 'priority']), /Query\.select duplicates: priority/);
});

test('invalid select shape fails locally', () => {
  assert.throws(() => uniqueSelectFields([]), /requires non-empty string fields/);
});
