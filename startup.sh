#!/bin/bash
echo "=== Starting ProfessorOS on Azure App Service ==="
cd "$(dirname "$0")/backend" || cd backend
python seed_dev.py || true
python seed_curriculum_and_students.py || true
exec python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
