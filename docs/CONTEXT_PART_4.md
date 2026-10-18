# PART 4: BACKEND LOGIC (Services, Background Monitor, Strike Rules & Grading Pipeline)

- **Audit Date:** 2026-10-17
- **Verification Baseline:** Direct reading of `backend/app/services/exam_monitor.py`, `backend/app/services/submission_service.py`, `backend/app/api/v1/exams.py`, `backend/app/services/grading_pipeline.py`, and `backend/app/core/proctor_config.py`.
- **Rules applied:** Zero assumptions, all logic traced with exact line numbers, raw pasted code snippets, and explicit disclosure of bugs, edge cases, and architectural limits.

---

## 1. Exam Monitor Daemon (`backend/app/services/exam_monitor.py:1-109`)

[CODE] Verified by reading `backend/app/services/exam_monitor.py`.

### 1.1 Full Daemon Loop & Lifecycle
- **Startup:** [CODE `backend/app/main.py:65`]:
  ```python
  asyncio.create_task(run_exam_monitor_daemon(interval_seconds=15))
  ```
  Spawned as an unmanaged background task inside the FastAPI lifespan handler.
- **Polling Interval:** Exactly **15 seconds** (passed as default argument `interval_seconds: int = 15`).

### 1.2 Exact Monitor Code
[CODE `backend/app/services/exam_monitor.py:27-91`]:
```python
async def monitor_active_exam_attempts(
    db: AsyncSession, now: Optional[datetime] = None
) -> Dict[str, int]:
    """Scan all active exam attempts and enforce server-side auto-close and offline flagging."""
    now = now or datetime.now(timezone.utc)
    res = await db.execute(
        select(ExamAttempt)
        .options(selectinload(ExamAttempt.assignment))
        .where(ExamAttempt.submitted_at.is_(None))
        .with_for_update()
    )
    active_attempts = list(res.scalars().all())

    closed_count = 0
    flagged_offline_count = 0

    for attempt in active_attempts:
        assignment = attempt.assignment
        if not assignment:
            continue

        # 1. Server-side auto-close past deadline + grace period
        if is_attempt_expired(attempt, assignment, now=now, grace_seconds=DEFAULT_GRACE_SECONDS):
            await auto_close_attempt(attempt, assignment, db, reason="time_expired_background_job")
            closed_count += 1
            continue

        # 2. Heartbeat monitoring (30s threshold)
        if attempt.last_heartbeat_at is not None:
            last_hb = attempt.last_heartbeat_at
            if last_hb.tzinfo is None:
                last_hb = last_hb.replace(tzinfo=timezone.utc)
            elapsed = (now - last_hb).total_seconds()
            if elapsed > HEARTBEAT_TIMEOUT_SECONDS:
                # Log exactly once per outage:
                # Check if a heartbeat_missed event has already been recorded after the last received heartbeat.
                recent_hb_res = await db.execute(
                    select(ExamViolation)
                    .where(
                        ExamViolation.attempt_id == attempt.id,
                        ExamViolation.violation_type == "heartbeat_missed",
                        ExamViolation.occurred_at >= last_hb,
                    )
                    .limit(1)
                )
                can_log = recent_hb_res.scalar_one_or_none() is None

                if can_log:
                    event = ExamViolation(
                        attempt_id=attempt.id,
                        violation_type="heartbeat_missed",
                        occurred_at=now,
                        details=f"No heartbeat received for {int(elapsed)}s.",
                    )
                    db.add(event)
                    attempt.is_flagged = True
                    attempt.flag_reason = f"[OFFLINE] Heartbeat missed ({int(elapsed)}s without signal)."
                    flagged_offline_count += 1

    await db.commit()
    return {
        "active_scanned": len(active_attempts),
        "closed_count": closed_count,
        "flagged_offline": flagged_offline_count,
    }
```

