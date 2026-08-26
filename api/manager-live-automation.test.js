import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';

test('manager home owns the live automation runner lifecycle', () => {
  const source = readFileSync(
    new URL('../lib/screens/manager/manager_home_screen.dart', import.meta.url),
    'utf8',
  );
  assert.match(source, /AutomationRuntimeService\.instance\.start/);
  assert.match(source, /AutomationRuntimeService\.instance\.stop/);
});

test('live runs share deterministic event keys with the hourly fallback', () => {
  const live = readFileSync(
    new URL('../lib/services/automation_runtime_service.dart', import.meta.url),
    'utf8',
  );
  const fallback = readFileSync(
    new URL('../scripts/run_automations.cjs', import.meta.url),
    'utf8',
  );
  assert.match(live, /created_\$\{task\['createdAt'\]\}/);
  assert.match(live, /status_\$\{task\['status'\]\}_\$\{task\['updatedAt'\]\}/);
  assert.match(fallback, /created_\$\{task\.createdAt\}/);
  assert.match(fallback, /status_\$\{task\.status\}_\$\{task\.updatedAt\}/);
});
