# ProfessorOS Audit Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing ProfessorOS foundation safe to run, migrate, test, and release without expanding the product beyond the implemented milestone.

**Architecture:** Preserve the current FastAPI + PostgreSQL + Redis + Celery + Flutter architecture. Repair the existing boundaries first: database migrations, worker boot, authentication, exam concurrency, downloads, readiness, and release artifacts. Keep one canonical implementation for each workflow and avoid a broad rewrite.

**Tech Stack:** Python 3.12, FastAPI, SQLAlchemy async, Alembic, PostgreSQL 16, Redis 7, Celery, Flutter/Dart, pytest, Flutter test/analyze, Selenium, Docker Compose, Railway.

---

## Scope decision

This plan covers defects that can cause data loss, security exposure, deployment failure, incorrect assessment behavior, or misleading release evidence.

It does not attempt to finish every feature described in the long-term SDS/SRS. The documents explicitly describe AI grading, full XAI, code execution, richer RAG, complete proctoring, notification workflows, formal load testing, and final operational handover as later work. Those features remain separate future phases unless the product owner changes the milestone scope.

## Files and responsibilities

### Backend runtime and deployment

- Modify `backend/app/main.py` only for health/readiness and removal of runtime schema mutation.
- Modify `backend/app/celery_app.py` and `docker-compose.yml` for the real Celery entrypoint and worker verification.
- Modify `backend/alembic/env.py` and create/modify Alembic revisions for complete schema ownership.
- Modify `backend/app/models/quiz_obe.py` and related models only when the migration/model contract requires it.

### Security and correctness

- Modify `backend/app/services/user_service.py` for administrative password-reset revocation and non-blocking hashing.
- Modify `backend/app/services/auth_service.py` and `backend/app/services/cache_service.py` for bounded revocation behavior and login throttling.
- Modify `backend/app/core/dependencies.py` and download endpoints to remove long-lived tokens from URLs.
- Modify `backend/app/api/v1/exams.py` and the `ExamAttempt` model/migration for concurrent start protection.

### Domain and performance

- Modify `backend/app/services/assignment_service.py` to use the current CLO model contract.
- Modify `backend/app/schemas/assignment.py` and the database migration for timing/attempt constraints.
- Modify `backend/app/services/course_service.py` for batched CSV enrollment.
- Modify `backend/app/services/analytics_service.py` and `backend/app/api/v1/analytics.py` for safe cache/snapshot behavior.

### Frontend and release artifacts

- Keep `frontend/lib/features/courses/presentation/exam_screen.dart` as the canonical modern exam flow.
- Either route `frontend/lib/features/courses/presentation/quiz_attempt_screen.dart` through the same shared flow or explicitly remove its legacy route after confirming callers.
- Keep only one generated Flutter web output directory, selected consistently by `backend/app/main.py` and the release process.
- Treat `backend/static/react` as either a compiled, supported product surface or an explicitly deprecated surface; do not silently maintain two frontends.

### Tests and evidence

- Add backend tests under `backend/tests/` for migration, concurrency, revocation, throttling, and worker contracts.
- Add frontend tests under `frontend/test/` for shared exam behavior and download behavior.
- Use `selenium_tests/` only for real browser flows that unit tests cannot validate.
- Update `README.md`, `CODE_ISSUES_REPORT.md`, and the final project report only after source and tests agree.

---

## Phase 0: Freeze scope and establish a clean baseline

### Task 0.1: Preserve the current working tree

**Files:** none.

- [ ] Record `git status --short` and save the output with the work log.
- [ ] Do not revert the existing user changes in `backend/data/dossiers/`.
- [ ] Create a dedicated branch or worktree before implementation.

Run:

```powershell
git status --short
git branch --show-current
```

Expected: the existing changes are visible and no unrelated file is discarded.

### Task 0.2: Run the existing baseline checks

- [ ] Run backend tests.
- [ ] Run Flutter tests and analyzer.
- [ ] Run Python compilation.
- [ ] Run `git diff --check`.

Commands:

```powershell
Push-Location backend
python -m pytest tests -q
python -m compileall -q app services
Pop-Location

Push-Location frontend
flutter test --no-pub --concurrency=1
flutter analyze --no-pub
Pop-Location

git diff --check
```