### 1.3 What It Checks & Exact SQL/ORM Behavior
1. **Active Attempt Scan:** Queries all attempts where `submitted_at IS NULL` with `with_for_update()`.
2. **Auto-Close on Expiry:** Checks `is_attempt_expired(..., grace_seconds=10)`. If `now >= started_at + duration_minutes + 10s`, it delegates to `auto_close_attempt(..., reason="time_expired_background_job")`.
3. **Heartbeat Missed (Offline Detection):**
   - Threshold: `HEARTBEAT_TIMEOUT_SECONDS = 30` seconds (`proctor_config.py:4`).
   - Deduplication: Verifies whether an `ExamViolation` with `violation_type == "heartbeat_missed"` already exists with `occurred_at >= last_hb`. This prevents flooding the database every 15s while a student is offline.
   - **Crucial Strike Rule:** Inserting `heartbeat_missed` marks `attempt.is_flagged = True`, but **NEVER increments `tab_switch_count`**.

### 1.4 How It Avoids Double-Closing
[CODE `backend/app/api/v1/exams.py:126-132`]:
```python
res = await db.execute(
    update(ExamAttempt)
    .where(ExamAttempt.id == attempt.id, ExamAttempt.submitted_at.is_(None))
    .values(submitted_at=now, auto_submitted=True)
)
if res.rowcount == 0:
    return False
```
An atomic Compare-And-Swap (CAS) SQL statement ensures that if a student submits or another thread closes the attempt concurrently, only the first transaction gets `rowcount == 1`. The second worker gets `rowcount == 0` and returns `False` immediately without duplicating submissions or audit events.

### 1.5 Error Handling & Crash Failure Modes
[CODE `backend/app/services/exam_monitor.py:97-108`]:
```python
while True:
    try:
        async with async_session() as session:
            stats = await monitor_active_exam_attempts(session)
    except asyncio.CancelledError:
        logger.info("Exam Monitor daemon cancelled.")
        break
    except Exception as e:
        logger.exception("Error in Exam Monitor daemon: %s", e)
    await asyncio.sleep(interval_seconds)
```
- **Transient Failures:** Any DB timeout, connection loss, or query exception is caught by `except Exception`, logged via `logger.exception`, and the loop resumes on the next 15-second tick.
- **Unrecovered Crash Risk:** The task runs as an unmanaged `asyncio.create_task`. There is **no supervisor, watchdog, or restart loop**. If an unhandled fatal error terminates the task, the daemon dies permanently for the lifetime of that backend worker process. Expired attempts will only be auto-closed when students interact with the API (`exams.py:196`).

---

## 2. Submission Service (`backend/app/services/submission_service.py:1-256`)

[CODE] Verified by reading `backend/app/services/submission_service.py`.

### 2.1 Text / Code Submission Handler (`submit`)
[CODE `backend/app/services/submission_service.py:37-91`]:
```python
    async def submit(
        self,
        assignment_id: int,
        student_id: int,
        data: SubmissionCreate,
        *,
        auto_submitted: Optional[bool] = None,
    ) -> Submission:
        """Create or update a student's submission (one per student per assignment)."""
        if auto_submitted is None:
            auto_submitted = bool(getattr(data, "auto_submitted", False))
        # Check assignment exists and is published
        assignment = await self.db.get(Assignment, assignment_id)
        if not assignment:
            raise ValueError("Assignment not found.")
        if assignment.status == "closed":
            raise ValueError("This assignment is closed for submissions.")
        if assignment.status != "published":
            raise ValueError("Assignment is not yet published.")

        if assignment.deadline:
            now = datetime.now(timezone.utc)
            dl = assignment.deadline if assignment.deadline.tzinfo else assignment.deadline.replace(tzinfo=timezone.utc)
            if now > dl and not assignment.allow_late and not auto_submitted:
                raise ValueError("The submission deadline has passed and late submissions are not allowed.")

        # Check if already submitted (update instead of create)
        existing = await self._get_submission(assignment_id, student_id)
        if existing:
            if existing.status == SubmissionStatus.GRADED.value:
                raise ValueError("This assignment has already been evaluated and graded. Submissions can no longer be modified.")
            # Allow resubmission for pending submissions – update content
            existing.content = data.content
            existing.submission_type = data.submission_type
            existing.status = SubmissionStatus.PENDING.value
            existing.auto_submitted = auto_submitted
            existing.score = None
            existing.feedback = None
            existing.graded_by_id = None
            existing.graded_at = None
            existing.submitted_at = datetime.now(timezone.utc)
            await self.db.flush()
            return existing

        submission = Submission(
            assignment_id=assignment_id,
            student_id=student_id,
            submission_type=data.submission_type,
            content=data.content,
            status=SubmissionStatus.PENDING.value,
            auto_submitted=auto_submitted,
        )
        self.db.add(submission)
        await self.db.flush()
        return await self._reload(submission.id)
```

