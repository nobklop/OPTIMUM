param([string]$Version = '0.3.0')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $projectRoot 'client\build\windows\x64\runner\Release'
if (-not (Test-Path -LiteralPath (Join-Path $sourcePath 'optimum.exe'))) { throw 'Build Windows release first' }
$destinationPath = Join-Path $projectRoot "dist\OPTIMUM-$Version-windows-x64"
if (Test-Path -LiteralPath $destinationPath) { throw 'Package already exists; preserve it and use another version' }
New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
Get-ChildItem -LiteralPath $sourcePath | Copy-Item -Destination $destinationPath -Recurse
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\WINDOWS_QUICKSTART.ru.md') -Destination (Join-Path $destinationPath 'README.ru.md')
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\DEPENDENCIES.md') -Destination (Join-Path $destinationPath 'DEPENDENCIES.ru.md')
$zipPath = "$destinationPath.zip"
Compress-Archive -LiteralPath $destinationPath -DestinationPath $zipPath
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$zipPath.sha256" -Value "$hash  $([IO.Path]::GetFileName($zipPath))" -Encoding ascii
Write-Output $zipPath