Expected: the current baseline remains green before any remediation begins.

---

## Phase 1: Make database schema ownership safe

### Task 1.1: Inventory ORM tables against Alembic tables

**Files:**

- Read: `backend/app/models/*.py`
- Read: `backend/alembic/versions/*.py`
- Test: create `backend/tests/test_schema_contract.py`

- [ ] Build a test that imports project metadata and asserts every application table has a migration-owned table or an explicit documented legacy exception.
- [ ] Include `quiz_questions`, `analytics_snapshots`, `at_risk_records`, `rubrics`, `rubric_criteria`, `rubric_levels`, `exam_attempts`, `submissions`, `assignments`, `users`, `courses`, `clos`, and `enrollments`.
- [ ] Run the test and confirm it fails for the current missing migration coverage.

### Task 1.2: Create a complete forward migration

**Files:**

- Create: `backend/alembic/versions/20261014_complete_foundation_schema.py`
- Modify: `backend/alembic/env.py` only if model metadata loading is incomplete
- Test: `backend/tests/test_schema_contract.py`

- [ ] Use existing database naming and model definitions; do not invent a second schema.
- [ ] Add the missing `quiz_questions` table and all missing foundation tables/constraints required by current models.
- [ ] Add uniqueness and check constraints for exam attempts, assignment timing, and maximum attempts only where existing business rules require them.
- [ ] Make the migration safe on the intended clean database and document whether it is baseline or incremental.
- [ ] Test upgrade and downgrade on disposable PostgreSQL, not only SQLite.

Required verification:

```powershell
Push-Location backend
alembic upgrade head
alembic current
alembic check
Pop-Location
```

Expected: one current head, no pending model changes, and every required table exists.

### Task 1.3: Remove schema mutation from application startup

**Files:**

- Modify: `backend/app/main.py:21-145`
- Test: `backend/tests/test_startup_migrations.py`

- [ ] Delete the `Base.metadata.create_all()` startup call.
- [ ] Delete the hand-written `ALTER TABLE` startup blocks.
- [ ] Keep startup limited to service initialization and fail clearly if required dependencies are unavailable.
- [ ] Add a test proving application startup does not create or alter tables.

### Task 1.4: Move seed and role correction out of startup

**Files:**

- Modify: `backend/app/main.py:91-145`
- Modify or create: `backend/seed_dev.py`, `backend/seed_assessment_data.py`
- Test: `backend/tests/test_startup_side_effects.py`

- [ ] Remove automatic role conversion and data seeding from application lifespan.
- [ ] Require an explicit development command for seed data.
- [ ] Make seed scripts refuse to run when `ENVIRONMENT=production`.
- [ ] Add tests proving normal startup does not mutate users, roles, or courses.

---

## Phase 2: Repair background workers and readiness

### Task 2.1: Fix the Celery entrypoint

**Files:**

- Modify: `docker-compose.yml:68,88`
- Read/verify: `backend/app/celery_app.py`
- Test: `backend/tests/test_celery_boot.py`

- [ ] Change both worker commands to reference the real `app.celery_app` module.
- [ ] Verify task registration includes grading, ingestion, question generation, CLO attainment, and analytics names.
- [ ] Add a boot test that imports the Celery app and asserts the expected task names are registered.

Run:

```powershell
Push-Location backend
python -c "from app.celery_app import celery_app; print(sorted(celery_app.tasks))"
Pop-Location
```

Then, with PostgreSQL and Redis available:

```powershell
docker compose up -d db redis
docker compose run --rm celery_worker_grading celery -A app.celery_app inspect ping
```

Expected: the worker imports successfully and responds to ping.

### Task 2.2: Replace the fake analytics task

**Files:**

- Modify: `backend/app/tasks/__init__.py:31-34`
- Modify: `backend/app/services/analytics_service.py`
- Modify: `backend/app/api/v1/analytics.py:121-138`
- Test: `backend/tests/test_analytics_task.py`

- [ ] Make the task call the same analytics service used by the API.
- [ ] Pass only serializable identifiers to Celery.
- [ ] Make the task return a real success/failure result.
- [ ] Keep the synchronous refresh endpoint only if it is explicitly needed for a user-facing refresh action.
- [ ] Test that the task changes snapshot/cache state transaction-safely.