### 2.2 File Upload Handler (`save_file`)
[CODE `backend/app/services/submission_service.py:93-147`]:
- **Directory:** `uploads/submissions/` (`STORAGE_ROOT/submissions`).
- **File Name Sanitization:** `re.sub(r"[^A-Za-z0-9_.-]", "_", original_name)`. Saved as `{assignment_id}_{student_id}_{safe_name}`.
- **Dangerous Extensions Blocked:**
  ```python
  ext = Path(safe_name_part).suffix.lower()
  if ext in {".exe", ".bat", ".cmd", ".sh", ".bash", ".msi", ".dll", ".scr", ".vbs", ".ps1", ".com", ".pyw"}:
      raise ValueError(f"File extension '{ext}' is prohibited for security reasons.")
  ```
- **File Overwrite Behavior:** If a previous submission row exists, it updates `file_path`, sets `content = None`, clears prior grades/feedback, and resets `status = 'pending'`.

### 2.3 Deadline, Grace Window & Late Penalty Rules
1. **Deadline Check:**
   [CODE `submission_service.py:57-61`]:
   ```python
   if now > dl and not assignment.allow_late and not auto_submitted:
       raise ValueError("The submission deadline has passed and late submissions are not allowed.")
   ```
2. **Grace Window:** There is **NO grace window** in `submission_service.py`. The comparison `now > dl` is a zero-second strict cutoff. (The only grace window in the system is `SUBMISSION_GRACE_SECONDS = 10s`, applied to `attempt.started_at + duration_minutes` in `exams.py:93`).
3. **Dead Configuration Alert:** `late_penalty_per_day` and `max_penalty_cap` exist as columns on `assignments`, but **are never referenced in any calculation** in `submission_service.py`, `grading_pipeline.py`, or `exams.py`. They are dead fields.

### 2.4 Max Attempts & Retake Math: Where Does It Live?
- `submission_service.py` **never** checks `max_attempts`.
- The attempt ceiling is enforced strictly at exam inception in `start_exam` [CODE `backend/app/api/v1/exams.py:386-413`]:
  ```python
  completed_count = len([a for a in existing_attempts if a.submitted_at is not None])
  retakes_allowed = len([a for a in existing_attempts if a.decision == "allow_retake"])
  allowed_attempts = (assignment.max_attempts or 1) + retakes_allowed

  if completed_count >= allowed_attempts:
      raise HTTPException(status_code=400, detail="Maximum attempts reached for this exam.")
  ```

---

## 3. Strike & Anti-Cheat Rules (`backend/app/api/v1/exams.py:184-286`)

[CODE] Verified by reading `backend/app/api/v1/exams.py` and `backend/app/core/proctor_config.py`.

### 3.1 Central Constants & Thresholds
| Parameter | Value | Source File & Line | Purpose |
| :--- | :--- | :--- | :--- |
| `VIOLATION_DEDUPE_WINDOW_SECONDS` | `1.5`s | `proctor_config.py:6` | Debounce window for telemetry events |
| `DEFAULT_STRIKE_LIMIT_FLAG` | `3` | `proctor_config.py:7` | Default strikes before attempt is marked `is_flagged = True` |
| `DEFAULT_STRIKE_LIMIT_AUTOSUBMIT` | `5` | `proctor_config.py:8` | Default strikes before student is disqualified and auto-submitted |
| `HEARTBEAT_TIMEOUT_SECONDS` | `30`s | `proctor_config.py:4` | Time without ping before attempt is marked offline |
| `SUBMISSION_GRACE_SECONDS` | `10`s | `proctor_config.py:5` | Grace window past timer before auto-close triggers |

