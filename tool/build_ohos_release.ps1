[CmdletBinding()]
param(
    [string]$FlutterSdk
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $FlutterSdk) {
    $properties = Join-Path $projectRoot 'ohos/local.properties'
    $sdkLine = Get-Content -LiteralPath $properties |
        Where-Object { $_ -match '^flutter\.sdk=' } | Select-Object -First 1
    if (-not $sdkLine) { throw 'Pass -FlutterSdk or configure flutter.sdk in ohos/local.properties.' }
    $FlutterSdk = ($sdkLine -replace '^flutter\.sdk=', '').Replace('\\', '\')
}
$dart = Join-Path $FlutterSdk 'bin/cache/dart-sdk/bin/dart.exe'
$flutterTools = Join-Path $FlutterSdk 'bin/cache/flutter_tools.snapshot'
if (-not (Test-Path -LiteralPath $dart) -or -not (Test-Path -LiteralPath $flutterTools)) {
    throw "Flutter SDK tools are missing under $FlutterSdk."
}

Push-Location $projectRoot
try {
    # Refresh even when an earlier build manually selected an isolated core snapshot.
    & $dart $flutterTools pub get
    if ($LASTEXITCODE -ne 0) { throw 'Dependency refresh failed.' }

    $configPath = Join-Path $projectRoot '.dart_tool/package_config.json'
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    $configUri = [Uri]::new($configPath)
    $expectedCore = [IO.Path]::GetFullPath((Join-Path $projectRoot '../qflistudio-core'))
    $expectedPackages = @{
        qfli_studio_core = $expectedCore
        re_editor = Join-Path $expectedCore 'vendor/re_editor'
    }
    foreach ($name in $expectedPackages.Keys) {
        $package = $config.packages | Where-Object { $_.name -eq $name } | Select-Object -First 1
        if (-not $package) { throw "Dependency $name is missing from package_config.json." }
        $actual = [IO.Path]::GetFullPath([Uri]::new($configUri, $package.rootUri).LocalPath).TrimEnd('\', '/')
        $expected = [IO.Path]::GetFullPath($expectedPackages[$name]).TrimEnd('\', '/')
        if (-not $actual.Equals($expected, [StringComparison]::OrdinalIgnoreCase)) {
            throw "$name resolves to $actual; expected current shared source at $expected."
        }
    }
    Write-Host "Building OHOS release with shared core: $expectedCore"
    & $dart $flutterTools build hap --release --no-pub --target lib/main.dart --target-platform ohos-arm64
    if ($LASTEXITCODE -ne 0) { throw 'OHOS release build failed.' }
    $hap = Join-Path $projectRoot 'build/ohos/hap/entry-default-signed.hap'
    if (-not (Test-Path -LiteralPath $hap)) { throw 'The signed production HAP is missing.' }
    Write-Host "Signed HAP: $hap"
} finally {
    Pop-Location
}
