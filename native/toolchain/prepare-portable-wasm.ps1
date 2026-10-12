[CmdletBinding()]
param(
    [string]$DownloadDirectory,
    [switch]$IncludeCompiler
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (!$DownloadDirectory) {
    $DownloadDirectory = Join-Path $repoRoot 'native/build/portable-deps'
}
$DownloadDirectory = [IO.Path]::GetFullPath($DownloadDirectory)
$manifest = Get-Content (Join-Path $PSScriptRoot 'portable-dependencies.json') -Raw | ConvertFrom-Json
$names = @('wasiSdk', 'wasmedge', 'fmt', 'spdlog')
if ($IncludeCompiler) { $names += 'llvm22' }
$curl = (Get-Command curl -CommandType Application -ErrorAction Stop).Source
$tar = (Get-Command tar -CommandType Application -ErrorAction Stop).Source
New-Item -ItemType Directory -Path $DownloadDirectory -Force | Out-Null

foreach ($name in $names) {
    $dependency = $manifest.$name
    $archive = Join-Path $DownloadDirectory $dependency.archive
    $source = Join-Path $DownloadDirectory $dependency.directory
    if (!(Test-Path -LiteralPath $archive -PathType Leaf)) {
        $temporary = "$archive.$([Guid]::NewGuid().ToString('N')).partial"
        try {
            & $curl -fL --retry 2 --retry-all-errors --connect-timeout 15 --max-time 600 `
                -o $temporary $dependency.url
            if ($LASTEXITCODE -ne 0) { throw "Download failed: $($dependency.url)" }
            $hash = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($hash -ne $dependency.sha256) { throw "Checksum mismatch: $($dependency.archive)" }
            Move-Item -LiteralPath $temporary -Destination $archive
        } finally {
            if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
        }
    }
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $dependency.sha256) {
        throw "Checksum mismatch in existing archive: $archive"
    }
    if (!(Test-Path -LiteralPath $source -PathType Container)) {
        & $tar -xzf $archive -C $DownloadDirectory
        if ($LASTEXITCODE -ne 0) { throw "Extraction failed: $archive" }
    }
    Write-Host "Verified $name : $source"
}
