# Work Plan design QA

## Source visual truth

- Selected concept 3: `/workspace/scratch/f6e85fd0dc19/generated_images/exec-d8f31926-b355-4114-bc43-943911bccc2e.png`.
- Source pixels: 1536 × 1024.
- Intended state: authenticated Arabic RTL Work Plan timeline on a wide desktop viewport.

## Rendered implementation evidence

- Production URL: `https://neotask1-ff5a4.web.app/?_build=6402fd6`.
- Build evidence: GitHub Actions run 58 completed successfully for commit `6402fd6029ff63ff32fad945fb53e8325fdf78ea`; Flutter web build and Firebase deployment passed.
- Browser viewport: 1363 × 936 CSS pixels at DPR 1.
- Browser result: the fresh QA browser was routed to the manager-setup gate before the authenticated Work Plan route could be opened.
- Implementation screenshot path: unavailable because the authenticated Work Plan state could not be reached. The browser capture shows the manager-setup gate and is not a valid same-state comparison artifact.

## Full-view comparison evidence

- Blocked. The selected source is an authenticated Work Plan screen while the browser-rendered production state is manager setup. Layout, density, typography, spacing, colors, timeline geometry, task selection, and responsive behavior cannot be judged from different product states.

## Focused region comparison evidence

- Blocked for the same authentication-state mismatch. No focused region comparison would be valid.

## Runtime checks

- Production build and Firebase deployment completed successfully.
- Browser console showed no application-origin exception. The only page warning was CPU rendering because WebGL was unavailable; extension metadata errors came from the cloud-browser extension, not NeoTask.
- Primary interactions tested: public app load only. Task selection, timeline scale, synchronized scrolling, details panel, edit action, and mobile bottom sheet remain visually unverified in the production browser.

## Findings

- [P1] Authenticated target state unavailable for visual verification.
  - Location: production Work Plan route.
  - Evidence: the QA browser loaded manager setup instead of the Work Plan screen.
  - Impact: the implementation cannot be compared against concept 3 at the same viewport and state.
  - Fix: capture the authenticated Work Plan screen from an existing signed-in session, then compare it at the same wide viewport and repeat at the mobile breakpoint.

## Comparison history

- Iteration 1: deployment passed, but the fresh browser was routed to manager setup. No visual fixes were made because the target screen was not observable.

## Implementation checklist

- Capture authenticated Work Plan at a wide desktop viewport.
- Compare it side by side with concept 3.
- Verify task selection, scale selection, synchronized vertical scrolling, and details actions.
- Capture the mobile Work Plan and verify the bottom-sheet details interaction.
- Fix any P0/P1/P2 differences and rerun the comparison.

## Automation workspace QA — 2026-08-02

### Source visual truth

- Approved automation design: `/workspace/scratch/f6e85fd0dc19/generated_images/exec-1d1cc440-de3b-467f-8ce2-05fa216ccfc9.png`.
- Intended state: authenticated Arabic RTL automation workspace with grouped rules on the right, a vertical trigger/condition/action path in the center, rule details on the left, and responsive mobile details.

### Implementation coverage

- App header and primary mint action match the established Work Plan screen.
- Metrics use the approved four values: total rules, active rules, successful runs today, and runs requiring review.
- Rules are grouped into active and paused sections, with execution state and relative time.
- The selected rule uses the approved vertical trigger → condition → action path with navy/gold semantic blocks and execution result.
- Details include creator identity, rule state, path, execution totals, success rate, latest activity, edit, duplicate, pause/resume, and delete actions.
- Tablet and mobile layouts open the same detail surface as a bottom sheet.
- Existing automation storage, toggle, edit, delete, and run-history behavior remains connected; duplication creates an inactive copy.

### Verification state

- Source structure and balanced delimiters passed local checks.
- Responsive widget tests were added for desktop, tablet, mobile, metrics, and run history.
- Flutter is not installed in the local workspace, so the new widget tests and rendered implementation cannot be executed or captured locally.
- The production site still contains the previous automation screen because this change has not been pushed or deployed.

### Blocking finding

- [P1] Same-state rendered comparison is unavailable until the commit is built in the repository workflow and the authenticated automation route is opened.
- Required follow-up: run Flutter tests/build after push, capture the authenticated automation screen at desktop and mobile breakpoints, compare it with the approved source, and correct any P0/P1/P2 mismatch before production acceptance.

final result: blocked

## Secondary manager workspaces QA — 2026-08-02

### Design target

- Calendar, Goals, Personal Tasks and Polls use the already approved Work
  Plan/Automation visual system: 24px heavy page title, mint primary action,
  white horizontal metrics, RTL list/canvas/details workspace, and bottom-sheet
  details below the desktop breakpoint.
- Existing providers, routes, permissions and write operations remain the
  source of truth; this pass changes information architecture and presentation.

### Implementation coverage

- Calendar: daily/weekly/monthly modes, today/week/month/overdue metrics,
  day agenda, calendar canvas and selected-day details.
- Goals: portfolio filters, total/active/completed/criteria/late metrics,
  measurable-criteria progress canvas and goal details.
- Personal Tasks: all/today/upcoming/completed filters, private metrics,
  focus canvas, completion/reopen actions and task details.
- Polls: all/active/draft/ended/cancelled filters, lifecycle metrics, decision
  options canvas, privacy/participant/deadline details and archived-poll access.
- Responsive widget tests cover desktop and mobile Personal Tasks/Polls, and
  the contract test imports all four top-level screens so CI compiles them.

### Verification state

- Balanced delimiter and `git diff --check` checks pass locally.
- Flutter is not installed in this workspace, so the new widget tests cannot be
  executed before the repository workflow runs.
- A valid rendered comparison also requires an authenticated manager session;
  the available cloud-browser session cannot reach these private routes.

### Blocking finding

- [P1] Same-state rendered comparison remains blocked until the approved commit
  is built and an authenticated manager opens all four routes at desktop and
  mobile widths.
- Required follow-up: run Flutter tests/build in GitHub Actions, then inspect
  Calendar, Goals, Personal Tasks and Polls on the live authenticated app and
  fix any P0/P1/P2 mismatch before production acceptance.

final result: blocked
