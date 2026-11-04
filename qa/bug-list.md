# Merged & Ranked Bug List: ProfessorOS Pre-Demo Audit

All findings ranked by damage to the live presentation per `shared/severity-scale.md`.

---

## P0 Blockers (Must be fixed before live audience)

| ID | Title | Found By | Where | Status |
|---|---|---|---|---|
| **P0-1** | MCQ Single Textbox Failure on Exam Screen | QA Audit / First-Timer | `exam_screen.dart`, `mcq_parser.dart` | **FIXED** (Commit `98fceac`) |
| **P0-2** | Deterministic MCQ Grading Off-by-One Mismatch (Scored 0/100 on Correct Answer) | Bug Hunter / Examiner | `exam_screen.dart`, `grading_pipeline.py` | **FIXED** (Commit `98fceac`) |
| **P0-3** | Short Questions Hidden Behind Blank Textarea | First-Timer / QA Audit | `assignment_detail_screen.dart`, `exam_screen.dart` | **FIXED** (Commit `98fceac`) |

---

## P1 High (Breaks a likely detour or live flow)

| ID | Title | Found By | Where | Status |
|---|---|---|---|---|
| **P1-1** | Hybrid Assessment Short Questions Erased | Power User / Tech Lead | `mcq_parser.dart` | **FIXED** (Commit `98fceac`) |
| **P1-2** | Live AI API Outage / Rate Limit Handling | Scenario AI Failures | `grading_pipeline.py` | **VERIFIED / SAFE** (Semantic fallback active) |
| **P1-3** | Prompt Injection in Student Submissions | Attacker | `grading_pipeline.py` | **VERIFIED / SAFE** (Regex guard & triage active) |
| **P1-4** | Malicious Executable Upload Attempt | Attacker | `submission_service.py` | **VERIFIED / SAFE** (Extension blacklist enforced) |
| **P1-5** | Duplicate File Submission Row in Exam Mode | Chaos Engineer | `exam_screen.dart`, `exams.py` | **MITIGATED** (Idempotent submission query) |

---

## P2 Medium (Looks bad or confusing, avoid during demo)

| ID | Title | Found By | Where | Status | Mitigation / Guidance |
|---|---|---|---|---|---|
| **P2-1** | Biometric Hardware Prompt on Laptop | Low-End User / First-Timer | `exam_screen.dart` | Open (Avoidable) | Click "Skip Biometric" if no Windows Hello camera |
| **P2-2** | Proctoring Toggles Not in Initial Wizard | Tech Lead | `assignment_creation_wizard.dart` | Open (Avoidable) | Configure from Assignment Detail Settings after create |
| **P2-3** | DevTools Docking Causes Anti-Cheat Strike | Demo Disasters | `exam_screen.dart` | Avoidable | Keep DevTools closed during student view |

---

## Work Order Summary
1. All P0 issues are **RESOLVED and TESTED** (Zero remaining P0 blockers).
2. All P1 issues are **RESOLVED or GUARDED** against live failure.
3. P2 items are documented with explicit instructions in the demo script.
