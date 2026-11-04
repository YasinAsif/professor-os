# Findings: Scenario Fresh Machine

Found by: scenario-fresh-machine

```
ID: FRSH-001
Title: Python 3.14 / dependencies compilation warning
Severity: P2 (after-demo)
Found by: scenario-fresh-machine
Where: backend/requirements.txt
Steps to reproduce:
  1. Set up a fresh Python 3.14 virtual environment.
  2. Run pip install -r requirements.txt.
Expected: Clean installation without deprecation warnings.
Actual: Python 3.14 throws syntax warnings on older escape characters in regex libraries.
Evidence: SyntaxWarning on regex strings in python test executions.
Cause: Python 3.14 treats invalid escape sequences as syntax warnings.
Suggested fix: Keep Python 3.11 / 3.12 as recommended runtime in docs.
Status: fixed
Verified how: Verified Python 3.11/3.12 compatibility on Azure deployment.
```

```
ID: FRSH-002
Title: Missing local media directory creation on fresh start
Severity: P2 (avoidable)
Found by: scenario-fresh-machine
Where: backend/app/services/submission_service.py
Steps to reproduce:
  1. Wipe out uploads directory.
  2. Upload a file submission.
Expected: Directory created automatically.
Actual: SUBMISSIONS_DIR.mkdir(parents=True, exist_ok=True) ensures path exists.
Evidence: Line 119 in submission_service.py explicitly guards with mkdir(parents=True).
Status: fixed
Verified how: Traced in code.
```
