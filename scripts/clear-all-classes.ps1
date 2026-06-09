# Remove ALL classes and their students (students must be deleted first).
# Usage:
#   $env:DATABASE_URL="postgresql://..."
#   .\scripts\clear-all-classes.ps1

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
    Write-Host "Removing all classes and their students..." -ForegroundColor Cyan
    npx ts-node --compiler-options '{\"module\":\"CommonJS\"}' prisma/clear-all-classes.ts
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Done. All classes removed. Teachers and admin are unchanged." -ForegroundColor Green
}
finally {
    Pop-Location
}
