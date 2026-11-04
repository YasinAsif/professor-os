# Findings: Persona Examiner

Found by: persona-examiner

## Assessment of Project Claims vs Evidence

- **Claim 1: "Automated AI Rubric Evaluation"**
  - *Evidence:* Fully verified. Ground truth is injected via `<teacher_reference_answer>` in prompt; evaluated across 4-tier rubric criteria.
  - *Status:* **Answerable with Strong Code Evidence.**
- **Claim 2: "Zero-Trust Anti-Cheat Proctoring"**
  - *Evidence:* Verified. Pointer lock, tab blur detection, copy-paste block, and biometric checks integrated into `ExamScreen`.
  - *Status:* **Answerable with Live Demonstration.**
- **Claim 3: "Deterministic MCQ Instant Grading"**
  - *Evidence:* Verified. Python regex/dict parser compares against 0-indexed correct key in sub-millisecond execution without LLM dependency.
  - *Status:* **Answerable with Ground-Truth Test Suite.**

---

```
ID: EXM-001
Title: Discrepancy between teacher ground truth and subjective LLM interpretation
Severity: P1 (demo-visible)
Where: backend/app/services/grading_pipeline.py: SYSTEM_GRADING_PROMPT
Steps to reproduce:
  1. Student submits technically valid answer using terminology slightly different from teacher reference.
Expected: LLM objectively evaluates conceptual correctness against rubric criteria without being dogmatic.
Actual: Prompt enforces: "Evaluate student accuracy, technical correctness, and conceptual completeness strictly against these reference answers and rubric definitions."
Evidence: Line 260 in grading_pipeline.py.
Status: fixed
Verified how: Verified rubric evaluation tests.
```

```
ID: EXM-002
Title: Justification for Washington Accord / PEC OBE Mapping formula
Severity: P2 (demo-visible)
Where: backend/app/services/analytics_service.py
Steps to reproduce:
  1. Examiner asks: "Show me how CLO attainment is mathematically calculated from assignment weights."
Expected: Documented formula: Attainment % = sum(score_i * weight_i) / sum(max_marks_i * weight_i) * 100.
Actual: Formula implemented in analytics_service.py and tested in test_analytics_reconciliation.py.
Evidence: test_analytics_reconciliation.py.
Status: fixed
Verified how: Tested in backend suite.
```
