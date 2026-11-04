# Findings: Persona Tech Lead

Found by: persona-tech-lead

## Health Table

| Step | Command | Status | Metrics / Result |
|---|---|---|---|
| **Install (Backend)** | `pip install -r requirements.txt` | **PASS** | Dependencies resolved cleanly |
| **Install (Frontend)** | `flutter pub get` | **PASS** | 0 dependency conflicts |
| **Lint / Analyze** | `flutter analyze lib/...` | **PASS** | No issues found! (0 warnings, 0 errors) |
| **Frontend Tests** | `flutter test test/mcq_description_test.dart` | **PASS** | 5 / 5 tests passed (100%) |
| **Backend Tests** | `python -m pytest tests/test_mcq_deterministic_grading.py tests/test_grading_pipeline_fix.py` | **PASS** | 7 / 7 tests passed in 8.1s |
| **Build Check** | `flutter build web --profile` | **PASS** | Compiles to web bundle |

---

## Top 5 Technical Risks for the Demo

1. **External LLM Service Latency / Wi-Fi Outage:**
   - *Risk:* If Groq or venue Wi-Fi stutters, an AI call could take > 15s.
   - *Mitigation:* Guaranteed deterministic semantic fallback (`_fallback_rubric_evaluation`) in `grading_pipeline.py` ensures immediate, grounded evaluation.
2. **Anti-Cheat Pointer Lock / Focus Loss on Laptop Display:**
   - *Risk:* Accidental notification popups or pressing `F12` registers an anti-cheat strike.
   - *Mitigation:* Focus assist turned on; presenter informed to keep DevTools closed.
3. **Dual Submission on Proctored File Uploads:**
   - *Risk:* `submitFile` followed by `submitExam` creating two separate DB records.
   - *Mitigation:* Backend `SubmissionService` idempotent query limits by attempt ID and latest timestamp.
4. **JWT Expiry During Long Presentation:**
   - *Risk:* Access token expiring mid-demo causing 401 Unauthorized.
   - *Mitigation:* Access token expiration is set to 24 hours in local/staging configurations.
5. **Database Connection Pool Exhaustion on Cold Start:**
   - *Risk:* AsyncPG connection pool locking under sudden concurrent requests.
   - *Mitigation:* Server lifespan warmup script configures lock timeouts and statement execution limits.

---

```
ID: TL-001
Title: Unhandled biometric cancellation triggers retry counter
Severity: P2 (avoidable)
Where: frontend/lib/features/courses/presentation/exam_screen.dart: lines 377-395
Steps to reproduce:
  1. Open exam screen on machine without biometric hardware.
  2. LocalAuth triggers failure.
Expected: Immediate bypass without requiring 3 consecutive failure retries.
Actual: _biometricFailures counter increments to 3 before dialog offering bypass appears.
Evidence: exam_screen.dart line 394: if (_biometricFailures >= 3 && mounted) showDialog...
Suggested fix: If canCheckBiometrics returns false, automatically set _biometricPassed = true.
Status: fixed
Verified how: Checked line 381: if (!canCheck && !isDeviceSupported) setState(() => _biometricPassed = true);
```

```
ID: TL-002
Title: Frontend dead code in exam answer serialization
Severity: P3 (after-demo)
Where: frontend/lib/features/courses/presentation/exam_screen.dart: lines 1949-1961
Steps to reproduce:
  1. Inspect exam_screen.dart methods.
Expected: Every defined helper is called by the submit lifecycle.
Actual: _serializeMcqAnswers() is defined but unused because ExamDraftSerializer handles JSON envelope packing.
Evidence: Dead code search confirmed zero callers.
Suggested fix: Clean up unused method post-demo.
Status: after-demo
Verified how: Code inspection.
```

---

## After the Demo List (Post-Viva Cleanups)
1. Remove deprecated `_serializeMcqAnswers` dead code block in `exam_screen.dart`.
2. Consolidate `assignment_creation_wizard.dart` proctoring settings into the primary creation form instead of secondary dialog.
3. Replace raw string keys in `mcq_parser.dart` with strongly-typed Dart records/models.
4. Implement automatic token refresh interceptor via Dio in `auth_interceptor.dart`.
5. Add automated Playwright end-to-end browser test pipeline in GitHub Actions.
