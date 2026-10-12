[CmdletBinding()]
param([string]$Distribution = 'qfli-java-build')

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'web-dependencies.json') -Raw | ConvertFrom-Json
$dependency = $manifest.emsdk
$buildRoot = Join-Path $repoRoot 'native/build'
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
$archive = Join-Path $buildRoot $dependency.archive
if (-not (Test-Path -LiteralPath $archive)) {
    & curl.exe -4 --http1.1 --fail --location --retry 3 --retry-all-errors `
        --connect-timeout 15 --output $archive $dependency.url
    if ($LASTEXITCODE -ne 0) { throw 'Emsdk download failed.' }
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $dependency.sha256) {
    throw "Emsdk archive checksum mismatch: $archive"
}
$sdkRoot = Join-Path $buildRoot $dependency.directory
if (-not (Test-Path -LiteralPath (Join-Path $sdkRoot 'emsdk'))) {
    & tar.exe -xzf $archive -C $buildRoot
    if ($LASTEXITCODE -ne 0) { throw 'Emsdk extraction failed.' }
}
$wslRoot = (& wsl.exe -d $Distribution -- wslpath -a $sdkRoot).Trim()
if ($LASTEXITCODE -ne 0 -or -not $wslRoot.StartsWith('/')) { throw 'Cannot resolve Emsdk WSL path.' }
& wsl.exe -d $Distribution -- "$wslRoot/emsdk" install $dependency.version
if ($LASTEXITCODE -ne 0) { throw 'Emsdk installation failed.' }
& wsl.exe -d $Distribution -- "$wslRoot/emsdk" activate $dependency.version
if ($LASTEXITCODE -ne 0) { throw 'Emsdk activation failed.' }
