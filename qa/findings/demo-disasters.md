# Findings: Scenario Demo Disasters

Found by: scenario-demo-disasters

## Live Demo Disasters & Recovery Summary

| Disaster | Probability | Impact | Plan B Recovery Action | Recovery Time |
|---|---|---|---|---|
| **Venue Wi-Fi Disconnect** | High | High | Switch to paired 4G mobile hotspot or run local server (`localhost:8000`) | < 30s |
| **DevTools Pressed Accidentally (F12)** | Medium | Low | Proctor strike logged; use as positive proof of anti-cheat system | 0s (Demonstration) |
| **Rapid Double-Click on Submit** | Medium | Low | Button disabled immediately; idempotent DB query prevents duplication | 0s (Native protection) |
| **Time Cut from 10m to 5m** | High | Medium | Execute 5-Minute Defense Plan: Wizard -> Student Exam -> SpeedGrader | 0s (Prepared script) |
| **Projector Resolution 1024x768** | Medium | Medium | Responsive Flutter layout reflows; use `Ctrl + -` to zoom to 80% if needed | < 10s |

---

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