### 3.2 Deduplication Code & Double-Strike Flaw
[CODE `backend/app/api/v1/exams.py:208-236`]:
```python
    # 2. Server-side deduplication within sliding window (1.5 seconds)
    recent_res = await db.execute(
        select(ExamViolation)
        .where(
            ExamViolation.attempt_id == attempt.id,
            ExamViolation.violation_type == violation_type,
        )
        .order_by(ExamViolation.occurred_at.desc())
        .limit(1)
    )
    recent = recent_res.scalar_one_or_none()
    if recent:
        last_t = recent.occurred_at
        if last_t.tzinfo is None:
            last_t = last_t.replace(tzinfo=timezone.utc)
        if (now - last_t).total_seconds() < DEDUPE_WINDOW_SECONDS:
            return {
                "attempt_id": attempt.id,
                "tab_switch_count": attempt.tab_switch_count,
                "strike_count": attempt.tab_switch_count,
                "is_flagged": attempt.is_flagged,
                "message": "Duplicate violation within debounce window ignored.",
                "deduplicated": True,
            }
```
- **Flaw:** Line 212 scopes deduplication to `ExamViolation.violation_type == violation_type`. When a student switches windows, the browser fires `window_blur` followed by `tab_switch`. Because their `violation_type` strings differ, both events bypass the 1.5s filter and register **2 strikes**.
- **No Excluded Types:** Every violation routed through `record_violation` increments `tab_switch_count`.

---

## 4. Auto-Close Submission Reconciliation

[CODE `backend/app/api/v1/exams.py:156-179`]

```python
    fallback_content = (
        attempt.current_answers
        or f"// [Time Expired - Auto-Submitted by System ({reason})]"
    )
    sub_type = getattr(assignment, "type", "text") or "text"
    if hasattr(sub_type, "value"):
        sub_type = sub_type.value

    if existing_sub:
        existing_sub.auto_submitted = True
        if not existing_sub.content and attempt.current_answers:
            existing_sub.content = attempt.current_answers
    else:
        new_sub = Submission(
            assignment_id=assignment.id,
            student_id=attempt.student_id,
            submission_type=str(sub_type),
            content=fallback_content,
            status=SubmissionStatus.PENDING.value,
            auto_submitted=True,
            submitted_at=now,
        )
        db.add(new_sub)
```

### Format Handling by Assignment Type
- **`text` / `programming`:** `attempt.current_answers` contains the raw drafted text/code. Stored directly into `Submission.content`.
- **`mcq`:** The frontend serializes radio button selections to a JSON string (e.g. `'{"0":"A","1":"B"}'`). `auto_close_attempt` performs **no parsing**; it writes this JSON string directly into `Submission.content`.
- **`file`:** If the student has not uploaded a file before the timeout, `submission.file_path` remains `None`, and `content` is set to `// [Time Expired - Auto-Submitted by System (time_expired)]`.
- **`quiz`:** Not handled here. OBE quizzes run via `student_quiz_attempts` in `quizzes.py` and do not participate in `auto_close_attempt`.

---

## 5. Auto-Grading & LLM Pipeline Analysis

[CODE `backend/app/services/grading_pipeline.py:206-260`]

```python
def _grade_submission_core(
    assignment_title: str,
    assignment_prompt: str,
    max_marks: float,
    rubric_criteria: List[Dict[str, Any]],
    student_submission_content: str,
    submission_type: str = "text",
) -> GradingEvaluationSchema:
    injection_codes = detect_prompt_injection(student_submission_content)
    if injection_codes:
        raise PromptInjectionDetected(injection_codes)
    llm = get_llm_client()
    ...
```

### What Happens When an MCQ Assignment Gets a Text/JSON Submission?
1. **Does it crash?** **NO.** The prompt treats `student_submission_content` as an arbitrary string.
2. **Does it mis-grade?** **YES.**
   - ProfessorOS has no deterministic MCQ answer-key matching in `submissions.py` (unlike `quizzes.py`).
   - The LLM receives the MCQ questions (from `assignment.description`) and the student's text/JSON answers inside `<student_submission>`.
   - The LLM attempts to evaluate the string against the subjective rubric criteria (e.g., "Technical Accuracy & Methodology").
   - It outputs hallucinated scores and essay-style feedback for multiple-choice answers.
