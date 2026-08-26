# NeoTask automation architecture

NeoTask separates automation from the eight AI analysis agents:

- Firestore event functions run `taskCreated` and `statusChanged` rules immediately.
- The hourly scheduler runs only `dueSoon`, `overdue`, and knowledge-review reminders.
- GitHub Actions is a temporary hourly safety net for Spark-plan production and a
  manual recovery command. Remove its `schedule` trigger after the backend
  functions are deployed and verified.
- The AI agents remain on-demand analysis and drafting tools. They do not poll
  Firestore and do not replace the automation executor.

Every rule execution reserves a deterministic `automation_runs` document before
performing its action. This makes retries idempotent. New records include
`trigger`, `source`, `startedAt`, `completedAt`, and `durationMs` so the UI can
show whether a run was immediate, scheduled, or handled by the fallback.

## Production cutover

1. Upgrade the Firebase project to a plan that supports Functions and Scheduler.
2. Deploy and verify these functions:
   - `runAutomationsOnTaskCreated`
   - `runAutomationsOnTaskStatusChanged`
   - `runScheduledAutomations`
3. Create a task and change its status; confirm two `automation_runs` records
   have `source: firestore-event` when matching rules exist.
4. Confirm an hourly run has `source: cloud-scheduler` for a matching time rule.
5. Remove the `schedule` block from `.github/workflows/run-automations.yml` and
   retain `workflow_dispatch` for manual recovery.

Do not remove the fallback schedule before steps 1-4 are complete.
