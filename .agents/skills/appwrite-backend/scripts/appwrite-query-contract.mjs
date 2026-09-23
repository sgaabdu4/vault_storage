#!/usr/bin/env node

export function uniqueSelectFields(fields, label = 'Query.select') {
  if (!Array.isArray(fields) || fields.length === 0 || fields.some((field) => typeof field !== 'string' || field.length === 0)) {
    throw new Error(`${label} requires non-empty string fields`);
  }
  const seen = new Set();
  const duplicates = new Set();
  for (const field of fields) {
    if (seen.has(field)) duplicates.add(field);
    seen.add(field);
  }
  if (duplicates.size > 0) {
    throw new Error(`${label} duplicates: ${[...duplicates].sort().join(', ')}`);
  }
  return [...fields];
}