3. **Does it go to manual review?**
   - If the student typed nothing and was auto-closed, `content` is `// [Time Expired ...]`.
   - In `submissions.py:318-333`, `build_document_triage` flags empty content with `triage_reasons: ["blank_or_unreadable"]` and sets `needs_review: True`.
   - If the student typed arbitrary text or valid JSON, triage passes, and the LLM grades it automatically unless prompt injection is detected.

---

## 6. Text Sanitization (`sanitize_plain_text`)

[CODE `backend/app/api/v1/exams.py:39-45`]:
```python
def sanitize_plain_text(text: Optional[str], max_length: int = 255) -> Optional[str]:
    """Sanitizes violation details and explanations to strict plain text."""
    if not text:
        return None
    cleaned = re.sub(r"<[^>]*>", "", text)
    cleaned = "".join(ch for ch in cleaned if ch.isprintable() or ch in "\n\r\t")
    return cleaned.strip()[:max_length]
```

### What It Strips
1. **HTML/XML tags:** Stripped via regex `re.sub(r"<[^>]*>", "", text)`.
2. **Control & Non-printable Characters:** Filters out characters where `ch.isprintable()` is False (preserves `\n`, `\r`, `\t`).
3. **Length Exceedance:** Truncates to `max_length` (default 255 characters).

### Where It Is Called
1. [CODE `exams.py:193`]: In `record_violation`, called on incoming telemetry `details`.
2. [CODE `exams.py:822`]: In `list_exam_attempts`, called when serializing `v.details` to the professor console.

### Where It Is NOT Called (Input Gaps)
- **Draft answers (`body.answers`):** In `attempt_heartbeat` (`exams.py:567`), answers are written directly to `attempt.current_answers` without HTML tag stripping or control character filtering.
- **Decision rationale (`payload.reason`):** In `update_exam_attempt_decision` (`exams.py:873`), instructor reasons are trimmed but not sanitized against HTML.
- **Submission content (`data.content`):** In `submission_service.py:69, 85`, student essay text is stored unescaped in the database.

---

## 7. Part 4 Follow-Up Audit & In-Depth Technical Evidence

### 7.1 Backend Lifespan & Real `exam_monitor.py` Code [CODE]
- **Lifespan Code [CODE `backend/app/main.py:23-36`]:**
  ```python
  @asynccontextmanager
  async def lifespan(app: FastAPI):
      """Start the API without mutating application data or database schema."""
      import asyncio
      from app.services.exam_monitor import run_exam_monitor_daemon
      monitor_task = asyncio.create_task(run_exam_monitor_daemon(interval_seconds=15))
      yield
      monitor_task.cancel()
      try:
          await monitor_task
      except asyncio.CancelledError:
          pass
      await engine.dispose()
  ```
  - **Is task stored in a variable?** YES: `monitor_task = asyncio.create_task(...)`. Properly cancelled and awaited on shutdown.
  - **Do stats keys match the log line?** YES: `exam_monitor.py:101` checks `stats["closed_count"] > 0 or stats["flagged_offline"] > 0`, matching the dict returned by `monitor_active_exam_attempts` (`active_scanned`, `closed_count`, `flagged_offline`).

