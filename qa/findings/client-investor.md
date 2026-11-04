# Findings: Persona Client or Investor

Found by: persona-client-investor

## 1. What I Understood After 60 Seconds
ProfessorOS is an integrated academic evaluation operating system for higher-education universities. It solves three critical operational bottlenecks simultaneously: eliminating grading backlog using AI rubric evaluation grounded against teacher answers, preventing exam dishonesty through full-stack proctoring, and calculating OBE/CLO accreditation compliance automatically without tedious spreadsheet exports.

## 2. Five Questions I Would Ask After the Demo
1. **Accreditation Adoption:** Does the OBE mapping report match Washington Accord / PEC (Pakistan Engineering Council) formatting out of the box?
2. **AI Cost Structure:** How much does grading a 100-student midterm exam cost the university in LLM API tokens?
3. **Institutional LMS Integration:** Can ProfessorOS integrate with existing systems like Canvas or Moodle via LTI 1.3 standards?
4. **Proctoring Privacy Compliance:** Where are biometric verification hashes and webcam violation logs stored, and who has access to them?
5. **Human Override Rate:** In practice, what percentage of automated AI grades are adjusted by professors before final sign-off?

## 3. Decision Drivers
- **One thing that would make me say YES:** The live demonstration of SpeedGrader accurately scoring a complex CS essay against a 4-level rubric in 5 seconds while highlighting evidence from the student's text.
- **One thing that would make me say NO:** If an AI evaluation produced wildly inconsistent scores for identical submissions or if the exam screen crashed mid-attempt.

---

```
ID: CLI-001
Title: Unclear pricing / token usage transparency in Professor UI
Severity: P2 (demo-visible)
Where: frontend/lib/features/courses/presentation/assignment_detail_screen.dart
Steps to reproduce:
  1. Professor clicks "AI Grade All Submissions".
Expected: UI displays estimated tokens or notice that deterministic grading is free while LLM evaluation uses primary model quota.
Actual: Evaluation runs directly without showing token estimate.
Evidence: Line 465 in assignment_detail_screen.dart: aiGradeSubmission().
Suggested fix: Add a small badge: "Deterministic MCQs: Free | Written Questions: Llama 3.3".
Status: open
Verified how: UI inspection.
```
