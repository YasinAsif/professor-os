<USER_REQUEST>
CHWCK OU TTHESE TINGS IN MY PROMPT AND THEN IMPLEMENT IF IT CAN BE AND ARE CORRECTLY SAID:
You are fixing ProfessorOS (backend/ FastAPI, frontend/ Flutter web). A read-only audit found the issues
below. Work in phases. Do not skip ahead.

RULES
1. TEST FIRST. For each item, write a test that FAILS on current code, show it failing, then fix, then show it passing.
   Use real HTTP tests (httpx AsyncClient against the app, real auth dependencies) for permission and API bugs,
   not direct function calls.
2. Server is the source of truth. Client never decides time, strikes, auto_submitted, or settings.
3. No swallowed errors. Log them. Show the user a clear message.
4. Re-read the code before each fix. If an item is already fixed or described wrongly, say so and skip it.
5. One git commit per phase. Message lists the item ids. Do NOT touch main.dart.js / static builds until the end.
6. Report per item: id | status (fixed / partly / not fixed / was fine) | files | test name | real command output.
   Mark anything needing a real browser as NOT RUN. Never write "100%", "fully", "robust".
7. Decide ambiguous things yourself and list the decisions at the end. Do not stop to ask.
8. Run the full backend and frontend suites at the end of every phase and paste the real tail output.
   Also run flutter analyze.

DECISIONS ALREADY MADE (follow them)
- TA model: a TA is an Enrollment with role="ta" for that course. Authorization uses enrollment role per course,
  never users.role alone. Add one helper: verify_course_staff_access(course_id, user, allow_ta: bool, assignment_id=None).
  Professor owner and admin always pass. TA passes only if enrolled as ta in THAT course, and for grading only if
  delegated in assignment_tas for that assignment.
- Retake/submission model: add submissions.attempt_id (nullable FK to exam_attempts, indexed). One submission per
  exam attempt. Non-exam assignments keep one row per student.
- Retake allowance: new column exam_attempts.retake_granted (bool, default false), separate from decision.
  allowed_attempts = max_attempts + count(retake_granted).
- Strike rule: tab_switch and window_blur belong to ONE group "focus_loss", deduped together.
  copy_paste and multi_monitor are logged as events but do NOT add strikes by default.
  heartbeat_missed is server-only.
- MCQ: an mcq assignment cannot be published without parsed options.

====================================================
PHASE 0: SAFETY (do first)
====================================================
0.1 Confirm backend/.env, backend/backups/, *.sql dumps are gitignored. Delete backend/inspect_routes.py or any scratch
    files still in the repo. List committed large/generated files (APK 26MB, duplicate static folders, report .docx,
    PDFs). Do NOT delete them; write docs/REPO_CLEANUP.md with a proposal (move APK to releases, keep one static dir).
0.2 conftest.py: force DATABASE_URL to a temp SQLite (or a dedicated test DB) BEFORE app imports, and make the exam
    monitor daemon NOT start under tests. Prove with a test that no test touches the dev DB. Find tests that import
    async_session unpatched (test_course_chat) and fix them.
0.3 Production settings validation: refuse startup in production if DATABASE_URL uses default password
    (postgres:postgres), DEBUG=True, INITIAL_ADMIN_PASSWORD empty-or-weak, or JWT key default.
0.4 Lower ACCESS_TOKEN_EXPIRE_MINUTES default to 60. Frontend must refresh transparently. Test it.

====================================================
PHASE 1: DATA LOSS AND EXAM CORRECTNESS (highest priority)
====================================================
1.1 [MCQ text answer dropped] exam_screen.dart: for type mcq with no parsed options, the UI shows a text box bound to
    _textCtrl but _getCurrentAnswersDraft and _submitExam read only _mcqAnswers. Fix:
    - Replace raw draft strings with a tagged envelope: {"v":1,"kind":"mcq|text|code|file","data":...}.
      Keep a compatibility reader for old drafts (raw text, raw JSON map {"0":1}). Treat a raw string as text when
      the assignment has no options. Test old formats restore correctly, including a student who types "{}".
    - Heartbeat, restore, submit, and auto-close must all use the same serializer. If options exist send choices;
      if not, send the typed text with submission_type "text" semantics.
    - Never send "[No answers selected]" if any input (text, code, choices) exists.
    - Backend auto_close_attempt builds the Submission from ANY of the draft formats (mcq, text, code, file). Test all.
    - Widget test: mcq with no options, type text, submit -> payload contains the text. Backend test: heartbeat saves
      the text; auto-close submits it.
    - Add SQL (read-only) docs/AFFECTED_STUDENTS.sql: submissions with "[No answers selected]" on mcq assignments.
