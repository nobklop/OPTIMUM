param(
  [string[]]$Versions = @('0.1.0','0.1.1','0.2.0','0.2.1'),
  [ValidatePattern('^[a-z0-9-]+$')][string]$TestName = 'installer-smoke'
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$rootInfo = Get-Item -LiteralPath $projectRoot
if ($rootInfo.LinkType) { $projectRoot = $rootInfo.ResolveLinkTarget($true).FullName }
$installPath = [IO.Path]::GetFullPath((Join-Path $projectRoot ".data\$TestName\OPTIMUM"))
if (-not $installPath.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Test path escaped workspace' }
$registryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{929641B1-6391-4F35-B470-CC67E7B19E49}_is1'
if (Test-Path -LiteralPath $registryPath) { throw 'An installed OPTIMUM is registered; use a clean test user to preserve it' }
if (Test-Path -LiteralPath $installPath) { throw 'Preserve previous test output before another run' }
$artifactPath = Join-Path $projectRoot 'artifacts\installer-tests'
New-Item -ItemType Directory -Path $artifactPath -Force | Out-Null
$records = @()
foreach ($version in $Versions) {
  if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid version' }
  $setup = Join-Path $projectRoot "dist\installers\OPTIMUM-$version-Setup-x64.exe"
  $log = Join-Path $artifactPath "$version-install.log"
  $arguments = @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/NOAUTOLAUNCH=1','/NOSHORTCUTS=1',"/DIR=`"$installPath`"","/LOG=`"$log`"")
  $process = Start-Process -FilePath $setup -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
  if ($process.ExitCode -ne 0) { throw "Installer $version failed: $($process.ExitCode); see $log" }
  $exe = Join-Path $installPath 'optimum.exe'
  if ((Get-Item -LiteralPath $exe).VersionInfo.ProductVersion.Split('+')[0] -ne $version) { throw 'Installed version mismatch' }
  $expected = Join-Path $projectRoot ".data\installer-build\$version"
  foreach ($file in Get-ChildItem -LiteralPath $expected -File -Recurse) {
    $relative = [IO.Path]::GetRelativePath($expected, $file.FullName)
    $actual = Join-Path $installPath $relative
    if ((Get-FileHash -LiteralPath $actual).Hash -ne (Get-FileHash -LiteralPath $file.FullName).Hash) { throw "Installed payload mismatch: $relative" }
  }
  $engine = (Get-FileHash -LiteralPath (Join-Path $installPath 'libmpv-2.dll')).Hash.ToLowerInvariant()
  if ($engine -ne '0a5a0b476866c91a639a4e511e8153968f8fa23564461b0aa09acdba816164a4') { throw 'Engine checksum mismatch' }
  if ((Get-ItemProperty -LiteralPath $registryPath).DisplayVersion -ne $version) { throw 'Uninstall registration mismatch' }
  $records += @{version=$version; payload='all hashes matched'; engine_sha256=$engine; installer_exit=$process.ExitCode}
  Write-Output "Install/upgrade passed: $version"
}
if ($Versions.Count -gt 1) {
  $oldSetup = Join-Path $projectRoot "dist\installers\OPTIMUM-$($Versions[0])-Setup-x64.exe"
  $process = Start-Process -FilePath $oldSetup -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/NOAUTOLAUNCH=1','/NOSHORTCUTS=1' -WindowStyle Hidden -PassThru -Wait
  if ($process.ExitCode -eq 0) { throw 'Downgrade was not blocked' }
  if ((Get-Item (Join-Path $installPath 'optimum.exe')).VersionInfo.ProductVersion.Split('+')[0] -ne $Versions[-1]) { throw 'Downgrade modified app' }
  Write-Output 'Downgrade blocked; installed app unchanged'
}
$testProcess = Start-Process -FilePath (Join-Path $installPath 'optimum.exe') -WorkingDirectory $installPath -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 4
$testProcess.Refresh()
if ($testProcess.HasExited -or -not $testProcess.Responding) { throw 'Installed app did not start/respond' }
Stop-Process -Id $testProcess.Id
$libraryPath = Join-Path $env:APPDATA 'app.optimum\OPTIMUM\library.db'
$hadLibrary = Test-Path -LiteralPath $libraryPath
$uninstall = Start-Process -FilePath (Join-Path $installPath 'unins000.exe') -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -WindowStyle Hidden -PassThru -Wait
if ($uninstall.ExitCode -ne 0) { throw 'Uninstall failed' }
Start-Sleep -Seconds 1
if (Test-Path -LiteralPath (Join-Path $installPath 'optimum.exe')) { throw 'App executable survived uninstall' }
if (Test-Path -LiteralPath $registryPath) { throw 'Uninstall registration survived' }
if ($hadLibrary -and -not (Test-Path -LiteralPath $libraryPath)) { throw 'User library was removed' }
@{versions=$records; downgrade_blocked=($Versions.Count -gt 1); launch='responding'; uninstall_exit=$uninstall.ExitCode; library_preserved=$hadLibrary} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $artifactPath 'results.json') -Encoding utf8
Write-Output 'Installed app launch, uninstall, library preservation passed'
