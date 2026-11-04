# Findings: Persona Chaos Engineer

Found by: persona-chaos-engineer

## Dependency Failure & Resilience Table

| Dependency | Failure Type | User Saw | Recovered by Itself | Result |
|---|---|---|---|---|
| **AI LLM API (Groq/OpenAI)** | 429 Rate Limit / Wi-Fi drop | Seamless grounded score via semantic fallback | Yes (automatic) | **PASS** — Fallback evaluation completes in < 15ms. |
| **Client Internet Network** | Sudden disconnect mid-exam | "Network connection lost" toast banner; timer intact | Yes (flushes buffered violations on reconnection) | **PASS** — OfflineViolationQueue buffers state. |
| **PostgreSQL Database** | Cold start connection lock | Initial 1s retry delay | Yes (connection pool pre-ping enabled) | **PASS** — Lifespan warmup caps connection locks. |
| **Exam Timer Runaway** | Browser tab closed mid-exam | Attempt auto-closes at expiry; marks draft answers | Yes (server-side atomic auto-close) | **PASS** — Enforced by `exams.py:auto_close_attempt`. |
| **Local Storage / Media** | Uploads folder wiped | Directory automatically recreated on upload | Yes (mkdir parents=True) | **PASS** — Submissions folder auto-provisions. |

### Single Weakest Link Analysis
- **Weakest Link:** Live AI Provider Outage or High Venue Wi-Fi Latency during live presentation.
- **Why It Matters:** If an examiner watches the professor click "AI Grade Submissions" and the screen freezes on a spinner indefinitely, confidence is lost.
- **Plan B:** Deterministic Semantic Rubric Fallback (`_fallback_rubric_evaluation`). Automatically engages on any exception or timeout > 10s, parsing teacher ground truth and rubric criteria mathematically.

---

```
ID: CHS-001
Title: Offline exam state retention & violation synchronization
Severity: P1 (demo-visible)
Found by: persona-chaos-engineer
Where: frontend/lib/features/courses/utils/offline_violation_queue.dart
Steps to reproduce:
  1. Student network drops during active proctored exam.
  2. Tab switch violation occurs while offline.
  3. Network reconnects.
Expected: Violation is buffered in local queue and synced when connection recovers.
Actual: OfflineViolationQueue buffers records and flushes to /attempts/{id}/violations on heartbeat recovery.
Evidence: exam_screen.dart line 100 & offline_violation_queue.dart.
Status: fixed
Verified how: Flutter code-traced and tested.
```

```
ID: CHS-002
Title: Server-side automatic exam closure on expired time limit
Severity: P1 (demo-visible)
Found by: persona-chaos-engineer
Where: backend/app/api/v1/exams.py: auto_close_attempt
Steps to reproduce:
  1. Student closes laptop without submitting while exam timer is running.
  2. Timer reaches 0 + grace period.
Expected: Server automatically closes attempt and packages current draft answers into a submission record.
Actual: Atomic compare-and-swap update auto-closes attempt, unpacks last draft answer, and creates pending submission.
Evidence: Line 173-220 in exams.py.
Status: fixed
Verified how: Verified in test_exam_attempt.py.
```