1.2 [mcq without options] Block publishing an mcq/quiz assignment that has no parsed options (clear 422 message).
    Old published ones keep the text fallback; log when it triggers.
1.3 [F5 breaks exam screen] ExamScreen must not depend on router extras. After load (including F5 and deep link),
    fetch the assignment config from the server: type, description, time limit, fullscreen_required, block_copy_paste,
    unsupported_browser_policy, strike limits. If an attempt is active, resume straight into the exam view (not the
    instructions screen) with the correct input widget, timer, and restored draft. Test with extra == null.
1.4 [Proctor settings never reach students] Return these settings from start_exam and exam/state, and use them in
    ExamScreen. Remove hardcoded 3/5 and fullscreen/copy-paste/browser defaults in the client. Client strike display
    and flagged state come from the server only. Widget tests: policy=block, fullscreen_required=false,
    block_copy_paste=false behave differently.
1.5 [Alt-tab double strike] Server: dedupe by GROUP (focus_loss = tab_switch + window_blur) within 1.5s, in
    record_violation, under the attempt row lock. Client ProctorDetector: same grouping. Tests: blur then
    visibility 30ms apart = 1 strike, both client and server; real HTTP test.
    Also: copy_paste and multi_monitor store an event but no strike. Reject client-sent heartbeat_missed (422).
1.6 [Offline queue loses strikes] Drain safely: peek/send one at a time and remove only after success; on failure
    stop and keep ALL remaining items in order. Send the original client timestamp as client_occurred_at; server
    stores it in a new column (keep server received_at too) and uses received_at for dedupe/ordering rules.
    Cap clock skew (ignore client time if >5 min from server). Tests: 4 queued, fail on #2, all remaining kept.
1.7 [Failed submit freezes exam] Submit becomes ONE atomic server call POST .../exam/submit with the answers in the
    body; it saves the submission (with attempt_id) and closes the attempt in one transaction. Idempotent. On failure
    the client keeps timers and heartbeat running and lets the student retry. Test: failure then retry works.
1.8 [Client timer] Use server remaining_seconds from every heartbeat to resync. Auto-submit at 0 (not 1). Server is
    final authority on time.
1.9 [Never-heartbeat blind spot] start_exam sets last_heartbeat_at = started_at. Monitor flags attempts with no
    heartbeat for the timeout. Do NOT overwrite an existing flag_reason; append offline info in a separate field or
    event. When heartbeat returns, clear an offline-only flag but keep the event. Tests for each.
1.10 [start_exam deadline] start_exam must reject after assignment.deadline unless allow_late. Also reject if
    remaining attempt time would exceed the deadline unless allow_late (or cap the attempt end at the deadline).
    Make submit() accept auto_submitted closes, and exam submits within the attempt window even if deadline passed
    mid-attempt per the cap rule. Test all three.
1.11 [Retake / overwrite] Implement submissions.attempt_id (migration + backfill: link existing exam submissions to
     the latest attempt by assignment_id+student_id). New attempt creates a NEW submission row; never overwrite a
     graded or pending submission of an earlier attempt. Grading, gradebook, analytics use the "counted" attempt
     (default: latest non-invalidated; document it). Test: attempt 1 graded, retake, attempt 2 submits OK.
1.12 [Retake allowance] Implement exam_attempts.retake_granted. Clear Flags / Accept must not erase it. Test: allow
     retake then clear flags then retake still works; student A retake does not affect student B.
1.13 [Resubmit rule] Backend: reject any second submission on a timed/proctored assignment unless a retake is granted
     and a new attempt exists. Frontend: hide "Resubmit" for exams.
1.14 [Proctored definition] ONE shared definition used by backend and frontend: proctored = time_limit_minutes > 0
     OR type in (mcq, quiz) with fullscreen_required. Put it in one backend helper and return is_proctored in the
     assignment response; frontend uses that field only. Fix the mcq-with-no-time-limit mismatch (backend must
     require an attempt, or the frontend must not show Exam Mode; pick one and test).
1.15 [Pre-Start question exposure] For proctored assignments, GET assignment must NOT return description/questions
     to students until they have an active attempt. Return it from start_exam/exam/state only. Instructors still see
     it. Test: student GET before start has no questions; after start has them.
