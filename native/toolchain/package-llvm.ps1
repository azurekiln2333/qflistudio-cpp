[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$NativeSdk,
    [Parameter(Mandatory = $true)]
    [string]$TargetBuildDirectory,
    [ValidateSet('arm64-v8a', 'x86_64')]
    [string]$TargetArchitecture = 'arm64-v8a',
    [string]$OutputDirectory,
    [string]$SourceDirectory = (Join-Path $PSScriptRoot '../build/llvm-project')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$version = '15.0.7'
$NativeSdk = [IO.Path]::GetFullPath($NativeSdk)
$TargetBuildDirectory = [IO.Path]::GetFullPath($TargetBuildDirectory)
$SourceDirectory = [IO.Path]::GetFullPath($SourceDirectory)
$cpu = if ($TargetArchitecture -eq 'arm64-v8a') { 'aarch64' } else { 'x86_64' }
$machine = if ($TargetArchitecture -eq 'arm64-v8a') { 183 } else { 62 }
$sdkTriple = "$cpu-linux-ohos"
$targetTriple = "$cpu-unknown-linux-ohos"
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $PSScriptRoot "../build/toolchain-ohos-$TargetArchitecture"
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)

function Require-File {
    param([string]$File)
    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
        throw "Required file does not exist: $File"
    }
}