- **Full `exam_monitor.py` on disk [CODE `backend/app/services/exam_monitor.py:1-109`]:**
  ```python
  """ProfessorOS – Background exam attempt monitoring service.

  Auto-closes attempts that exceeded their deadline and flags attempts with missed heartbeats.
  """

  import asyncio
  from datetime import datetime, timezone
  import logging
  from typing import Dict, Optional

  from sqlalchemy import select
  from sqlalchemy.ext.asyncio import AsyncSession
  from sqlalchemy.orm import selectinload

  from app.db.base import async_session
  from app.models.exam_attempt import ExamAttempt, ExamViolation
  from app.api.v1.exams import (
      auto_close_attempt,
      is_attempt_expired,
      DEFAULT_GRACE_SECONDS,
      HEARTBEAT_TIMEOUT_SECONDS,
  )

  logger = logging.getLogger("professor_os.exam_monitor")


  async def monitor_active_exam_attempts(
      db: AsyncSession, now: Optional[datetime] = None
  ) -> Dict[str, int]:
      """Scan all active exam attempts and enforce server-side auto-close and offline flagging."""
      now = now or datetime.now(timezone.utc)
      res = await db.execute(
          select(ExamAttempt)
          .options(selectinload(ExamAttempt.assignment))
          .where(ExamAttempt.submitted_at.is_(None))
          .with_for_update()
      )
      active_attempts = list(res.scalars().all())

      closed_count = 0
      flagged_offline_count = 0

      for attempt in active_attempts:
          assignment = attempt.assignment
          if not assignment:
              continue

          # 1. Server-side auto-close past deadline + grace period
          if is_attempt_expired(attempt, assignment, now=now, grace_seconds=DEFAULT_GRACE_SECONDS):
              await auto_close_attempt(attempt, assignment, db, reason="time_expired_background_job")
              closed_count += 1
              continue

          # 2. Heartbeat monitoring (30s threshold)
          if attempt.last_heartbeat_at is not None:
              last_hb = attempt.last_heartbeat_at
              if last_hb.tzinfo is None:
                  last_hb = last_hb.replace(tzinfo=timezone.utc)
              elapsed = (now - last_hb).total_seconds()
              if elapsed > HEARTBEAT_TIMEOUT_SECONDS:
                  # Log exactly once per outage:
                  # Check if a heartbeat_missed event has already been recorded after the last received heartbeat.
                  recent_hb_res = await db.execute(
                      select(ExamViolation)
                      .where(
                          ExamViolation.attempt_id == attempt.id,
                          ExamViolation.violation_type == "heartbeat_missed",
                          ExamViolation.occurred_at >= last_hb,
                      )
                      .limit(1)
                  )
                  can_log = recent_hb_res.scalar_one_or_none() is None

                  if can_log:
                      event = ExamViolation(
                          attempt_id=attempt.id,
                          violation_type="heartbeat_missed",
                          occurred_at=now,
                          details=f"No heartbeat received for {int(elapsed)}s.",
                      )
                      db.add(event)
                      attempt.is_flagged = True
                      attempt.flag_reason = f"[OFFLINE] Heartbeat missed ({int(elapsed)}s without signal)."
                      flagged_offline_count += 1

      await db.commit()
      return {
          "active_scanned": len(active_attempts),
          "closed_count": closed_count,
          "flagged_offline": flagged_offline_count,
      }


  async def run_exam_monitor_daemon(interval_seconds: int = 15) -> None:
      """Async periodic worker loop checking active attempts every 15-30 seconds."""
      logger.info("Starting Exam Monitor daemon (interval: %ss)", interval_seconds)
      while True:
          try:
              async with async_session() as session:
                  stats = await monitor_active_exam_attempts(session)
                  if stats["closed_count"] > 0 or stats["flagged_offline"] > 0:
                      logger.info("Exam Monitor cycle completed: %s", stats)
          except asyncio.CancelledError:
              logger.info("Exam Monitor daemon cancelled.")
              break
          except Exception as e:
              logger.exception("Error in Exam Monitor daemon: %s", e)
          await asyncio.sleep(interval_seconds)
  ```

---

### 7.2 Initial Heartbeat on Start & Attempts That Never Send Pings [CODE]
1. `start_exam` **DOES** set `last_heartbeat_at = now` [CODE `exams.py:404, 421`].
2. If a student starts an exam and immediately disconnects without ever sending a heartbeat:
   - Within 30 seconds (`elapsed = now - started_at > 30s`), `exam_monitor.py:60-84` fires: inserts `ExamViolation(violation_type="heartbeat_missed")`, flags `is_flagged = True`, and sets `flag_reason = "[OFFLINE] Heartbeat missed..."`.
   - Once `now >= started_at + duration_minutes + 10s`, the monitor auto-closes the attempt, reconciles a blank submission with `// [Time Expired - Auto-Submitted by System (time_expired_background_job)]`, and marks `auto_submitted = True`.

---

