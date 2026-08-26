# NeoTask automation architecture

NeoTask separates automation from the eight AI analysis agents:

- The manager live runner executes `taskCreated` and `statusChanged` rules
  immediately while a manager is using NeoTask.
- The hourly scheduler runs only `dueSoon`, `overdue`, and knowledge-review reminders.
- GitHub Actions is the hourly offline safety net and manual recovery command.
- The AI agents remain on-demand analysis and drafting tools. They do not poll
  Firestore and do not replace the automation executor.

Every rule execution reserves a deterministic `automation_runs` document before
performing its action. This makes retries idempotent. New records include
`trigger`, `source`, `startedAt`, `completedAt`, and `durationMs` so the UI can
show whether a run was immediate, scheduled, or handled by the fallback.

## Production cutover

Create a task and change its status while a manager is online. Matching rules
must create `automation_runs` records with `source: manager-live`. When no
manager is online, the hourly GitHub runner reconciles missed events using the
same deterministic run IDs.
