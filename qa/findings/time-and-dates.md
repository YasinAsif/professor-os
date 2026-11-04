# Findings: Scenario Time and Dates

Found by: scenario-time-and-dates

## Time Features & Storage Matrix

| Feature | Storage Format | Presentation Format | Test Result |
|---|---|---|---|
| **Assignment Deadline** | UTC ISO-8601 (`TIMESTAMPTZ`) | Local formatted date (`dd MMM yyyy, hh:mm a`) | **PASS** — Proper timezone parsing |
| **Exam Countdown Timer** | Integer minutes | Digital countdown (`mm:ss`) | **PASS** — Client countdown synced with server start time |
| **Late Submission Grace** | Boolean `allow_late` + `late_penalty_per_day` | Warning notice with penalty percentage/day | **PASS** — Enforced in `SubmissionService.submit` |
| **Exam Attempt Heartbeat** | UTC `DateTime` (`last_heartbeat_at`) | Seconds since last heartbeat | **PASS** — Heartbeat ping interval: 10s |
| **Proctoring Return Grace** | Integer seconds (`15s`) | Fullscreen return countdown modal | **PASS** — 15-second return grace period verified |

---

```
ID: TIM-001
Title: Late submission enforcement and penalty capping
Severity: P1 (demo-visible)
Where: backend/app/services/submission_service.py: lines 58-63 & test_business_rules_validation.py
Steps to reproduce:
  1. Student submits after assignment deadline when allow_late is False.
Expected: Rejection with "The submission deadline has passed and late submissions are not allowed."
Actual: Strict datetime check (now > dl) rejects submission immediately.
Evidence: test_business_rules_validation.py: 20/20 passed.
Status: fixed
Verified how: Executed pytest tests/test_business_rules_validation.py.
```

```
ID: TIM-002
Title: Exam timer tampering resilience via server-side attempt tracking
Severity: P1 (demo-visible)
Where: backend/app/api/v1/exams.py: is_attempt_expired
Steps to reproduce:
  1. Student changes client OS clock forward/backward during timed exam.
Expected: Server enforces duration based on attempt.started_at + duration_minutes regardless of client clock.
Actual: Server calculates expiry using datetime.now(timezone.utc) - attempt.started_at. Client clock manipulation has zero effect on server-side attempt validity.
Evidence: exams.py line 30 & line 480.
Status: fixed
Verified how: Unit tested in test_exam_attempt.py.
```
