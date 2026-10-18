#!/usr/bin/env bash
# ProfessorOS Database Backup Script (Bash)
# Usage: ./backend/scripts/backup.sh [database_url] [output_directory]

set -euo pipefail

DB_URL="${1:-${DATABASE_URL:-}}"
OUT_DIR="${2:-backend/backups}"

if [ -z "$DB_URL" ]; then
    echo "Error: DATABASE_URL environment variable is not defined and no argument was provided." >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="$OUT_DIR/professor_os_backup_$TIMESTAMP.dump"

echo "Creating PostgreSQL custom-format database backup to $OUTPUT_FILE..."
pg_dump --dbname="$DB_URL" --format=c --file="$OUTPUT_FILE" --verbose
echo "Backup successfully created: $OUTPUT_FILE"

echo ""
echo "To verify and restore this backup to a scratch database:"
echo "1. createdb -h localhost -U postgres professor_os_restore_verify"
echo "2. pg_restore -h localhost -U postgres -d professor_os_restore_verify -v $OUTPUT_FILE"
echo "3. dropdb -h localhost -U postgres professor_os_restore_verify"