### Task 2.3: Add liveness and readiness endpoints

**Files:**

- Modify: `backend/app/main.py`
- Modify: `railway.json`
- Test: `backend/tests/test_health.py`

- [ ] Keep `/health` as a cheap liveness check.
- [ ] Add `/ready` that performs a lightweight database query and verifies migration state.
- [ ] Do not make readiness depend on an optional cache if the application safely operates without cache.
- [ ] Point Railway health checking to readiness only when its failure semantics are correct.
- [ ] Add tests for healthy, database-unavailable, and migration-not-current states.

---

## Phase 3: Fix security and session correctness

### Task 3.1: Revoke sessions after administrator password reset

**Files:**

- Modify: `backend/app/services/user_service.py:160-166`
- Test: `backend/tests/test_token_revocation.py`

- [ ] Update `token_valid_after` whenever an administrator changes a password.
- [ ] Preserve the existing password policy and hashing algorithm.
- [ ] Test that an access token issued before reset is rejected after reset.

### Task 3.2: Bound token blacklist behavior

**Files:**

- Modify: `backend/app/services/cache_service.py:64-96`
- Test: `backend/tests/test_token_revocation.py`

- [ ] Do not keep expired JTIs forever in process memory.
- [ ] Store expiry timestamps in the fallback or remove the fallback for security-sensitive revocation.
- [ ] Ensure Redis failure does not make one worker silently disagree with another beyond the documented policy.
- [ ] Test expiry, Redis unavailable, and multi-process behavior as far as the environment permits.

### Task 3.3: Add distributed login throttling

**Files:**

- Modify: `backend/app/api/v1/auth.py:68-77`
- Modify: `backend/app/services/cache_service.py`
- Test: `backend/tests/test_auth_throttling.py`

- [ ] Add Redis-backed counters for IP, email, and combined identity.
- [ ] Use short windows with a clear response policy.
- [ ] Prevent account lockout from becoming an easy denial-of-service vector.
- [ ] Return generic authentication errors without revealing whether an email exists.
- [ ] Test repeated failures, successful login reset, and Redis-unavailable fallback.

### Task 3.4: Remove access tokens from download URLs

**Files:**

- Modify: `backend/app/core/dependencies.py:21-28`
- Modify: download endpoints in `backend/app/api/v1/assignments.py`, `backend/app/api/v1/submissions.py`, and `backend/app/api/v1/analytics.py`
- Modify: `frontend/lib/features/courses/presentation/assignment_detail_screen.dart`
- Modify: `frontend/lib/features/analytics/presentation/analytics_dashboard_screen.dart`
- Test: `backend/tests/test_download_auth.py`
- Test: `frontend/test/download_auth_test.dart`

- [ ] Use Authorization-header requests through Dio for downloads.
- [ ] If external-browser downloads are unavoidable, issue a short-lived one-use download token instead of a normal access token.
- [ ] Remove new frontend construction of `?token=` URLs.
- [ ] Test expired tokens, missing authorization, and authorized downloads.

---

## Phase 4: Fix assessment integrity and domain failures

### Task 4.1: Fix the default CLO path

**Files:**

- Modify: `backend/app/services/assignment_service.py:57-80,247-267`
- Test: `backend/tests/test_assignment_access.py` or a new assignment service test

- [ ] Construct `CLO` using only fields defined by `backend/app/models/course.py`.
- [ ] Preserve existing code/description behavior.
- [ ] Add a test for assignment creation in a course with no CLOs.
- [ ] Add a test for publishing an assignment in a course with no CLOs.

### Task 4.2: Enforce valid timing and attempt values

**Files:**

- Modify: `backend/app/schemas/assignment.py:18,33`
- Modify: assignment migration/model constraints
- Test: `backend/tests/test_assignment_validation.py`

- [ ] Reject negative time limits.
- [ ] Reject zero or negative maximum attempts.
- [ ] Define null time limit as untimed.
- [ ] Use the same constraints in API and database validation.

### Task 4.3: Prevent concurrent duplicate exam attempts

