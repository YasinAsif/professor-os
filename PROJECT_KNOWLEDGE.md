# Project Knowledge

## What this is
ProfessorOS: AI-first academic operating system for universities. Features proctored timed examination, rubric-anchored AI grading pipeline, OBE/HEC compliance, and analytics.

## Stack and how to run
- Language / framework: Python 3.14 (FastAPI, SQLAlchemy, Celery), Dart / Flutter 3.24.3 (Web & Native)
- Install:
  - Backend: `pip install -r backend/requirements.txt -r backend/requirements-dev.txt`
  - Frontend: `cd frontend && flutter pub get`
- Run dev:
  - Backend: `uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload`
  - Frontend: `flutter run -d chrome --web-port 3000`
- Run tests:
  - Backend: `cmd /c "set PYTHONPATH=backend&& python -m pytest backend/tests"`
  - Frontend: `cd frontend && flutter test`
- Build:
  - Frontend web: `cd frontend && flutter build web --release`
- Deploy target: Docker / Linux VM / VPS with PostgreSQL, Redis, Celery, and static web host.

## Goals and acceptance criteria
See `docs/plan.md`. Top criteria:
1. Fix student exam screen to properly render multi-question prompts and MCQs.
2. Render distinct individual submission text boxes for each question in a multi-question midterm/final exam.
3. Patch the AI grading pipeline to prevent Pydantic validation crashes and handle model aliases/tolerance.
4. Hide Rubric Builder step when creating MCQs; allow MCQ publishing without manual rubric configuration.
5. Reorder category selection UI to: 1. Internal Assessment, 2. Midterm, 3. Final Exam.
6. Lock academic semester dropdown to Fall 2026 and Spring 2027.
7. Enable browser autocomplete on the login email input.

## Decisions
- [2026-11-03] Decision: Retain MCQ database schema and models, but hide the Rubric Builder in the wizard for MCQs and allow publishing without a rubric. Reason: Preserves existing test contracts and historical data while eliminating unnecessary friction for professors.
- [2026-11-03] Decision: Store multi-question exam answers in serialized structured text format with clear per-question demarcations. Reason: Completely compatible with existing backend `unpack_draft_answers`, SpeedGrader display, and LLM evaluation prompts.

## Gotchas
- Pydantic models in `grading_pipeline.py` strictly validate `criteria_evaluations` and sum of criteria vs `total_score`; LLMs occasionally return `criterion_evaluations` or slightly rounded floats.
- Flutter Web autocomplete requires `AutofillGroup` and `autofillHints` on `TextFormField`.
- `ExamScreen` previously checked only `widget.description` which was null on direct navigation or page refresh, rather than `_effectiveDescription`.

## Current status
- Stage: Verify / Complete
- Done:
  - Slice 1: AI Engine Patch (Pydantic validation aliasing, provider shape normalizer, LLM test verified).
  - Slice 2: Exam Rendering & Multi-Question Text Boxes (Structured question parser, individual text areas for each question, widget test verified).
  - Slice 3: Assessment Sorting & Rubric Hiding on MCQs (Wizard category order: Internal -> Midterm -> Final; rubric skipped on MCQ creation and publishing).
  - Slice 4: Semester Dropdown Lockdown & Login Autofill (Dropdown locked strictly to Fall 2026 & Spring 2027; browser autocomplete hints added with AutofillGroup).
  - Slice 6: Backend Exam Start & MCQ Deterministic Grading (description returned immediately on exam start; regex & markdown parser for MCQ plaintext fallback).
  - Slice 7: Student Exam Screen Live Sync (description adopted immediately upon starting without F5; 409 Conflict handled gracefully on terminated attempts).
  - Slice 8: SpeedGrader Rubric Scaling & Multi-Question Viewer (scaled to max_marks e.g. 20; structured cards render multi-question text cleanly).
  - Slice 9: Student Dashboard & Dispute Indicators (onTap navigation enabled on Action Queue and Recent Feedback; pending dispute badges shown to professors).
  - Full test suite verified: 149 backend tests pass, 82 frontend tests pass.
  - Production build synchronized: Flutter web release compiled and deployed to backend/static/.
- In progress: Ready for user demo.
- Blocked / needs human: None.

## Releases
- 2026-11-03: Demo blocker and full student & professor hardening patch verified and passing all 149 backend tests, 82 Flutter tests, and web release build.

## Observations
- [2026-11-03] Backend test suite: 149 passed, 3 deselected in 20.96s.
- [2026-11-03] Frontend test suite: 79 passed in 38s.
