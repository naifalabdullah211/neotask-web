import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';

test('automation fallback no longer runs every fifteen minutes', () => {
  const workflow = readFileSync(
    new URL('../.github/workflows/run-automations.yml', import.meta.url),
    'utf8',
  );

  assert.doesNotMatch(workflow, /cron:\s*['"]\*\/15 /);
  assert.match(workflow, /cron:\s*['"]7 \* \* \* \*['"]/);
  assert.match(workflow, /workflow_dispatch:/);
});

test('backend keeps immediate events separate from hourly scheduling', () => {
  const functions = readFileSync(
    new URL('../functions/index.js', import.meta.url),
    'utf8',
  );

  assert.match(functions, /runAutomationsOnTaskCreated = onDocumentCreated/);
  assert.match(functions, /runAutomationsOnTaskStatusChanged = onDocumentUpdated/);
  assert.match(functions, /schedule: "every 60 minutes"/);
  assert.match(functions, /source: "firestore-event"/);
  assert.match(functions, /source: "cloud-scheduler"/);
});
