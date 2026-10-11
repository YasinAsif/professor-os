# ProfessorOS - Context & State

## Project Identity
- **Stack**: FastAPI + PostgreSQL + SQLAlchemy + Celery + Redis | Flutter Web/Mobile (Dart/Dio/Riverpod)
- **Primary Mission**: Multi-role Academic Assessment and Course Management System (Admin, Professor, TA, Student).
- **Ground Truth**: Live code in `backend/` and `frontend/` is the single source of truth.
- **Out of Scope**: Cross-submission plagiarism / similarity detection is strictly out of scope.

## Core Directives
1. **Rule 1 (Single Source of Truth):** Live code in `backend/` and `frontend/` is ground truth.
2. **Rule 2 (Out of Scope):** Cross-submission plagiarism/similarity is strictly out of scope.
3. **Rule 3 (Ponytail Execution Law):** Every wave follows `/ponytail full` — read existing callers/callees first, reuse existing repo widgets/services, never cut trust-boundary security/validation/accessibility, and leave an executed test behind for every branch.

## Current State & Gates Baseline
- **Backend**: FastAPI with async SQLAlchemy, auth dependency checks, Pydantic v2 schemas.
  - Test suite: `pytest` in `backend/` (Target: >= 48 passed, 0 failed, 0 warnings).
- **Frontend**: Flutter Web/Mobile, clean architecture with Riverpod providers.
  - Lints: `flutter analyze --no-pub` (Target: 0 issues).
  - Tests: `flutter test --no-pub --concurrency=1` in `frontend/` (Target: >= 21 passed, 0 failed).
- **End-to-End**: Flutter Web static build synced to `backend/app/static/`, tested via Selenium suite (`selenium_tests/`).
