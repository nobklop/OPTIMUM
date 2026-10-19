param([string]$Flutter = 'D:\OptimumTools\flutter\bin\flutter.bat')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location (Join-Path $projectRoot 'client')
try {
    & $Flutter analyze --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed' }
    & $Flutter test --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed' }
} finally { Pop-Location }
Push-Location (Join-Path $projectRoot 'backend')
try {
    & '.\.venv\Scripts\python.exe' -m ruff check app tests
    if ($LASTEXITCODE -ne 0) { throw 'Backend lint failed' }
    & '.\.venv\Scripts\python.exe' -m pytest -q
    if ($LASTEXITCODE -ne 0) { throw 'Backend tests failed' }
} finally { Pop-Location }
