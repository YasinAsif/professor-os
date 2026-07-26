# CO-5 Test Plan (Rubric-Aligned)

## Objective
Generate direct evidence for the 7 marks under CO-5.

## Coverage Mapping

### 1) Validation (2 marks)
- Backend field-level validation:
  - Email format
  - Password minimum length
  - Required fields
  - Numeric ranges and enums
- Frontend form validation:
  - Login, register, reset password forms
  - Required, email, and password validator checks

### 2) Test Case Verification (3 marks)
- Automated UI cases with Selenium (auth + admin semester flows)
- Positive, negative, and boundary scenarios
- Final HTML report and screenshots as proof
- Manual checklist for canvas-heavy interactions that are hard to assert purely with DOM locators

### 3) Look and Feel + Flow (2 marks)
- Validate user journey clarity:
  - Login to dashboard
  - Navigation to core modules
  - Form error visibility and recovery
- Capture desktop screenshots and a short demo video

## Deliverables
- Automated report: outputs/reports/report.html
- Screenshots: outputs/screenshots/
- Video: outputs/videos/co5_demo_full.webm
- Traceability matrix: docs/TEST_CASE_MATRIX.csv
- Manual checklist: docs/UI_MANUAL_CHECKLIST.md

## Exit Criteria
- Report is regenerated and internally consistent
- No placeholder or simulated assertions in final showcased suite
- Every rubric item is mapped to at least one artifact
