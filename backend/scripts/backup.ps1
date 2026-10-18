# ProfessorOS Database Backup Script (PowerShell)
# Usage: .\backend\scripts\backup.ps1 [-DbUrl <connection_string>] [-OutDir <output_directory>]

param(
    [string]$DbUrl = $env:DATABASE_URL,
    [string]$OutDir = "backend/backups"
)

if (-not $DbUrl) {
    Write-Error "DATABASE_URL environment variable is not defined and -DbUrl was not provided."
    exit 1
}

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputFile = Join-Path $OutDir "professor_os_backup_$Timestamp.dump"

Write-Host "Creating PostgreSQL custom-format database backup to $OutputFile..."
try {
    # Custom format (-Fc) allows compressed, parallel restoration with pg_restore
    pg_dump --dbname=$DbUrl --format=c --file=$OutputFile --verbose
    Write-Host "Backup successfully created: $OutputFile"
} catch {
    Write-Error "pg_dump failed: $_"
    exit 1
}

Write-Host ""
Write-Host "To verify and restore this backup to a scratch database:"
Write-Host "1. createdb -h localhost -U postgres professor_os_restore_verify"
Write-Host "2. pg_restore -h localhost -U postgres -d professor_os_restore_verify -v $OutputFile"
Write-Host "3. dropdb -h localhost -U postgres professor_os_restore_verify"
