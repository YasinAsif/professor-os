# ProfessorOS SRS & Scope Requirement Gap Analysis

This document evaluates the functional requirements from the project specification documents against the live codebase, test suite, and FYP delivery scope.

---

| Requirement / Module | In Code? | Tested? | Live Architecture Status / Gap | FYP-Critical? |
| :--- | :--- | :--- | :--- | :--- |
| **User Authentication & RBAC** | Yes | Yes (Automated HTTP) | Argon2 password hashing, JWT bearer tokens (60m access expiry, 7d refresh), role separation (admin, professor, student, TA). | **Yes (Delivered)** |
| **Course Management & Join Codes** | Yes | Yes (Automated HTTP) | 8-character secure alphanumeric join codes with regeneration, rate limiting, and enrollment roster CSV import. | **Yes (Delivered)** |
| **Proctored Timed Examination Engine** | Yes | Yes (Automated HTTP & Widget) | Server-authoritative timer, `focus_loss` violation grouping, client debounce (1.5s), heartbeat recovery, and server-side auto-submission. | **Yes (Delivered)** |
| **Deterministic MCQ Auto-Grading** | Yes | Yes (Automated Unit & Service) | Deterministic answer-key comparison bypassing LLM tokens; text fallback routing to manual review (`needs_review`). | **Yes (Delivered)** |
| **Course Staff & TA Delegated Permissions** | Yes | Yes (Automated HTTP) | `verify_course_staff_access` enforcing course-level TA enrollment and assignment grading delegation. | **Yes (Delivered)** |
| **OBE & CLO Attainment Calculations** | Yes | Yes (Automated Unit) | Single CLO source of truth (`clos`), HEC weight tolerances, exclusion of invalidated attempts, missing attempts documented in `docs/OBE_NOTES.md`. | **Yes (Delivered)** |
| **Course Document Q&A / Syllabus RAG** | Yes | Yes (Automated Service) | Keyword retrieval default (`HashingVectorizer`); prompt injection detection; dense neural embeddings optional via `ENABLE_PYTORCH_EMBEDDINGS`. | **Yes (Delivered)** |
| **Background Exam Monitoring Supervisor** | Yes | Yes (Automated Async) | Periodic supervisor loop with batch limits (100 attempts), state telemetry on `/health/monitor`, and auto-restart on cycle exceptions. | **Yes (Delivered)** |
| **Automated Code Sandbox Execution (Judge0)** | Partial / Gap | No | `settings.py` includes configuration properties, but execution container is not deployed in default compose stack; code submissions evaluated via static analysis / manual review. | No (Deferred to post-FYP production) |
| **Live Audio/Video Webcam Proctoring** | No | No | Out of scope for web architecture; upfront biometric authentication (`local_auth`) and focus tracking deployed instead. | No (Documented in `docs/KNOWN_LIMITS.md`) |
| **WebSocket Real-Time Broadcast Notifications** | No | No | Push notifications and live WebSocket channels not deployed; state synchronization uses 10–15s heartbeat polling. | No (Non-critical for assessment integrity) |
| **Automated Nightly Database Snapshots** | Yes | Yes (Scripted) | PowerShell (`backend/scripts/backup.ps1`) and Bash (`backend/scripts/backup.sh`) scripts using `pg_dump` with documented restore verification. | **Yes (Delivered)** |
