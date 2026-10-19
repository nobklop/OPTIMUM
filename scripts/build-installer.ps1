param(
  [Parameter(Mandatory=$true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
  [string]$Compiler = 'D:\OptimumTools\Inno Setup 6\ISCC.exe',
  [string]$FlutterSdk = 'D:\OptimumTools\flutter'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$packagePath = Join-Path $projectRoot "dist\OPTIMUM-$Version-windows-x64"
$stagePath = Join-Path $projectRoot ".data\installer-build\$Version"
$outputPath = Join-Path $projectRoot 'dist\installers'
if (-not (Test-Path -LiteralPath $Compiler)) { throw "Inno Setup compiler not found: $Compiler" }
$exe = Get-Item -LiteralPath (Join-Path $packagePath 'optimum.exe')
if ($exe.VersionInfo.ProductVersion.Split('+')[0] -ne $Version) { throw 'Package version mismatch' }
$installerPath = Join-Path $outputPath "OPTIMUM-$Version-Setup-x64.exe"
if (Test-Path -LiteralPath $installerPath) { throw 'Preserve existing installer; use a new build version' }
New-Item -ItemType Directory -Path $stagePath -Force | Out-Null
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
# libmpv is acquired from its upstream provider at installation time, with two hashes.
# Do not redistribute the prebuilt engine whose corresponding sources are unresolved.
Get-ChildItem -LiteralPath $packagePath | Where-Object Name -NotIn @('libmpv-2.dll','DEPENDENCIES.ru.md') | Copy-Item -Destination $stagePath -Recurse -Force
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsPath = & $vswhere -latest -products '*' -property installationPath
$redistRoot = Join-Path $vsPath 'VC\Redist\MSVC'
$redistVersion = Get-ChildItem -LiteralPath $redistRoot -Directory | Where-Object Name -Match '^14\.' | Sort-Object Name -Descending | Select-Object -First 1
$crt = Join-Path $redistVersion.FullName 'x64\Microsoft.VC143.CRT'
foreach ($name in @('msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll')) {
  $source = Join-Path $crt $name
  $signature = Get-AuthenticodeSignature -LiteralPath $source
  if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft') { throw "Invalid runtime signature: $name" }
  Copy-Item -LiteralPath $source -Destination $stagePath
}
$noticePath = Join-Path $stagePath 'NOTICES'
New-Item -ItemType Directory -Path $noticePath -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $FlutterSdk 'LICENSE') -Destination (Join-Path $noticePath 'Flutter-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $FlutterSdk 'bin\cache\artifacts\engine\windows-x64-release\license.windows_flutter.md') -Destination (Join-Path $noticePath 'Flutter-engine-LICENSE.md')
Copy-Item -LiteralPath (Join-Path $FlutterSdk 'bin\cache\pkg\sky_engine\LICENSE') -Destination (Join-Path $noticePath 'Flutter-engine-full-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $projectRoot 'client\assets\fonts\OFL.txt') -Destination (Join-Path $noticePath 'Manrope-OFL.txt')
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\INSTALLER.ru.md') -Destination (Join-Path $stagePath 'INSTALLATION.ru.md')
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\NATIVE_NOTICES.md') -Destination (Join-Path $noticePath 'NATIVE_NOTICES.md')
if (Test-Path -LiteralPath (Join-Path $packagePath 'webview_windows_plugin.dll')) {
  $nativePackages = Join-Path $projectRoot 'client\build\windows\x64\packages'
  Copy-Item -LiteralPath (Join-Path $nativePackages 'Microsoft.Web.WebView2\LICENSE.txt') -Destination (Join-Path $noticePath 'WebView2-loader-LICENSE.txt')
  Copy-Item -LiteralPath (Join-Path $nativePackages 'Microsoft.Windows.ImplementationLibrary\LICENSE') -Destination (Join-Path $noticePath 'WIL-LICENSE.txt')
  Copy-Item -LiteralPath (Join-Path $nativePackages 'Microsoft.Windows.ImplementationLibrary\ThirdPartyNotices.txt') -Destination (Join-Path $noticePath 'WIL-ThirdPartyNotices.txt')
}
if (Test-Path -LiteralPath (Join-Path $stagePath 'libmpv-2.dll')) { throw 'External engine must not be bundled' }
& $Compiler "/DAppVersion=$Version" "/DSourceDir=$stagePath" "/DOutputPath=$outputPath" (Join-Path $projectRoot 'packaging\windows\optimum.iss')
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed' }
$hash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$installerPath.sha256" -Value "$hash  $([IO.Path]::GetFileName($installerPath))" -Encoding ascii
Write-Output $installerPath
