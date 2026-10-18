# ProfessorOS System Scope & Architectural Boundaries (Item 1.16)

This document establishes authoritative architectural boundaries between assessment flows in ProfessorOS.

## 1. Summative Proctored Exams (`exam_attempts`)
- **Purpose**: High-stakes, timed summative assessments (midterms, finals, proctored quizzes).
- **Proctoring**: Full real-time telemetry (focus-loss deduplication, offline event queues, server-side heartbeat tracking, automatic strike calculation, server-enforced autosubmit).
- **Storage**: Table `exam_attempts`, `exam_violations`, `exam_audit_logs`.
- **Authorization & Workflow**: Server-enforced time windows, deadline capping, attempt locks, TA delegation rules, and atomic submit endpoints.

## 2. Formative OBE Quizzes (`student_quiz_attempts`)
- **Purpose**: Low-stakes, in-class practice and Outcome-Based Education (OBE) Bloom taxonomy calibration.
- **Proctoring Classification**: Explicitly **unproctored / formative**.
- **Behavior**: Does not run fullscreen proctoring, background heartbeat daemons, or server-side anti-cheat disqualification. Tab-switch events are treated as client telemetry diagnostics only.
- **Frontend Presentation**: UI clearly marks OBE Quizzes as formative assessments without making false automated proctoring claims.