### 7.3 Flag Reason Overwrite & Reconnect Behavior [CODE]
1. **Does the monitor overwrite `flag_reason`?**
   **YES [CODE `exam_monitor.py:82-83`]:** It unconditionally executes:
   ```python
   attempt.is_flagged = True
   attempt.flag_reason = f"[OFFLINE] Heartbeat missed ({int(elapsed)}s without signal)."
   ```
   If the student was previously flagged for 3 tab switches, the offline notice completely overwrites the reason string.
2. **Does reconnect clear `is_flagged`?**
   **YES, conditionally [CODE `exams.py:570-577`]:**
   ```python
   if attempt.flag_reason and "[OFFLINE]" in attempt.flag_reason:
       attempt.flag_reason = (
           f"Flagged: {attempt.tab_switch_count} violations detected."
           if attempt.tab_switch_count >= strike_flag
           else None
       )
       attempt.is_flagged = attempt.tab_switch_count >= strike_flag
   ```
   If `tab_switch_count < strike_flag`, reconnect resets `is_flagged = False` and `flag_reason = None`.

---

### 7.4 Auto-Close Reason Storage & Violation Rows [CODE]
- **Is auto-close reason stored in a column?** NO. `exam_attempts` has no `close_reason` column; only `auto_submitted = True` (boolean).
- **Does auto_close create a violation row?** YES [CODE `exams.py:138-144`]:
  ```python
  event = ExamViolation(
      attempt_id=attempt.id,
      violation_type="auto_close",
      occurred_at=now,
      details=f"Attempt auto-closed ({reason}).",
  )
  db.add(event)
  ```

---

### 7.5 Triage of the "[Time Expired" Placeholder [CODE]
[CODE `backend/app/services/document_ingestion.py:56-66`]:
```python
def build_document_triage(text: str, file_path: Optional[str] = None, max_chars: int = 25000) -> List[str]:
    """Classify extraction hazards without changing or sanitizing student evidence."""
    reasons: List[str] = []
    clean_text = (text or "").strip()
    if not clean_text:
        reasons.append("scanned_or_image_only" if file_path and Path(file_path).suffix.lower() == ".pdf" else "blank_or_unreadable")
    elif "Document truncated at" in clean_text:
        reasons.append("truncated_oversized_file")
    if detect_prompt_injection(clean_text):
        reasons.append("injection_detected")
    return reasons
```
**CRITICAL FLAW:** `build_document_triage` **does NOT special-case `// [Time Expired - Auto-Submitted by System]`**.
Because `clean_text` is non-empty, `triage_reasons` returns `[]` (empty). Deterministic triage passes, and the backend sends the auto-submitted system error placeholder directly to DeepSeek-R1-Distill-70B for grading.

---

### 7.6 Dynamic Strike Thresholds & Settings Schema Inconsistency [CODE]
1. `record_violation` **reads from the assignment row**, falling back to config defaults [CODE `exams.py:255-256`]:
   ```python
   strike_flag = getattr(assignment, "strike_limit_flag", DEFAULT_STRIKE_LIMIT_FLAG) or DEFAULT_STRIKE_LIMIT_FLAG
   strike_auto = getattr(assignment, "strike_limit_autosubmit", DEFAULT_STRIKE_LIMIT_AUTOSUBMIT) or DEFAULT_STRIKE_LIMIT_AUTOSUBMIT
   ```
2. **Schema Inconsistency [CODE `exams.py:63-70`]:**
   `ExamSettingsRequest` allows `strike_limit_flag` in range [1, 20] and `strike_limit_autosubmit` in range [2, 50], but **has no validator ensuring `strike_limit_flag <= strike_limit_autosubmit`**. A professor can set `strike_limit_flag = 20` and `strike_limit_autosubmit = 2`.

---

### 7.7 Content and Answer Field Length Limits [CODE]
- `HeartbeatRequest.answers` [CODE `exams.py:57-61`]: **NO limit** (`Optional[str] = None`, no `max_length`).
- `SubmissionCreate.content` [CODE `backend/app/schemas/submission.py:9-11`]: **NO limit** (`Optional[str] = None`, no `max_length`).

---