**Files:**

- Modify: `backend/app/api/v1/exams.py:61-121`
- Modify: `backend/app/models/exam_attempt.py`
- Modify: relevant Alembic revision
- Test: `backend/tests/test_exam_attempt.py`

- [ ] Write a concurrent start test first using two transactions for the same student and assignment.
- [ ] Add a database-backed uniqueness or locking strategy that protects the no-existing-row case.
- [ ] Preserve resume behavior for an existing active attempt.
- [ ] Test maximum-attempt enforcement after concurrent requests.

### Task 4.4: Unify the two exam experiences

**Files:**

- Modify: `frontend/lib/features/courses/presentation/quiz_attempt_screen.dart`
- Reuse: `frontend/lib/features/courses/presentation/exam_screen.dart`
- Reuse: `frontend/lib/features/courses/utils/exam_submission.dart`
- Test: `frontend/test/exam_route_test.dart`

- [ ] Identify every route that reaches `quiz_attempt_screen.dart`.
- [ ] Route equivalent timed assessments through the hardened exam flow where possible.
- [ ] If the legacy screen remains, reuse the same fullscreen, warning, submit, and expiry helpers.
- [ ] Replace the raw emoji alert with the existing accessible icon/text pattern.
- [ ] Test focus loss, warning dismissal, resume, expiry, and submit behavior.

---

## Phase 5: Fix analytics and import performance

### Task 5.1: Make analytics refresh transactional and cache empty results

**Files:**

- Modify: `backend/app/services/analytics_service.py:37`
- Modify: `backend/app/api/v1/analytics.py:39-42`
- Test: `backend/tests/test_analytics_access.py`

- [ ] Replace delete-then-insert with an upsert or transaction that cannot leave an empty state.
- [ ] Treat a cached zero-student response as a valid cache hit.
- [ ] Preserve error visibility for cohort-trend failures; log course ID and request ID.
- [ ] Test empty courses, repeated refreshes, and concurrent refreshes.

### Task 5.2: Batch CSV enrollment

**Files:**

- Modify: `backend/app/services/course_service.py:177-205`
- Test: `backend/tests/test_enrollment_role_validation.py`

- [ ] Parse and validate rows first.
- [ ] Load all referenced users in one query.
- [ ] Load existing enrollments for the course in one query.
- [ ] Insert only missing valid enrollments.
- [ ] Preserve duplicate-row and role-validation behavior.
- [ ] Add a fixture with at least 100 rows and assert bounded query behavior.

---

## Phase 6: Make release artifacts deterministic

### Task 6.1: Choose one frontend delivery path

**Files:**

- Modify: `backend/app/main.py:18,210-258` only if the chosen path changes
- Modify: `Dockerfile`
- Modify: `.gitignore`
- Modify: release documentation in `README.md`

- [ ] Declare `backend/static` as the only served generated Flutter web directory, or change the server and use the other directory; do not keep both as competing outputs.
- [ ] Remove or archive the unused duplicate tree after verifying it is not user-owned.
- [ ] Add a reproducible build command from `frontend/` to the selected output directory.
- [ ] Record Flutter version, build number, commit SHA, and build timestamp in release metadata.
- [ ] Verify the served `main.dart.js` hash matches the build output.

### Task 6.2: Decide the React surface

**Files:**

- Read: `frontend/react_pages/*`
- Read: `backend/static/react/*`
- Modify: `README.md`

- [ ] If React is deprecated, document it and stop treating its static output as supported.
- [ ] If React remains supported, replace CDN/dev scripts with a pinned production build and add a smoke test.
- [ ] Do not maintain both Flutter and React implementations without explicit ownership.

### Task 6.3: Verify the APK release package

**Files:**

- Read: `frontend/android/app/build.gradle*`
- Read: `frontend/android/app/src/main/AndroidManifest.xml`
- Modify: release scripts/config only if verification exposes a real issue

- [ ] Verify release/debug signing.
- [ ] Verify package name, version name, version code, API base URL, and network security configuration.
- [ ] Install the APK on a real Android device or emulator.
- [ ] Test login, course loading, submission, and logout.
- [ ] Do not call the APK production-ready until signed and smoke-tested.

---