1.16 [Proctored quiz builder] The OBE quiz attempt flow (student_quiz_attempts) has no proctoring and
     never sends its tab-switch count. Decide: wire it to the same violations/heartbeat model, or document it as
     unproctored and hide the proctored claims. Pick wiring if low effort; otherwise write docs/ONE_PAGE_LIMITS.md.
1.17 [Exam answers caps] Max length on HeartbeatRequest.answers and SubmissionCreate.content (e.g. 200 KB);
     return 413/422. Test.
1.18 [Biometric] Either send "biometric_unverified" to the server (new column on exam_attempts, shown in the
     professor console) or remove the dialog's claim. Do the former. Web fallback stays "skip", but record
     biometric_status = skipped|passed|bypassed.
1.19 [Fullscreen overlay trap] If fullscreen is refused on Return to Exam, show a message and send a violation; keep
     the Submit button available but still gated behind the overlay's explicit "Submit now" confirm. Test the widget.

====================================================
PHASE 2: PERMISSIONS AND PRIVACY
====================================================
2.1 [Staff read any attempt] GET /attempts/{id}/state and GET /attempts/{id}/result: professors/TAs must pass a
    course check for THAT attempt's course. Students only their own. Real HTTP tests: professor of other course 403,
    TA of other course 403, student of another student's attempt 403. Delete dead GET /attempts/{id}/state if the
    frontend never calls it.
2.2 [Id-only routes] Audit EVERY route that takes only an id (submission sid, quiz_id, question_id, attempt_id,
    material_id). Produce docs/PERMISSION_MATRIX.md: route | check used | course-scoped? Fix each unscoped one.
    Specifically verify and fix PUT /submissions/{sid}/grade and /ai-grade: paste verify_assignment_access and
    SubmissionService.grade_submission. If any TA/professor can grade another course's submission, fix it and add
    403 tests (other-course professor, TA not delegated to that assignment, student).
2.3 [TA model] Implement verify_course_staff_access (see decisions). Apply: TA may list exam attempts and view the
    timeline for delegated assignments, may grade delegated assignments. TA may NOT create/edit/publish
    assignments, change settings, record decisions, enroll users, or delete materials. Remove "ta" from decorators
    that the service denies, or make them truly work. Dashboard must show TA courses (enrollment.role=ta). Tests for
    each endpoint x role (student, ta-same-course, ta-other-course, prof-owner, prof-other, admin).
2.4 [Lock bypass] PUT /assignments/{aid} must reject changes to time_limit_minutes and max_attempts once any attempt
    exists (409). Also change /exam/settings lock to: locked while any attempt is ACTIVE or any submitted attempt
    exists unless the professor creates a new version (keep simple: lock once any attempt exists, but allow editing
    title/description typos via a separate non-structural path with an audit log entry).
2.5 [Audit trail integrity] exam_audit_logs, exam_violations, exam_attempts must not be deletable by deleting a
    course/assignment/user in one call. Change FKs to RESTRICT or SET NULL as appropriate, and replace permanent
    delete with: admin-only, requires confirmation text, writes an audit row, and archives audit tables to a
    separate retained table first. DELETE /assignments/{aid} too (block if attempts exist; archive instead).
    Also fix professor deletion (courses.professor_id is RESTRICT): return a clear 409, not a 500. Tests.
2.6 [Invalidate must do something] invalidate: set the linked submission status to invalidated (add enum value or
    flag), score = 0 or excluded (document choice: excluded from gradebook and analytics, visible to instructor),
    skip AI grading, exclude from CLO attainment. Accept/clear keep grading flow. Tests on gradebook and analytics.
2.7 [Clear Flags baseline] Keep tab_switch_count, but add reviewed_strike_baseline = count at review. Auto-submit and
    flag thresholds use (count - baseline). Show both on the console. Test: cleared at 4 strikes, next strike does
    not auto-submit.
2.8 [Decision endpoint TAs] See 2.3 (TAs cannot decide). Record decided_by/at; keep audit rows; sanitize reason
    text on output (plain text only) without altering stored reason.
2.9 [Auth] Password reset token single use: store a reset_nonce/hash on the user or a used-token table; reject
    reuse; also compare iat with token_valid_after. CSV user import: reject role=admin (admin creation only via the
    single-user admin form) and write an audit row for every imported professor/TA. Add per-IP and per-account rate
    limit to POST /courses/join; add "regenerate join code" for professors; make join codes 8 chars.
