import assert from 'node:assert/strict';
import test from 'node:test';

import {normalizeProviderKey} from './agent.js';

test('normalizeProviderKey removes embedded whitespace', () => {
  assert.equal(
    normalizeProviderKey('  sk-test-part-one\npart-two\r\n  '),
    'sk-test-part-onepart-two',
  );
});

test('normalizeProviderKey handles missing values', () => {
  assert.equal(normalizeProviderKey(undefined), '');
});
