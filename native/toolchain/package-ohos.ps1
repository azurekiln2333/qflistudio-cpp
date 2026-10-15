# Package executable ELF files as installed native libraries. The resource ZIP
# contains the sysroot, headers, link-time libraries and portable configuration.
# Artifact validation does not establish that generated code can run in an app.
[CmdletBinding()]
param(
    [string]$ToolchainDirectory,
    [string]$ProjectRoot = (Join-Path $PSScriptRoot '../..'),
    [string]$NativeSdk = 'D:/ProgramFiles/Huawei/DevEco Studio/sdk/default/openharmony/native',
    [string]$ExecutorSource,
    [ValidateSet('arm64-v8a', 'x86_64')]
    [string]$TargetArchitecture = 'arm64-v8a'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$cpu = if ($TargetArchitecture -eq 'arm64-v8a') { 'aarch64' } else { 'x86_64' }
$expectedMachine = if ($TargetArchitecture -eq 'arm64-v8a') { 183 } else { 62 }
$expectedTriple = "$cpu-unknown-linux-ohos"

if (-not $ToolchainDirectory) {
    $matching = @()
    foreach ($candidate in (Get-ChildItem (Join-Path $PSScriptRoot '../build') -Directory -Filter 'toolchain-ohos-*')) {
        $candidateManifest = Join-Path $candidate.FullName 'toolchain.json'
        if (-not (Test-Path -LiteralPath $candidateManifest -PathType Leaf)) { continue }
        try {
            $parsed = Get-Content -LiteralPath $candidateManifest -Raw | ConvertFrom-Json
            if ($parsed.targetTriple -eq $expectedTriple -and
                (Test-Path -LiteralPath (Join-Path $candidate.FullName 'bin/clang') -PathType Leaf)) {
                $matching += $candidate
            }
        } catch { continue }
    }
    if ($matching.Count -eq 0) { throw "No packaged $expectedTriple toolchain; run package-llvm.ps1 first." }
    $selected = $matching | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($matching.Count -gt 1) { Write-Host "Selecting newest matching toolchain: $($selected.FullName)" }
    $ToolchainDirectory = $selected.FullName
}
if (-not $ExecutorSource) { $ExecutorSource = Join-Path $PSScriptRoot 'ohos-executor.c' }
$ToolchainDirectory = [IO.Path]::GetFullPath($ToolchainDirectory)
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$ExecutorSource = [IO.Path]::GetFullPath($ExecutorSource)
$NativeSdk = [IO.Path]::GetFullPath($NativeSdk)

function Require-File {
    param([string]$File)
    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { throw "Required file does not exist: $File" }
}

$readelf = Join-Path $NativeSdk 'llvm/bin/llvm-readelf.exe'
$sdkCompiler = Join-Path $NativeSdk 'llvm/bin/clang.exe'
foreach ($file in @($readelf, $sdkCompiler, $ExecutorSource, (Join-Path $ToolchainDirectory 'toolchain.json'))) {
    Require-File $file
}

function Inspect-Elf {
    param([string]$File, [bool]$Executable)
    Require-File $File
    $bytes = [IO.File]::ReadAllBytes($File)
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x7f -or
        [Text.Encoding]::ASCII.GetString($bytes, 1, 3) -ne 'ELF' -or
        $bytes[4] -ne 2 -or $bytes[5] -ne 1 -or
        [BitConverter]::ToUInt16($bytes, 16) -ne 3 -or
        [BitConverter]::ToUInt16($bytes, 18) -ne $expectedMachine) {
        throw "Expected a $TargetArchitecture 64-bit little-endian ET_DYN ELF: $File"
    }
    $dynamic = & $readelf --dynamic $File
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect ELF dependencies: $File" }
    $needed = @($dynamic | ForEach-Object {
        if ($_ -match '\(NEEDED\).*\[([^\]]+)\]') { $Matches[1] }
    })
    foreach ($library in $needed) {
        if ($library -notin @('libc.so', 'libc++_shared.so')) {
            throw "Unpackaged ELF dependency ${library}: $File"
        }
    }
    if ($Executable) {
        $headers = & $readelf --program-headers $File
        if ($LASTEXITCODE -ne 0) { throw "Cannot inspect ELF interpreter: $File" }
        if (($headers -join "`n") -notmatch [regex]::Escape("[Requesting program interpreter: /lib/ld-musl-$cpu.so.1]")) {
            throw "Expected OHOS musl ELF interpreter: $File"
        }
    }
    return [ordered]@{
        architecture = $cpu
        neededLibraries = $needed
        sha256 = (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$manifest = Get-Content -LiteralPath (Join-Path $ToolchainDirectory 'toolchain.json') -Raw | ConvertFrom-Json
if ($manifest.targetTriple -ne $expectedTriple -or $manifest.architecture -ne $TargetArchitecture) {
    throw "Toolchain architecture mismatch: expected $TargetArchitecture / $expectedTriple"
}
if ($manifest.formatVersion -ne 1 -or $manifest.llvmVersion -ne '15.0.7' -or
    $manifest.llvmCommit -ne '8dfdcc7b7bf66834a761bd8de445840ef68e4d1a') {
    throw 'Toolchain must use the pinned LLVM 15.0.7 version and source commit.'
}
$runtimeRelative = "lib/$expectedTriple/libc++_shared.so"
foreach ($item in @(
    @{ Path = 'bin/clang'; Metadata = 'compilerMetadata'; Executable = $true },
    @{ Path = 'bin/ld.lld'; Metadata = 'linkerMetadata'; Executable = $true },
    @{ Path = $runtimeRelative; Metadata = 'runtimeMetadata'; Executable = $false }
)) {
    $file = Join-Path $ToolchainDirectory $item.Path
    $actual = Inspect-Elf $file $item.Executable
    if ($actual.sha256 -ne $manifest.($item.Metadata).sha256) {
        throw "Toolchain SHA256 does not match toolchain.json: $file"
    }
}
foreach ($relative in @(
    'bin/ohos.cfg', 'sysroot/usr/include/stdio.h',
    'include/c++/v1/vector', 'include/c++/v1/stdexcept',
    'lib/clang/15.0.7/include/stddef.h',
    "lib/clang/15.0.7/lib/$expectedTriple/libclang_rt.builtins.a",
    "lib/clang/15.0.7/lib/$expectedTriple/clang_rt.crtbegin.o",
    "lib/clang/15.0.7/lib/$expectedTriple/clang_rt.crtend.o",
    "sysroot/usr/lib/$cpu-linux-ohos/libc.so",
    "lib/$expectedTriple/libc++.so", "lib/$expectedTriple/libunwind.a"
)) { Require-File (Join-Path $ToolchainDirectory $relative) }

$outputLibs = Join-Path $ProjectRoot "ohos/entry/libs/$TargetArchitecture"
New-Item -ItemType Directory -Path $outputLibs -Force | Out-Null
$executorOutput = Join-Path $outputLibs 'libqfli_executor.so'
$executorTemporary = "$executorOutput.$([guid]::NewGuid().ToString('N')).tmp"
$compilerArguments = @(
    "--target=$expectedTriple", "--sysroot=$(Join-Path $NativeSdk 'sysroot')",
    '-O2', '-fPIC', '-fPIE', '-pie', '-o', $executorTemporary, $ExecutorSource
)
try {
    & $sdkCompiler @compilerArguments
    if ($LASTEXITCODE -ne 0) { throw "Executor build failed with exit code $LASTEXITCODE" }
    $executorMetadata = Inspect-Elf $executorTemporary $true
    Move-Item -LiteralPath $executorTemporary -Destination $executorOutput -Force
} finally {
    if (Test-Path -LiteralPath $executorTemporary) { Remove-Item -LiteralPath $executorTemporary -Force }
}
# Retain the ld.lld component: upstream LLD selects its ELF driver from argv[0].
$nativeFiles = @{
    'libqfli_clang.so' = 'bin/clang'
    'libqfli-ld.lld-.so' = 'bin/ld.lld'
    'libc++_shared.so' = $runtimeRelative
}
foreach ($name in $nativeFiles.Keys) {
    Copy-Item -LiteralPath (Join-Path $ToolchainDirectory $nativeFiles[$name]) -Destination (Join-Path $outputLibs $name) -Force
}
$manifest.compiler = 'libqfli_clang.so'
$manifest.linker = 'libqfli-ld.lld-.so'
$manifest | Add-Member -NotePropertyName executor -NotePropertyValue 'libqfli_executor.so' -Force
$manifest | Add-Member -NotePropertyName installedNativeExecutables -NotePropertyValue $true -Force
$manifest | Add-Member -NotePropertyName executorMetadata -NotePropertyValue $executorMetadata -Force
$manifestBytes = [Text.Encoding]::UTF8.GetBytes(($manifest | ConvertTo-Json -Depth 8))

$rawfileDirectory = Join-Path $ProjectRoot 'ohos/entry/src/main/resources/rawfile/qfli_toolchain'
New-Item -ItemType Directory -Path $rawfileDirectory -Force | Out-Null
$archive = Join-Path $rawfileDirectory "ohos-$TargetArchitecture.zip"
$archiveTemporary = "$archive.$([guid]::NewGuid().ToString('N')).tmp"
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
    $archiveStream = [IO.Compression.ZipFile]::Open($archiveTemporary, 'Create')
    try {
        $toolchainPrefix = $ToolchainDirectory.TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
        foreach ($file in (Get-ChildItem -LiteralPath $ToolchainDirectory -Recurse -File)) {
            if (-not $file.FullName.StartsWith($toolchainPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw "ZIP source is outside toolchain directory: $($file.FullName)"
            }
            $relative = $file.FullName.Substring($toolchainPrefix.Length).Replace('\', '/')
            if ($relative.StartsWith('/') -or $relative -match '(^|/)\.\.(/|$)' -or $relative.Contains(':')) {
                throw "Invalid ZIP entry path: $relative"
            }
            if ($relative -in @('bin/clang', 'bin/ld.lld')) { continue }
            $entry = $archiveStream.CreateEntry($relative, [IO.Compression.CompressionLevel]::Optimal)
            $entry.ExternalAttributes = 33188 -shl 16
            $entryStream = $entry.Open()
            try {
                if ($relative -eq 'toolchain.json') {
                    $entryStream.Write($manifestBytes, 0, $manifestBytes.Length)
                } else {
                    $inputStream = [IO.File]::OpenRead($file.FullName)
                    try { $inputStream.CopyTo($entryStream) } finally { $inputStream.Dispose() }
                }
            } finally { $entryStream.Dispose() }
        }
    } finally { $archiveStream.Dispose() }
    $checkArchive = [IO.Compression.ZipFile]::OpenRead($archiveTemporary)
    try {
        foreach ($relative in @('toolchain.json', 'bin/ohos.cfg', 'sysroot/usr/include/stdio.h', 'include/c++/v1/vector')) {
            if ($null -eq $checkArchive.GetEntry($relative)) { throw "ZIP is missing required entry: $relative" }
        }
        foreach ($entry in $checkArchive.Entries) {
            if ($entry.FullName.Contains('\')) { throw "ZIP paths must use forward slashes: $($entry.FullName)" }
        }
    } finally { $checkArchive.Dispose() }
    Move-Item -LiteralPath $archiveTemporary -Destination $archive -Force
} finally {
    if (Test-Path -LiteralPath $archiveTemporary) { Remove-Item -LiteralPath $archiveTemporary -Force }
}
$archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$archive.sha256", "$archiveHash`n", [Text.Encoding]::ASCII)
Write-Host "Packaged $TargetArchitecture LLVM $($manifest.llvmVersion)"
Write-Host "Installed native files: $outputLibs"
Write-Host "Resource ZIP: $archive ($([math]::Round((Get-Item $archive).Length / 1MB, 1)) MiB)"
Write-Host "Resource SHA256: $archiveHash"
Write-Host 'App compilation/execution and platform code-signing policies require independent verification.'