2.10 [Biometric login] Stop storing the plaintext password. Store a refresh token (or require password re-entry) and
    clear it on logout. Remove biometric_password/biometric_email keys and migrate by deleting them.
2.11 [CSP] Add a Content-Security-Policy header that works with the Flutter web build (test in a browser).
     Keep Permissions-Policy but note camera is blocked in docs.
2.12 [CSV injection] Escape cells starting with = + - @ tab or CR in every CSV writer (exam export, gradebook, user
     export, assignment export). Test.
2.13 [Remove dead/duplicate routes] Remove /switch-tab, /exam/flag, /status alias, legacy /exam/heartbeat,
     GET /exam/settings if the frontend never calls them (verify with grep). Keep route list in docs.
2.14 [Questions via description in chat/RAG] Check courses chat calls detect_prompt_injection on the message
     and on retrieved chunks; add if missing. Add a per-user rate limit and daily cap on /chat and ai-grade-all.

====================================================
PHASE 3: GRADING, CONTENT, AND REPORT HONESTY
====================================================
3.1 [MCQ grading] Add deterministic MCQ grading for assignment type mcq: store the answer key (structured options
    with correct flag) at creation; auto-score by comparing choices; never send mcq choices to the LLM. Text
    fallback submissions go to manual review (needs_review). Test.
3.2 [Placeholder triage] Verify build_document_triage matches the real placeholders: "// [Time Expired - Auto-
    Submitted by System ...]" and the client placeholders. Normalize ONE placeholder constant used by backend and
    frontend. Test that placeholders never reach the LLM.
3.3 [Late penalties] Either implement late_penalty_per_day and max_penalty_cap in grading, or remove the fields from
    the UI and schemas. Same for randomize_questions and show_results_after (implement or remove). Pick implement
    for late penalty and show_results_after; remove or hide the others. Tests.
3.4 [ai-grade-all] Run as a background task with progress and a per-course cap; no long request. Add timeouts and a
    clear failure state on the submission (grading_failed, retry button). Test LLM down -> submission goes to manual
    review, nothing is lost.
3.5 [RAG honesty] Remove the hardcoded canned answers in courses.py chat. If the LLM fails or no material, return
    a clear "can't answer right now / no material indexed". Document that default embeddings are HashingVectorizer
    (keyword-like) unless ENABLE_PYTORCH_EMBEDDINGS=true; list that env var in the env table and decide the
    deployed default. If the PyTorch path is too heavy, rename the feature "keyword retrieval" in docs.
    Fix the chat model name in settings to a real model and make it configurable.
3.6 [Ingestion] Content-type sniffing in addition to extension; do not run heavy parsing in the web process when
    Celery is down — return 503 "indexing queue unavailable" or queue to a DB-backed table. Delete orphan files
    (uploads, FAISS index) when a course or material is deleted. Test.
3.7 [Uploads] Block .html .svg .js .php and similar on submission and material uploads; ensure downloads send
    Content-Disposition: attachment and X-Content-Type-Options: nosniff.
3.8 [Course weights] Fix float compare in HEC weight check (use tolerance). Reconcile the default weights (model
    vs docs) and use one set. Fix join_code column mismatch if any (alembic check must stay clean).
3.9 [Dashboards] Student dashboard hides archived courses; shows TA courses for TAs. Roster CSV and direct enroll
    reject unapproved/inactive users and wrong roles. Tests.
3.10 [OBE] Answer in docs/OBE_NOTES.md: do missing attempts count as zero or get excluded in attainment? Make
    attainment read ONE CLO source (clos or clo_definitions), connect assignment_clos to attainment, remove the C3
    fallback guess, and show "no data" instead of fake attainment. Exclude invalidated submissions. Tests with
    missing attempts. Fix at_risk table naming in docs.

====================================================
PHASE 4: BACKGROUND JOBS, DB, DEPLOY
====================================================
4.1 [Monitor daemon] Store the task in a variable (main.py), supervise it (restart on unexpected exit), and expose
    last_run_at on /ready or /health/monitor. Align one version of exam_monitor.py (stats key names must match the
    log line). Run with skip_locked or batch limits. Test: a cycle that raises does not stop the loop (real daemon
    function, not just one cycle).
4.2 [Postgres tests] Add an opt-in pytest marker `pg` that runs against a scratch Postgres (env TEST_PG_URL):
    concurrent violation reports (threads), double Start Exam click creating one active attempt, CAS auto-close
    from two workers. Add a partial unique index: one active attempt per (assignment, student) where
    submitted_at IS NULL (migration + test). Say plainly which tests ran on Postgres.
