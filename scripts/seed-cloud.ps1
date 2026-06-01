# Run once after Neon DB is created. Usage:
#   $env:DATABASE_URL="postgresql://..."
#   .\scripts\seed-cloud.ps1

param(
    [string]$DatabaseUrl = $env:DATABASE_URL
)

if (-not $DatabaseUrl) {
    Write-Host "ERROR: Set DATABASE_URL first." -ForegroundColor Red
    Write-Host '  $env:DATABASE_URL="postgresql://user:pass@host/db?sslmode=require"'
    exit 1
}

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
