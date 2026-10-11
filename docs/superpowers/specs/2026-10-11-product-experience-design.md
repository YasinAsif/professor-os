# ProfessorOS Product Experience Design

## Product Direction

ProfessorOS should feel like an academic operations desk: calm, trustworthy, and fast to scan. The existing Journal visual language is the right foundation, but every screen should answer three questions immediately: where am I, what needs attention, and what is the next safe action?

## Primary User Journeys

1. Student: sign in -> see upcoming work -> open a course -> read material -> submit -> see grading state and feedback.
2. Professor: sign in -> see active courses -> open a course -> create assignment -> attach CLOs -> build rubric -> publish -> review submissions -> grade -> inspect analytics.
3. TA: sign in -> open a focused grading queue -> inspect assigned submissions -> grade within the assignment scale -> return to the queue.
4. Admin: sign in -> see pending approvals and system health -> approve/manage accounts -> inspect course coverage.

## Interaction Principles

- Role-aware navigation uses human labels, not icon-only discovery.
- The main page of each role is an action queue, not a static report.
- Lists support search, filters, and predictable empty/loading/error states.
- Destructive actions require confirmation and explain consequences.
- Scores, deadlines, publication state, and review state are always visible together.
- Errors are translated into next steps; raw transport or database text never reaches users.
- Mobile keeps the primary action reachable without opening a deep drawer for every task.

## First Implementation Slice

The first slice improves the highest-frequency shared surface: course navigation and course discovery. It adds a persistent mobile-friendly navigation affordance, a searchable course ledger, visible result counts, accessible semantics, and consistent retry/error handling. It preserves the Journal palette and existing routes so the change is low-risk and composable.

## Later Slices

- Student action queue: due soon, awaiting feedback, and recent results.
- Professor command center: draft assignments, unpublished rubrics, pending submissions, and at-risk signals.
- TA grading queue: delegated-only work, keyboard-friendly grading, and explicit max-mark context.
- Admin operations: approval queue, account state, and audit-oriented status language.
- Cross-cutting UX: confirmations, optimistic refresh, offline/retry messaging, and visual regression checks at mobile and desktop widths.

## Quality Bar

- No clipped text or horizontal overflow at 360px, 768px, and 1440px.
- Every async surface has loading, success, empty, error, and retry states where applicable.
- Primary actions are reachable by keyboard and have tooltips/semantic labels.
- Existing backend permission and grading tests remain green.
- Flutter analyzer/tests complete without hanging.