### 7.8 Lock Acquisition in `/switch-tab` and `/exam/flag` [CODE]
1. `/attempts/{id}/switch-tab` calls `report_attempt_violation` [CODE `exams.py:442-451`]: Acquires row-level lock via `with_for_update()` on `ExamAttempt` **before** calling `record_violation`.
2. `/exam/flag` [CODE `exams.py:488-499`]: Acquires row-level lock via `with_for_update()` on `ExamAttempt` **before** calling `record_violation`.

---

### 7.9 CSV Formula Injection & File Download Headers [CODE]
1. **CSV Formula Injection:** **UNPROTECTED [CODE `exams.py:957-1000`].**
   Uses Python's standard `csv.writer` and dumps `student_name`, `decision_reason`, and `email` directly into cells without escaping leading `=`, `+`, `-`, or `@`.
2. **Content-Disposition on File Download [CODE `submissions.py:608`, `exams.py:1006`]:**
   - File download: `FileResponse(str(path), filename=sub.file_name or path.name)` generates `Content-Disposition: attachment; filename="..."`.
   - CSV export: Explicit header `Content-Disposition: attachment; filename=exam_attempts_assignment_{id}.csv`.

---

### 7.10 Assignment & Quiz Dead Configuration Audit [CODE]

| Field Name | Table | Read Anywhere in Business Logic? | Audit Finding |
| :--- | :--- | :--- | :--- |
| `late_penalty_per_day` | `assignments` | **NO** | Set in `assignment_service.py:45`. Never evaluated during grading or submission. (DEAD) |
| `max_penalty_cap` | `assignments` | **NO** | Set in `assignment_service.py:46`. Never evaluated during grading or submission. (DEAD) |
| `randomize_questions` | `assignments` | **NO** | Set in `assignment_service.py:49`. Never evaluated during exam attempts. (DEAD on assignments) |
| `show_results_after` | `assignments` | **NO** | Set in `assignment_service.py:50`. Never evaluated during exam attempts. (DEAD on assignments) |
| `randomize_order` | `quiz_configs` | **YES** | Read at `quizzes.py:1035` (`random.shuffle(questions)`). (ACTIVE) |
| `show_answers_after` | `quiz_configs` | **YES** | Read at `quizzes.py:1158` (hides/shows rationale). (ACTIVE) |
| `bloom_gate_passed` | `quiz_configs` | **YES** | Read at `quizzes.py:622`, updated at `blooms_gate.py:150`. (ACTIVE) |
| `time_limit_minutes` | `quiz_configs` | **YES** | Read at `quizzes.py:1042`. (ACTIVE) |
| `max_attempts` | `quiz_configs` | **YES** | Read at `quizzes.py:968`. (ACTIVE) |

---

### 7.11 Real `backend/app/services` Directory Catalog [RAN]
There is **NO `ai_grading_service.py` file**. The actual module on disk is `grading_pipeline.py`.
Full listing of all 21 service modules currently on disk:
```
backend/app/services/
├── analytics_service.py         ( 6,543 bytes)
├── approval_state.py            (   203 bytes)
├── assignment_access.py         (   679 bytes)
├── assignment_service.py        (13,283 bytes)
├── auth_service.py              ( 9,616 bytes)
├── blooms_gate.py               ( 8,059 bytes)
├── cache_service.py             ( 4,769 bytes)
├── clo_attainment.py            (10,486 bytes)
├── course_service.py            (12,254 bytes)
├── document_ingestion.py        (25,081 bytes)
├── email_service.py             (10,725 bytes)
├── exam_monitor.py              ( 4,173 bytes)
├── grading_pipeline.py          (16,873 bytes)  <-- LLM DeepSeek grading pipeline
├── hec_dossier.py               (26,142 bytes)
├── intent_router.py             (10,715 bytes)
├── question_generation.py       (14,112 bytes)
├── registration_policy.py       (   205 bytes)
├── student_access.py            (   364 bytes)
├── student_dashboard_service.py ( 3,645 bytes)
├── submission_service.py        (10,646 bytes)
└── user_service.py              ( 9,458 bytes)
```

---

PART 4 FOLLOW-UP DONE

