# ProfessorOS Live Acceptance Audit Plan

Status: prepared; production-changing steps require explicit confirmation before execution.

## Test identities

- Professor: supplied professor account
- Student: supplied student account
- Environment: Railway production deployment supplied by the user

Credentials are intentionally not recorded in this document.

## Assignment matrix

For each type, test professor creation, draft save, editing, rubric/CLO linking, publishing, student visibility, submission, grading, feedback, resubmission policy, analytics, and export:

- Text essay / Q&A
- File upload
- MCQ quiz
- Programming
- Hybrid / mixed
- Timed exam / proctored exam
- AI/OBE-generated quiz

## AI service matrix

- Course AI chat with material-grounded question
- Course AI chat with no-material fallback
- Material ingestion and indexing state
- AI question generation
- Bloom filtering and validation
- Question approval/rejection/editing
- Quiz publish gate
- AI single-submission grading
- AI batch grading
- Prompt-injection and malformed-submission handling
- CLO attainment and HEC dossier generation

## Student checks

- Login and dashboard landing
- Course discovery/join flow
- Assignment clarity and expected-output guidance
- Deadline/time-limit visibility
- Draft/submit/resubmit behavior
- File size/type errors
- Timed exam entry, fullscreen warning, focus-loss warning, resume, expiry, and auto-submit
- Result visibility and feedback comprehension
- Mobile and keyboard usability

## Professor checks

- Course creation and HEC weight validation
- Roster enrollment and CSV import
- CLO management
- Assignment authoring and publishing
- Rubric creation and validation
- Submission triage and grading
- Proctor console
- Analytics, at-risk students, CSV/PDF exports
- OBE/CLO attainment and AI assessment tooling

## HEC evidence baseline

The audit will compare observed behavior and generated artifacts against the official HEC sources below. This is an evidence comparison, not a legal/accreditation certification.

- HEC Undergraduate Education Policy 2020: competency-based learning and graduate competencies.
- HEC Undergraduate Education Policy implementation guidance.
- HEC policy guidelines for the uniform semester system and examination system.
- HEC Quality Assurance / programme-level outcome and continuous-improvement guidance.

## Evidence to save

- Timestamped screenshots for each major state and failure.
- A Markdown findings report with severity, reproduction path, expected behavior, observed behavior, student/professor impact, and recommended fix.
- A HEC traceability table linking product behavior to official source sections.
- A final test ledger showing passed, failed, blocked, and not safely executed cases.

## Safety boundary

No production record will be created, published, uploaded, graded, or submitted until the user confirms the live-test actions immediately before execution. Destructive actions such as deleting courses, assignments, submissions, or files are excluded unless separately authorized.
