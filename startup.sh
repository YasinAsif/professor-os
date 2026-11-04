#!/bin/bash
echo "=== Starting ProfessorOS on Azure App Service ==="
cd "$(dirname "$0")/backend" || cd backend

echo "Running database migrations (max 15s)..."
timeout 15s python -m alembic upgrade head || echo "Alembic step completed or skipped"

echo "Ensuring seed users (max 15s)..."
timeout 15s python seed_dev.py || echo "Seed dev step completed or skipped"

echo "Seeding clean demo showcase data (4 courses & complete OBE assessments)..."
python seed_demo_showcase.py || echo "Demo seed step completed or skipped"

PORT="${WEBSITES_PORT:-${PORT:-8000}}"
echo "Starting Uvicorn on port $PORT..."
exec python -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT"
