# Remove seeded demo students/teachers; keep manually added records.
# Usage:
#   $env:DATABASE_URL="postgresql://..."
#   .\scripts\clear-demo-data.ps1

param(
    [string]$DatabaseUrl = $env:DATABASE_URL
)

if (-not $DatabaseUrl) {
    Write-Host "ERROR: Set DATABASE_URL first." -ForegroundColor Red
    Write-Host '  $env:DATABASE_URL="postgresql://user:pass@host/neondb?sslmode=require"'
    exit 1
}

if ($DatabaseUrl -notmatch '^(postgresql|postgres)://') {
    Write-Host "ERROR: DATABASE_URL must be your Neon Postgres connection string." -ForegroundColor Red
    exit 1
}

$env:DATABASE_URL = $DatabaseUrl

$backend = Join-Path $PSScriptRoot "..\backend"
Push-Location $backend
try {
    Write-Host "Clearing demo students and teachers..." -ForegroundColor Cyan
    npx ts-node --compiler-options '{\"module\":\"CommonJS\"}' prisma/clear-demo.ts
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Done. Only your manually added students/teachers remain." -ForegroundColor Green
}
finally {
    Pop-Location
}
