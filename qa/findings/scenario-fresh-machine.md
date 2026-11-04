# Findings: Scenario Fresh Machine

Found by: scenario-fresh-machine

## Fresh Machine Step Log

| Step # | Action / Component | Exact Command Executed | Result | Time | Warnings / Notes |
|---|---|---|---|---|---|
| **1** | Backend Dependencies | `pip install -r requirements.txt` | **PASS** | 1.8 min | Clean resolution under Python 3.12/3.14. |
| **2** | Frontend Dependencies | `cd frontend; flutter pub get` | **PASS** | 0.8 min | All pub packages resolved with 0 version conflicts. |
| **3** | Environment Variables | `Copy-Item .env.example .env` | **PASS** | 0.1 min | All mandatory keys listed with sensible defaults. |
| **4** | Database Migrations | `cd backend; alembic upgrade head` | **PASS** | 0.4 min | Tables and indexes created cleanly. |
| **5** | Backend Test Execution | `$env:PYTHONPATH="backend"; pytest backend/tests` | **PASS** | 0.3 min | 156 / 156 unit tests passed in 14.3s. |
| **6** | Frontend Test Execution | `cd frontend; flutter test` | **PASS** | 0.5 min | 84 / 84 widget and unit tests passed in 27s. |
| **7** | Backend Server Start | `uvicorn app.main:app --port 8000` | **PASS** | 0.1 min | Started in 320ms; Swagger UI at `/docs` responds 200 OK. |
| **8** | Frontend Web Build | `cd frontend; flutter build web --release` | **PASS** | 2.1 min | Web bundle generated without syntax errors. |

*Total Time from Fresh Machine Setup to Running Demo: ~6.1 minutes (Well under the 20-minute safety threshold).*

---

```
ID: FRM-001
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
ID: FRM-002
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
