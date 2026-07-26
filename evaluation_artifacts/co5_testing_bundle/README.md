# CO-5 Testing Bundle (Evaluation Ready)

This folder is prepared for FYP evaluation criteria CO-5:

1. Validation (Field + Code level) - 2 marks
2. Test case verification (Automated + Manual) - 3 marks
3. UI look and task flow - 2 marks

## Folder Layout

- docs/
  - CO5_TEST_PLAN.md
  - TEST_CASE_MATRIX.csv
  - UI_MANUAL_CHECKLIST.md
- outputs/
  - reports/
  - screenshots/
  - videos/
- scripts/
  - collect_evidence.py
  - record_demo_video.py

## Quick Execution

From project root:

1. Run existing tests and regenerate report:
   - cd testing_assignment
   - pytest -v --html=report.html --self-contained-html

2. Collect report and screenshots into this bundle:
   - python evaluation_artifacts/co5_testing_bundle/scripts/collect_evidence.py

3. Record evaluation demo video (saved in outputs/videos):
   - python evaluation_artifacts/co5_testing_bundle/scripts/record_demo_video.py

## Slides Content You Can Use

1. outputs/reports/report.html (automated evidence)
2. outputs/screenshots/* (positive/negative/boundary proof)
3. outputs/videos/co5_demo_full.webm (demo playback)
4. docs/TEST_CASE_MATRIX.csv (traceability table)
5. docs/UI_MANUAL_CHECKLIST.md (manual verification proof)
