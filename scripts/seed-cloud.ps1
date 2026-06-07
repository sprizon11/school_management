# Run once after Neon DB is created. Usage:
#   $env:DATABASE_URL="postgresql://..."
#   .\scripts\seed-cloud.ps1

param(
    [string]$DatabaseUrl = $env:DATABASE_URL
)

if (-not $DatabaseUrl) {
    Write-Host "ERROR: Set DATABASE_URL first." -ForegroundColor Red
    Write-Host '  $env:DATABASE_URL="postgresql://user:pass@host/neondb?sslmode=require"'
    Write-Host "Copy the value from Render -> Environment -> DATABASE_URL (or Neon dashboard)."
    exit 1
}

if ($DatabaseUrl -notmatch '^(postgresql|postgres)://') {
    Write-Host "ERROR: DATABASE_URL must be your Neon Postgres connection string." -ForegroundColor Red
    Write-Host "You set: $DatabaseUrl"
    Write-Host ""
    Write-Host "NOT the Render API URL (https://...onrender.com). That is only for the Flutter app."
    Write-Host ""
    Write-Host "Copy DATABASE_URL from: Render -> Environment (starts with postgresql://)"
    Write-Host "Then run (quotes required):"
    Write-Host '  $env:DATABASE_URL="postgresql://neondb_owner:PASSWORD@ep-....neon.tech/neondb?sslmode=require"'
    Write-Host '  .\scripts\seed-cloud.ps1'
    exit 1
}

# Use Neon URL for this run (Prisma also loads backend/.env with localhost)
$env:DATABASE_URL = $DatabaseUrl

$backend = Join-Path $PSScriptRoot "..\backend"
Push-Location $backend
try {
    Write-Host "Running migrations..." -ForegroundColor Cyan
    npx prisma migrate deploy
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host "Seeding demo data (~250 students)..." -ForegroundColor Cyan
    npm run db:seed
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host "Done! Demo accounts:" -ForegroundColor Green
    Write-Host "  admin@school.demo   / Admin@123"
    Write-Host "  teacher@school.demo / Admin@123"
    Write-Host "  parent@school.demo  / Admin@123"
}
finally {
    Pop-Location
}
