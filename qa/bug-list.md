# Merged & Ranked Bug List: ProfessorOS Pre-Demo Audit

All findings ranked by damage to the live presentation per `shared/severity-scale.md`.

---

## P0 Blockers (Must be fixed before live audience)

| ID | Title | Found By | Where | Status | Verification |
|---|---|---|---|---|---|
| **P0-1** | MCQ Single Textbox Failure on Exam Screen | QA Audit / First-Timer | `exam_screen.dart`, `mcq_parser.dart` | **FIXED** | Tested in `mcq_description_test.dart` |
| **P0-2** | Deterministic MCQ Grading Off-by-One Mismatch (Scored 0/100 on Correct Answer) | Bug Hunter / Examiner | `exam_screen.dart`, `grading_pipeline.py` | **FIXED** | Tested in `test_mcq_deterministic_grading.py` |
| **P0-3** | Short Questions Hidden Behind Blank Textarea | First-Timer / QA Audit | `assignment_detail_screen.dart`, `exam_screen.dart` | **FIXED** | Tested in `mcq_description_test.dart` |
| **P0-4** | MCQ False-Positive Scoring on Wrong Choice via Unconditional 1-Based Offset | Tech Lead / Bug Hunter | `backend/app/services/grading_pipeline.py` | **FIXED** | Tested in `test_phase3_grading.py` & `test_mcq_deterministic_grading.py` |

---

## P1 High (Breaks a likely detour or live flow)

| ID | Title | Found By | Where | Status | Verification |
|---|---|---|---|---|---|
| **P1-1** | Hybrid Assessment Short Questions Erased | Power User / Tech Lead | `mcq_parser.dart` | **FIXED** | Tested in `mcq_description_test.dart` |
| **P1-2** | Live AI API Outage / Rate Limit Handling | Scenario AI Failures | `grading_pipeline.py` | **VERIFIED / SAFE** | Tested in `test_grading_pipeline_fix.py` |
| **P1-3** | Prompt Injection in Student Submissions | Attacker | `grading_pipeline.py` | **VERIFIED / SAFE** | Tested in `test_audit_fixes.py` (32/32) |
| **P1-4** | Malicious Executable Upload Attempt | Attacker | `submission_service.py` | **VERIFIED / SAFE** | Tested extension blacklist |
| **P1-5** | Duplicate File Submission Row in Exam Mode | Chaos Engineer | `exam_screen.dart`, `exams.py` | **MITIGATED** | Idempotent submission query |
| **P1-6** | AI Schema Total Score Inconsistency Crash | Tech Lead / Chaos | `grading_pipeline.py` | **FIXED** | Tested in `test_audit_fixes.py` |

---

## P2 Medium (Looks bad or confusing, avoid during demo)

| ID | Title | Found By | Where | Status | Mitigation / Guidance |
|---|---|---|---|---|---|
| **P2-1** | Biometric Hardware Prompt on Laptop | Low-End User / First-Timer | `exam_screen.dart` | Open (Avoidable) | Click "Skip Biometric" if no Windows Hello camera |
| **P2-2** | Proctoring Toggles Not in Initial Wizard | Tech Lead | `assignment_creation_wizard.dart` | Open (Avoidable) | Configure from Assignment Detail Settings after create |
| **P2-3** | DevTools Docking Causes Anti-Cheat Strike | Demo Disasters | `exam_screen.dart` | Avoidable | Keep DevTools closed during student view |
| **P2-4** | Course Card Top Chips RenderFlex 4.8px Mobile Overflow | Low-End User | `course_list_screen.dart` | **FIXED** | Tested in `course_mobile_test.dart` (2/2) |

---

## Work Order Summary
1. All P0 blockers are **100% RESOLVED and TESTED** (Zero remaining P0 blockers).
2. All P1 issues are **RESOLVED or GUARDED** against live presentation failure.
3. All P2 items are either fixed or documented with explicit presenter instructions.
4. Total Test Suite Health: **240 / 240 passing tests (156 Backend + 84 Frontend, 0 failures)**.