## Phase 7: Align documents and evidence

### Task 7.1: Choose the authoritative project report

**Files:**

- `ProfessorOS_FYP_Report_30pct.docx`
- `ProfessorOS_FYP_Report_Formatted.docx`
- `Professor OS_SDS (1).pdf`
- `ProfessorOS_SRS.pdf`
- `ProfessorOS_Scope_Document (2).pdf`

- [ ] Choose one authoritative report version.
- [ ] Merge only claims supported by current source code and executed tests.
- [ ] Mark deferred features as deferred instead of claiming completion.
- [ ] Update the table of contents and list of tables after pagination.
- [ ] Fix PDF cover overlap, clipped headings, wrapped dates, and empty revision rows.
- [ ] Render the final DOCX/PDF and inspect every page.

### Task 7.2: Add a requirements-to-evidence matrix

**Files:**

- Create: `docs/requirements-evidence-matrix.md`

- [ ] For every implemented requirement, record source path, endpoint/screen, automated test, and manual verification status.
- [ ] For every deferred requirement, record “deferred” and the reason.
- [ ] Do not list CI/CD, deployment, or production testing as complete without executed evidence.

### Task 7.3: Add only the CI required for this milestone

**Files:**

- Create: `.github/workflows/quality.yml`
- Modify: `README.md`

- [ ] Run backend tests and compilation.
- [ ] Run Flutter tests and analyzer.
- [ ] Run diff checks.
- [ ] Keep deployment automation separate until a real environment and credentials are available.

---

## Phase 8: Final verification gate

- [ ] Run the complete backend test suite.
- [ ] Run the complete Flutter test suite.
- [ ] Run Flutter analyzer.
- [ ] Run Python compilation.
- [ ] Run Alembic upgrade/current/check on disposable PostgreSQL.
- [ ] Boot both Celery workers and verify task registration.
- [ ] Run Selenium smoke tests against the actual served Flutter build.
- [ ] Verify authorized and unauthorized downloads.
- [ ] Verify concurrent exam starts.
- [ ] Verify admin password reset revokes old tokens.
- [ ] Verify readiness fails when the database is unavailable.
- [ ] Render final documents and inspect every page.
- [ ] Verify APK installation and core mobile flows.
- [ ] Run `git diff --check`.
- [ ] Review the final diff for generated artifacts, secrets, and unrelated changes.

Release only if database migration, worker boot, authentication, exam concurrency, download security, and artifact verification all pass.

## What we do not need to do now

1. Do not rewrite the whole backend architecture.
2. Do not replace FastAPI, SQLAlchemy, PostgreSQL, Redis, Celery, or Flutter.
3. Do not build a new design system; reuse the existing components.
4. Do not add speculative microservices.
5. Do not add new AI models or retraining pipelines.
6. Do not complete deferred AI grading/XAI roadmap work in this remediation phase.
7. Do not implement a full Judge0/code-execution platform in this pass.
8. Do not add advanced RAG/vector-search infrastructure beyond making existing workers boot.
9. Do not redesign the entire proctoring product; unify and harden the existing flows first.
10. Do not add real-time notifications, mobile push infrastructure, or replace the email provider.
11. Do not perform a full penetration test or formal load test inside the code-fix phase; schedule them separately.
12. Do not manually edit generated Flutter JavaScript or WASM.
13. Do not keep both static trees synchronized by copying them manually; generate one authoritative build.
14. Do not maintain the legacy React interface as a second product unless explicitly approved.
15. Do not rewrite academic documents to claim features that are not implemented and tested.
16. Do not modify unrelated dossier HTML/PDF changes already present in the working tree.
17. Do not optimize code paths before migration, worker, security, and correctness gates pass.

## Recommended execution order

1. Phase 0: baseline and worktree safety.
2. Phase 1: migrations and startup safety.
3. Phase 2: Celery and readiness.
4. Phase 3: authentication and download security.
5. Phase 4: assignment and exam integrity.
6. Phase 5: analytics and import performance.
7. Phase 6: release artifacts.
8. Phase 7: documents and CI evidence.
9. Phase 8: final verification.

This plan is intentionally a remediation plan for the current implemented foundation, not a new-feature roadmap.
