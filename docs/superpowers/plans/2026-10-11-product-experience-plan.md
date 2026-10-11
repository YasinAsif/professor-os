# Product Experience Implementation Plan

## Phase 1: Shared Navigation and Course Discovery

- Improve mobile navigation with clear role-aware destinations and current-location context.
- Add course search across title, code, semester, and professor.
- Show filtered result counts and preserve active/archived filtering.
- Normalize course-list error handling through the shared error parser and add retry.
- Add widget tests for filtering and navigation semantics.

## Phase 2: Role Action Queues

- Student: make upcoming deadlines and feedback the first actionable region.
- Professor: surface drafts, unpublished rubrics, pending submissions, and analytics entry points.
- TA: focus the dashboard on delegated assignments and pending grading.
- Admin: prioritize pending approvals and account health.

## Phase 3: Workflow Polish and Verification

- Add confirmation flows for destructive actions.
- Verify small-screen layout, text scaling, keyboard focus, and error recovery.
- Run backend regression tests, Flutter analyzer/tests, and browser smoke tests.
- Record unresolved infrastructure blockers separately from product defects.