4.3 [Docker] Compose: remove --reload for the backend service in prod profile; pin Postgres version to match dev
    (16 vs 18: pick one, document); add a Judge0 service or remove JUDGE0_URL and any programming auto-run claim.
    Pin >= dependencies (langchain, docling, sentence-transformers, faiss) with exact versions; remove pytest from
    prod requirements; confirm the Dockerfile Python version matches requirements; build the image and paste output.
4.4 [Backups] Add scripts/backup.ps1 and backup.sh using pg_dump plus a documented restore test. Delete the junk
    JSON backup. Add backups to gitignore (already) and document where real backups live.
4.5 [Static build] Pick ONE static dir the Dockerfile serves, delete the duplicate, and make the build step part of
    deploy docs (not committed bundles). SPA catch-all must return JSON 404 for /api/* paths. Cache headers: add
    content hashes or lower the wasm cache time.
4.6 [Env docs] docs/ENV.md listing every env var, where it is read, safe defaults, and what production must set.
    Include ENABLE_PYTORCH_EMBEDDINGS, MODEL_RAG_PRIMARY, EMAIL_BACKEND behavior with empty SMTP creds (must not
    crash). HTML-escape user-provided values in email templates.
4.7 [Refactor risk, minimal] Do NOT refactor the 1,600-line exam_screen.dart or 4,600-line assignment_detail_screen
    now. Only extract the new serializer and the config loader into small files.

====================================================
PHASE 5: PROFESSOR UI AND REPORTS
====================================================
5.1 CSV export: real browser download (blob + anchor) as well as copy. Server returns is_live/seconds_since_heartbeat
    (already) with ONE timeout constant; UI never computes time.
5.2 Console: show strikes always, baseline-adjusted strikes, biometric status, last heartbeat age, decision and
    reviewer, offline-only flag distinct from cheating flag. Pagination (server side) for >100 attempts.
5.3 Add a retake button flow: Allow Retake sets retake_granted; the student sees "Retake available".
5.4 Add widget tests: console filters, decision dialog (reason required), settings lock banner, export button.

====================================================
PHASE 6: DOCS, TESTS, CLEANUP
====================================================
6.1 Delete or rewrite tests that test only in-file helper functions (test_exam_attempt.py flag-logic helpers):
    point them at the real record_violation and decision code, or delete them. Remove tests whose names claim more
    than they check.
6.2 Fix docs/PROCTORING_MANUAL_TEST.md: statuses must be NOT RUN unless a human ran it; correct "exactly 1 strike"
    wording to match the focus_loss group; add rows: F5 mid-exam, blocked heartbeat, double-click Start, student
    reads questions before Start, TA permissions, retake end-to-end, MCQ with no options.
6.3 Rewrite docs/CONTEXT_PART_*.md claims that proved wrong (Universal Safeguard, exam_settings table, bcrypt,
    /analytics/system, route names, intervals). Add docs/KNOWN_LIMITS.md: cannot block Alt+Tab/Win key, cannot see
    second devices or VMs, iOS has no fullscreen, Esc lock Chrome/Edge only, concurrency tested on SQLite only
    unless pg marker ran, no webcam proctoring, RAG default is keyword-like, notifications/announcements not built.
6.4 Missing features from the SRS/SDS/Scope PDFs in /mnt/project: build docs/SRS_GAP_TABLE.md (requirement | in
    code? | tested? | gap | FYP-critical?). Do not build them yet, just list.
6.5 Final: run everything, rebuild the Flutter web bundle ONCE, copy it to the single static dir, paste:
    pytest tail, flutter test tail, flutter analyze tail, alembic heads, alembic check, migration up/down on a
    scratch Postgres restored from pg_dump. Then give the summary table and the list of decisions you made, and the
    list of things you could not verify.
</USER_REQUEST>
<ADDITIONAL_METADATA>
The current local time is: 2026-10-18T00:39:19+05:00.
</ADDITIONAL_METADATA>
<USER_SETTINGS_CHANGE>
The user changed setting `Model Selection` from Gemini 3.8 Flash (Medium) to Claude Opus 4.6 (Thinking). No need to comment on this change if the user doesn't ask about it. If reporting what model you are, please use a human readable name instead of the exact string.
</USER_SETTINGS_CHANGE>