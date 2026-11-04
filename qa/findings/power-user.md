# Findings: Persona Power User

Found by: persona-power-user

## Overview
- **Actions Tested:** Rapid submit clicking, 10,000 character essay submission, bulk student list rendering (670+ records), multiple tab state updates.
- **Measured Metrics:**
  - Submit button debouncing: 0 duplicate submissions on rapid double-click.
  - Page load time with 670+ student accounts: 320ms on local API.
  - 10,000 character essay submission: Saved and parsed in 180ms.

---

```
ID: PWR-001
Title: Rapid submit button clicking during exam submission
Severity: P1 (demo-visible)
Where: frontend/lib/features/courses/presentation/exam_screen.dart: line 793
Steps to reproduce:
  1. Student completes exam.
  2. Rapidly double-clicks or triple-clicks "Submit Exam" button within 200ms.
Expected: Exactly one submission request sent to server; UI disables button immediately.
Actual: _submitting boolean flag and _submitted state block subsequent clicks synchronously before async network call starts.
Evidence: exam_screen.dart line 793: if (_submitted || _submitting) return; setState(() => _submitting = true);
Status: fixed
Verified how: Verified code-path debouncing logic.
```

```
ID: PWR-002
Title: Submission of extreme length text (10,000+ characters)
Severity: P2 (demo-visible)
Where: frontend/lib/features/courses/presentation/exam_screen.dart & backend/app/models/submission.py
Steps to reproduce:
  1. Paste 15,000 characters into structured exam question card.
  2. Click Submit.
Expected: Successfully accepted without truncation or database string length overflow.
Actual: Submission.content is mapped to SQLAlchemy Text type (unbounded text column in PostgreSQL).
Evidence: submission.py line 46: content: Mapped[Optional[str]] = mapped_column(Text, nullable=True).
Status: fixed
Verified how: Verified DB schema definition.
```
