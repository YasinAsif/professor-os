#!/bin/bash
echo "=== Starting ProfessorOS on Azure App Service ==="
cd "$(dirname "$0")/backend" || cd backend
exec python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
