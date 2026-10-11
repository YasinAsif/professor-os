# Phase 1 and Phase 2 Execution Record

## Scope

This iteration hardens deterministic grading triage and verifies the existing
role workflows. Cross-submission similarity and plagiarism detection are
explicitly out of scope.

## Completed Slice 1

- Added deterministic prompt-injection detection for score overrides, rubric
  bypasses, system/developer spoofing, role tags, and fake score payloads.
- Kept student content inside the existing untrusted grading boundary.
- Persisted `needs_review`, `triage_reasons`, and `injection_detected` in
  submission evaluation metadata.
- Blocked provider calls for deterministic injection matches in sync and Celery
  grading paths.
- Added blank/unreadable, scanned/image-only, and truncation triage codes.
- Added Professor/TA triage badges and filters to the assignment submission
  workspace.

## Phase 2 Verification Surface

- Added a student action queue with Due Soon, Needs Submission, Feedback Ready,
  and Needs Resubmission filters, triage notices, and retryable error state.
- Added Professor/TA triage filters, status counters, and a Next Matching queue
  jump for prompt injection, unreadable/scanned, ungraded, and human-review
  work.
- Preserved confirmation guards for destructive and batch-grade overwrite
  actions and human-readable retry states for analytics.
- Added Flutter widget coverage for triage badges/chips and course search,
  active/archive filters, and actionable empty states.
- Added deterministic local Selenium provisioning for four valid role accounts,
  a seeded course and assignment, enrollment/delegation, and lifecycle-managed
  local API/static server. The complete role suite executes without skips.

## Gates

- Backend suite: 42 passed.
- Flutter suite: 21 passed.
- Flutter analyzer: no issues found.
- Web build: successful.
- Browser suite: 21 passed, 0 skipped, 0 failed.