function Copy-RequiredFile {
    param([string]$Source, [string]$Destination)
    Require-File $Source
    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Copy-RequiredDirectory {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Required directory does not exist: $Source"
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Get-ChildItem -LiteralPath $Source -Force |
        Copy-Item -Destination $Destination -Recurse -Force
}

function Inspect-Elf {
    param([string]$File)
    $headers = & $readobj --elf-output-style=JSON --file-headers $File
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect ELF headers: $File" }
    $parsed = ($headers -join "`n") | ConvertFrom-Json
    $metadata = @($parsed)[0].PSObject.Properties.Value
    if ($metadata.ElfHeader.Machine.RawValue -ne $machine) {
        throw "ELF architecture does not match ${TargetArchitecture}: $File"
    }
    $dynamic = & $readelf --dynamic $File
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect ELF dependencies: $File" }
    # LLVM 15 readobj emits invalid JSON for NeededLibraries, so parse readelf.
    $needed = @($dynamic | ForEach-Object {
        if ($_ -match '\(NEEDED\).*\[([^\]]+)\]') { $Matches[1] }
    })
    foreach ($library in $needed) {
        if ($library -notin @('libc.so', 'libc++_shared.so')) {
            throw "Unpackaged ELF dependency ${library}: $File"
        }
    }
    return [ordered]@{
        architecture = $metadata.FileSummary.Arch
        neededLibraries = $needed
        sha256 = (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$readobj = Join-Path $NativeSdk 'llvm/bin/llvm-readobj.exe'
$readelf = Join-Path $NativeSdk 'llvm/bin/llvm-readelf.exe'
Require-File $readobj
Require-File $readelf
$cachePath = Join-Path $TargetBuildDirectory 'CMakeCache.txt'
Require-File $cachePath
$cache = Get-Content -LiteralPath $cachePath -Raw
if ($cache -notmatch '(?m)^CMAKE_PROJECT_VERSION:STATIC=15\.0\.7\r?$') {
    throw "Build directory must contain LLVM $version"
}
if ($cache -notmatch "(?m)^OHOS_ARCH:[^=]+=$([regex]::Escape($TargetArchitecture))`r?$") {
    throw "Build directory does not target ${TargetArchitecture}: $TargetBuildDirectory"
}
$clang = Join-Path $TargetBuildDirectory 'bin/clang'
$lld = Join-Path $TargetBuildDirectory 'bin/lld'
Require-File $clang
Require-File $lld
$compilerMetadata = Inspect-Elf $clang
$linkerMetadata = Inspect-Elf $lld

# A fresh output prevents stale libraries or headers from another SDK surviving.
if (Test-Path -LiteralPath $OutputDirectory) {
    throw "Output directory already exists; select a fresh OutputDirectory: $OutputDirectory"
}
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
Copy-RequiredFile $clang (Join-Path $OutputDirectory 'bin/clang')
Copy-RequiredFile $lld (Join-Path $OutputDirectory 'bin/ld.lld')
Copy-RequiredDirectory (Join-Path $TargetBuildDirectory "lib/clang/$version/include") `
    (Join-Path $OutputDirectory "lib/clang/$version/include")
Copy-RequiredDirectory (Join-Path $NativeSdk 'sysroot/usr/include') `
    (Join-Path $OutputDirectory 'sysroot/usr/include')
Copy-RequiredDirectory (Join-Path $NativeSdk "sysroot/usr/lib/$sdkTriple") `
    (Join-Path $OutputDirectory "sysroot/usr/lib/$sdkTriple")
Copy-RequiredDirectory (Join-Path $NativeSdk 'llvm/include/libcxx-ohos/include/c++/v1') `
    (Join-Path $OutputDirectory 'include/c++/v1')

$runtimeDirectory = Join-Path $OutputDirectory "lib/$targetTriple"
foreach ($name in @('libc++_static.a', 'libc++abi.a', 'libunwind.a', 'libc++_shared.so', 'libc++.so', 'libc++.a')) {
    Copy-RequiredFile (Join-Path $NativeSdk "llvm/lib/$sdkTriple/$name") `
        (Join-Path $runtimeDirectory $name)
}
$resourceLibraries = Join-Path $OutputDirectory "lib/clang/$version/lib/$targetTriple"
foreach ($name in @('libclang_rt.builtins.a', 'clang_rt.crtbegin.o', 'clang_rt.crtend.o')) {
    Copy-RequiredFile (Join-Path $NativeSdk "llvm/lib/clang/15.0.4/lib/$sdkTriple/$name") `
        (Join-Path $resourceLibraries $name)
}
$runtimeMetadata = Inspect-Elf (Join-Path $runtimeDirectory 'libc++_shared.so')
Copy-RequiredFile (Join-Path $SourceDirectory 'llvm/LICENSE.TXT') `
    (Join-Path $OutputDirectory 'licenses/LLVM.txt')
Copy-RequiredFile (Join-Path $NativeSdk 'NOTICE.txt') `
    (Join-Path $OutputDirectory 'licenses/OHOS-Native-SDK.txt')
Copy-RequiredFile (Join-Path $NativeSdk 'llvm/NOTICE') `
    (Join-Path $OutputDirectory 'licenses/OHOS-LLVM.txt')

$configuration = @"
--target=$targetTriple
-D__OHOS__=1
-D__OHOS_FAMILY__=1
-D__MUSL__=1
--sysroot=<CFGDIR>/../sysroot
-resource-dir=<CFGDIR>/../lib/clang/$version
-isystem <CFGDIR>/../sysroot/usr/include/$sdkTriple
-isystem <CFGDIR>/../include/c++/v1
-B<CFGDIR>/../sysroot/usr/lib/$sdkTriple
-L<CFGDIR>/../sysroot/usr/lib/$sdkTriple
-L<CFGDIR>/../lib/$targetTriple
--rtlib=compiler-rt
--unwindlib=libunwind
-stdlib=libc++
--ld-path=<CFGDIR>/ld.lld
-Wl,--dynamic-linker,/lib/ld-musl-$cpu.so.1
-Wl,-rpath,<CFGDIR>/../lib/$targetTriple
"@
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'bin/ohos.cfg'), $configuration)
$manifest = [ordered]@{
    formatVersion = 1
    llvmVersion = $version
    llvmCommit = '8dfdcc7b7bf66834a761bd8de445840ef68e4d1a'
    architecture = $TargetArchitecture
    targetTriple = $targetTriple
    compiler = 'bin/clang'
    linker = 'bin/ld.lld'
    configuration = 'bin/ohos.cfg'
    libraryDirectory = "lib/$targetTriple"
    compilerMetadata = $compilerMetadata
    linkerMetadata = $linkerMetadata
    runtimeMetadata = $runtimeMetadata
}
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'toolchain.json'), ($manifest | ConvertTo-Json -Depth 8))
Write-Output "Packaged $TargetArchitecture LLVM $version at $OutputDirectory"
Write-Output 'Set execute permissions on bin/clang and bin/ld.lld after copying to OHOS.'
Write-Output 'Invoke bin/clang --config ohos.cfg; add --driver-mode=g++ for C++ linking.'
