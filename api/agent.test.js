import assert from 'node:assert/strict';
import test from 'node:test';

import {
  buildLocalFallback,
  normalizeProviderKey,
  resolveGatewayCredential,
} from './agent.js';

test('normalizeProviderKey removes embedded whitespace', () => {
  assert.equal(
    normalizeProviderKey('  example-key-part-one\npart-two\r\n  '),
    'example-key-part-onepart-two',
  );
});

test('normalizeProviderKey handles missing values', () => {
  assert.equal(normalizeProviderKey(undefined), '');
});

test('resolveGatewayCredential prefers automatic Vercel OIDC', () => {
  assert.equal(
    resolveGatewayCredential({
      VERCEL_OIDC_TOKEN: 'oidc-token',
      AI_GATEWAY_API_KEY: 'manual-key',
      OPENAI_API_KEY: 'legacy-key-must-not-be-used',
    }),
    'oidc-token',
  );
});

test('resolveGatewayCredential never falls back to legacy OpenAI key', () => {
  assert.equal(
    resolveGatewayCredential({OPENAI_API_KEY: 'legacy-key'}),
    '',
  );
});

test('local fallback summarizes live team context', () => {
  const result = buildLocalFallback({
    prompt: 'لخص أداء الفريق',
    today: '2026-08-08',
    teamContext: [
      {name: 'سارة', activeTasks: 3, overdueTasks: 1, plannedHours: 8},
      {name: 'محمد', activeTasks: 2, overdueTasks: 0, plannedHours: 5},
    ],
  });
  assert.match(result.reply, /5 مهمة نشطة/);
  assert.match(result.reply, /1 متأخرة/);
  assert.equal(result.action, null);
});

test('local fallback prepares an approvable task with Arabic relative date', () => {
  const result = buildLocalFallback({
    prompt: 'كلف سارة بمهمة مراجعة التقرير غدًا بشكل عاجل',
    today: '2026-08-08',
    teamContext: [{
      uid: 'employee-1',
      name: 'سارة',
      employeeNumber: '400200',
      activeTasks: 0,
      overdueTasks: 0,
      plannedHours: 0,
    }],
  });
  assert.equal(result.action?.type, 'create_task_draft');
  assert.equal(result.action?.employeeUid, 'employee-1');
  assert.equal(result.action?.dueDate, '2026-08-09');
  assert.equal(result.action?.priority, 'high');
  assert.equal(result.action?.requiresApproval, true);
});

test('local fallback asks for assignee instead of inventing one', () => {
  const result = buildLocalFallback({
    prompt: 'أنشئ مهمة مراجعة التقرير غدًا',
    today: '2026-08-08',
    teamContext: [],
  });
  assert.match(result.reply, /اسم الموظف/);
  assert.equal(result.action, null);
});
