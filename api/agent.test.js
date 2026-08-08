import assert from 'node:assert/strict';
import test from 'node:test';

import {normalizeProviderKey} from './agent.js';

test('normalizeProviderKey removes embedded whitespace', () => {
  assert.equal(
    normalizeProviderKey('  example-key-part-one\npart-two\r\n  '),
    'example-key-part-onepart-two',
  );
});

test('normalizeProviderKey handles missing values', () => {
  assert.equal(normalizeProviderKey(undefined), '');
});
