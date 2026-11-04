# Findings: Persona Chaos Engineer

Found by: persona-chaos-engineer

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
