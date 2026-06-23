# Remove ALL classes, ALL teachers, and all students (students block class deletion).
# Usage:
#   $env:DATABASE_URL="postgresql://..."
#   .\scripts\clear-all-classes-and-teachers.ps1

param(
    [string]$DatabaseUrl = $env:DATABASE_URL
)

if (-not $DatabaseUrl) {
    Write-Host "ERROR: Set DATABASE_URL first." -ForegroundColor Red
    Write-Host '  $env:DATABASE_URL="postgresql://user:pass@host/neondb?sslmode=require"'
    exit 1
}

if ($DatabaseUrl -notmatch '^(postgresql|postgres)://') {
    Write-Host "ERROR: DATABASE_URL must be your Postgres connection string." -ForegroundColor Red
    exit 1
}

$env:DATABASE_URL = $DatabaseUrl

$backend = Join-Path $PSScriptRoot "..\backend"
Push-Location $backend
try {
    Write-Host "Removing all classes, teachers, and students..." -ForegroundColor Cyan
    npx ts-node --compiler-options '{\"module\":\"CommonJS\"}' prisma/clear-all-classes-and-teachers.ts
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Done. Admin accounts were kept." -ForegroundColor Green
}
finally {
    Pop-Location
}
