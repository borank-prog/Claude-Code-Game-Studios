param(
  [switch]$WithTests
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$flutterApp = Join-Path $root "flutter_app"
$functions = Join-Path $root "functions"

Write-Host "[1/3] Flutter analyze" -ForegroundColor Cyan
Push-Location $flutterApp
flutter analyze
if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed with code $LASTEXITCODE" }
if ($WithTests) {
  Write-Host "[2/3] Flutter test" -ForegroundColor Cyan
  flutter test
  if ($LASTEXITCODE -ne 0) { throw "flutter test failed with code $LASTEXITCODE" }
}
Pop-Location

Write-Host "[3/3] Functions lint" -ForegroundColor Cyan
Push-Location $functions
npm run lint
if ($LASTEXITCODE -ne 0) { throw "functions lint failed with code $LASTEXITCODE" }
Pop-Location

Write-Host "Smoke checks completed successfully." -ForegroundColor Green
