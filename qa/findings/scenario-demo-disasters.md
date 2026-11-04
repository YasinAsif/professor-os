# Findings: Scenario Demo Disasters

Found by: scenario-demo-disasters

```
ID: DIS-001
Title: Double-clicking submit button during exam completion
Severity: P1 (demo-visible)
Found by: scenario-demo-disasters
Where: frontend/lib/features/courses/presentation/exam_screen.dart
Steps to reproduce:
  1. Student double-clicks or rapidly clicks "Submit Exam" button.
Expected: Only one submission request is sent; subsequent clicks are blocked.
Actual: _submitting boolean flag and _submitted check prevent multi-click races.
Evidence: exam_screen.dart line 793: if (_submitted || _submitting) return;
Status: fixed
Verified how: Verified in exam_screen.dart.
```

```
ID: DIS-002
Title: Accidental F12 / DevTools launch during student exam
Severity: P2 (avoidable)
Found by: scenario-demo-disasters
Where: frontend/lib/features/courses/presentation/exam_screen.dart
Steps to reproduce:
  1. Presenter accidentally presses F12 while showing student exam screen.
Expected: Anti-cheat window blur detector flags tab switch.
Actual: Screen detects focus loss and presents warning banner / strike count increment.
Evidence: ProctorDetector window blur listener.
Suggested fix: Presenter should refrain from opening DevTools during the student exam view.
Status: avoidable
Verified how: Documented in presenter notes.
```
