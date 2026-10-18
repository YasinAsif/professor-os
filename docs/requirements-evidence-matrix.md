# ProfessorOS Requirements Evidence Matrix

This matrix records only evidence that exists in the current repository. A requirement is not marked complete merely because it appears in an SDS, SRS, or report.

| Area | Current evidence | Automated verification | Status |
|---|---|---|---|
| Authentication and sessions | `backend/app/api/v1/auth.py`, `backend/app/services/auth_service.py` | `backend/tests/test_token_revocation.py`, backend suite | Implemented foundation |
| Role and approval controls | `backend/app/core/dependencies.py`, `backend/app/services/user_service.py` | approval/access tests | Implemented foundation |
| Course and roster management | `backend/app/services/course_service.py` | enrollment/course tests | Implemented foundation |
| Assignment and rubric management | `backend/app/services/assignment_service.py`, `backend/app/models/rubric.py` | assignment tests | Implemented foundation |
| Timed exams | `backend/app/api/v1/exams.py`, `frontend/lib/features/courses/presentation/exam_screen.dart` | exam and Flutter exam utility tests | Implemented with remaining browser/device verification |
| Submission and grading queue | `backend/app/services/submission_service.py`, `backend/app/tasks` | submission and pipeline tests | Implemented foundation |
| Analytics | `backend/app/services/analytics_service.py`, `backend/app/api/v1/analytics.py` | analytics tests | Implemented foundation |
| OBE/CLO question bank | `backend/app/api/v1/quizzes.py`, `backend/app/models/quiz_obe.py` | pipeline tests and migration checks | Implemented foundation |
| Celery deployment | `docker-compose.yml`, `backend/app/celery_app.py` | task registration test | Requires Docker worker smoke test |
| Production database schema | `backend/alembic/versions` | `alembic upgrade`, `alembic check` | Verified against local PostgreSQL |
| AI grading/XAI completeness | Existing service code and report scope | No complete quality evaluation | Deferred |
| Judge0/code execution | No verified production workflow | No end-to-end evidence | Deferred |
| Formal load/performance testing | No benchmark report | No load test evidence | Deferred |
| Production deployment/rollback | Railway configuration only | No live deployment evidence | Deferred |
| Final document submission package | PDFs/DOCX exist but require visual cleanup | DOCX renderer unavailable in current environment | Pending manual document QA |
