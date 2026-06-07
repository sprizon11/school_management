# Apply Prisma migrations to Neon (cloud DB). Does NOT re-seed data.
# Usage:
#   $env:DATABASE_URL="postgresql://user:pass@ep-....neon.tech/neondb?sslmode=require"
#   .\scripts\migrate-cloud.ps1

param(
    [string]$DatabaseUrl = $env:DATABASE_URL
)

if (-not $DatabaseUrl) {
    Write-Host "ERROR: Set DATABASE_URL first." -ForegroundColor Red
    Write-Host ""
    Write-Host "Get it from Render -> Environment -> DATABASE_URL"
    Write-Host "OR Neon dashboard -> Connection string"
    Write-Host ""
    Write-Host '  $env:DATABASE_URL="postgresql://user:pass@host/neondb?sslmode=require"'
    Write-Host "  .\scripts\migrate-cloud.ps1"
    exit 1
}

if ($DatabaseUrl -notmatch '^(postgresql|postgres)://') {
    Write-Host "ERROR: DATABASE_URL must start with postgresql://" -ForegroundColor Red
    Write-Host "Do NOT use the Render API URL (https). That is only for Flutter."
    exit 1
}

$env:DATABASE_URL = $DatabaseUrl

$backend = Join-Path $PSScriptRoot "..\backend"
Push-Location $backend
try {
    Write-Host "Applying migrations to cloud database..." -ForegroundColor Cyan
    npx prisma migrate deploy
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Migrations applied successfully." -ForegroundColor Green
    }
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
