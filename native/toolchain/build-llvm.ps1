[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$NativeSdk,
    [Parameter(Mandatory = $true)]
    [string]$MsysRoot,
    [ValidateSet('All', 'Host', 'Target')]
    [string]$Stage = 'All',
    [ValidateSet('arm64-v8a', 'x86_64')]
    [string]$TargetArchitecture = 'arm64-v8a',
    [ValidateRange(1, 32)]
    [int]$Jobs = 2,
    [string]$BuildRoot = (Join-Path $PSScriptRoot '../build'),
    [string]$SourceDirectory,
    [string]$HostBuildDirectory,
    [string]$TargetBuildDirectory,
    [string]$SourceRepository = 'https://github.com/llvm/llvm-project.git',
    [switch]$ConfigureOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$llvmTag = 'llvmorg-15.0.7'
$llvmCommit = '8dfdcc7b7bf66834a761bd8de445840ef68e4d1a'

function Invoke-Checked {
    param([string]$File, [string[]]$Arguments)
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$File failed with exit code $LASTEXITCODE"
    }
}

function Require-File {
    param([string]$File)
    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
        throw "Required file does not exist: $File"
    }
}

function Cmake-Path {
    param([string]$Value)
    return [IO.Path]::GetFullPath($Value).Replace('\', '/')
}

function Require-Tablegen {
    param([string]$File)
    Require-File $File
    $version = & $File --version
    if ($LASTEXITCODE -ne 0 -or ($version -join "`n") -notmatch 'LLVM version 15\.0\.7(?:\r?\n|$)') {
        throw "TableGen must start and report LLVM 15.0.7: $File"
    }
    $version | Write-Output
}

$NativeSdk = [IO.Path]::GetFullPath($NativeSdk)
$MsysRoot = [IO.Path]::GetFullPath($MsysRoot)
$BuildRoot = [IO.Path]::GetFullPath($BuildRoot)
if (-not $SourceDirectory) { $SourceDirectory = Join-Path $BuildRoot 'llvm-project' }
if (-not $HostBuildDirectory) { $HostBuildDirectory = Join-Path $BuildRoot 'llvm-host-windows' }
$targetName = if ($TargetArchitecture -eq 'arm64-v8a') { 'arm64' } else { 'x86_64' }
$targetBackend = if ($TargetArchitecture -eq 'arm64-v8a') { 'AArch64' } else { 'X86' }
$targetTriple = if ($TargetArchitecture -eq 'arm64-v8a') {
    'aarch64-unknown-linux-ohos'
} else {
    'x86_64-unknown-linux-ohos'
}
if (-not $TargetBuildDirectory) { $TargetBuildDirectory = Join-Path $BuildRoot "llvm-ohos-$targetName" }
$SourceDirectory = [IO.Path]::GetFullPath($SourceDirectory)
$HostBuildDirectory = [IO.Path]::GetFullPath($HostBuildDirectory)
$TargetBuildDirectory = [IO.Path]::GetFullPath($TargetBuildDirectory)
$cmake = Join-Path $NativeSdk 'build-tools/cmake/bin/cmake.exe'
$ninja = Join-Path $NativeSdk 'build-tools/cmake/bin/ninja.exe'
$toolchain = Join-Path $NativeSdk 'build/cmake/ohos.toolchain.cmake'
$mingwBin = Join-Path $MsysRoot 'mingw64/bin'
$gcc = Join-Path $mingwBin 'gcc.exe'
$gxx = Join-Path $mingwBin 'g++.exe'
foreach ($file in @($cmake, $ninja, $toolchain, $gcc, $gxx)) { Require-File $file }

$git = (Get-Command git -ErrorAction Stop).Source
if (-not (Test-Path -LiteralPath $SourceDirectory)) {
    New-Item -ItemType Directory -Path $BuildRoot -Force | Out-Null
    Invoke-Checked $git @('clone', '--depth', '1', '--branch', $llvmTag, $SourceRepository, $SourceDirectory)
}
$head = & $git -C $SourceDirectory rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $head -ne $llvmCommit) {
    throw "LLVM source must be $llvmTag at $llvmCommit (found $head)"
}
Invoke-Checked $git @('-C', $SourceDirectory, 'diff', '--quiet', 'HEAD', '--')

# Keep compiler frontends beside their DLLs without changing the MSYS2 install.
$hostTools = Join-Path $BuildRoot 'llvm-host-tools'
New-Item -ItemType Directory -Path $hostTools -Force | Out-Null
$gccVersion = & $gcc -dumpfullversion
if ($LASTEXITCODE -ne 0) { throw 'Cannot determine the MSYS2 GCC version' }
$gccLib = Join-Path $MsysRoot "mingw64/lib/gcc/x86_64-w64-mingw32/$gccVersion"
foreach ($name in @('cc1.exe', 'cc1plus.exe', 'collect2.exe')) {
    $file = Join-Path $gccLib $name
    Require-File $file
    Copy-Item -LiteralPath $file -Destination $hostTools -Force
}
foreach ($name in @('as.exe', 'ld.exe')) {
    $file = Join-Path $mingwBin $name
    Require-File $file
    Copy-Item -LiteralPath $file -Destination $hostTools -Force
}
Get-ChildItem -LiteralPath $mingwBin -Filter '*.dll' | Copy-Item -Destination $hostTools -Force
$originalPath = $env:Path
$env:Path = "$hostTools;$mingwBin;$originalPath"

try {
    $common = @(
        '-G', 'Ninja', "-DCMAKE_MAKE_PROGRAM=$(Cmake-Path $ninja)",
        '-DCMAKE_BUILD_TYPE=Release',
        '-DLLVM_INCLUDE_TESTS=OFF', '-DLLVM_INCLUDE_EXAMPLES=OFF',
        '-DLLVM_INCLUDE_BENCHMARKS=OFF', '-DLLVM_ENABLE_TERMINFO=OFF',
        '-DLLVM_ENABLE_ZLIB=OFF', '-DLLVM_ENABLE_ZSTD=OFF',
        '-DLLVM_ENABLE_LIBXML2=OFF', '-DLLVM_ENABLE_WARNINGS=OFF'
    )
    $source = Join-Path $SourceDirectory 'llvm'
    if ($Stage -in @('All', 'Host')) {
        $toolsFlag = '-B"' + (Cmake-Path $hostTools) + '/"'
        $hostArgs = @(
            '-S', $source, '-B', $HostBuildDirectory,
            "-DCMAKE_C_COMPILER=$(Cmake-Path $gcc)",
            "-DCMAKE_CXX_COMPILER=$(Cmake-Path $gxx)",
            "-DCMAKE_C_FLAGS=$toolsFlag", "-DCMAKE_ASM_FLAGS=$toolsFlag",
            "-DCMAKE_CXX_FLAGS=$toolsFlag -include cstdint",
            '-DLLVM_ENABLE_PROJECTS=clang', '-DLLVM_TARGETS_TO_BUILD=AArch64'
        ) + $common
        Invoke-Checked $cmake $hostArgs
        if (-not $ConfigureOnly) {
            Invoke-Checked $cmake @('--build', $HostBuildDirectory, '--target', 'llvm-tblgen', 'clang-tblgen', '--parallel', "$Jobs")
            Require-Tablegen (Join-Path $HostBuildDirectory 'bin/llvm-tblgen.exe')
            Require-Tablegen (Join-Path $HostBuildDirectory 'bin/clang-tblgen.exe')
        }
    }
    if ($Stage -in @('All', 'Target')) {
        $cachePath = Join-Path $TargetBuildDirectory 'CMakeCache.txt'
        if (Test-Path -LiteralPath $cachePath) {
            $existingCache = Get-Content -LiteralPath $cachePath -Raw
            if ($existingCache -match '(?m)^OHOS_ARCH:[^=]+=([^\r\n]+)' -and
                $Matches[1] -ne $TargetArchitecture) {
                throw "Build directory targets $($Matches[1]), not $TargetArchitecture; select another TargetBuildDirectory"
            }
        }
        $llvmTablegen = Join-Path $HostBuildDirectory 'bin/llvm-tblgen.exe'
        $clangTablegen = Join-Path $HostBuildDirectory 'bin/clang-tblgen.exe'
        Require-Tablegen $llvmTablegen
        Require-Tablegen $clangTablegen
        $targetArgs = @(
            '-S', $source, '-B', $TargetBuildDirectory,
            "-DCMAKE_TOOLCHAIN_FILE=$(Cmake-Path $toolchain)",
            "-DOHOS_ARCH=$TargetArchitecture", "-DLLVM_TARGETS_TO_BUILD=$targetBackend",
            '-DCMAKE_C_FLAGS=-Qunused-arguments',
            '-DCMAKE_CXX_FLAGS=-Qunused-arguments', '-DCMAKE_ASM_FLAGS=-Qunused-arguments',
            '-DLLVM_ENABLE_PROJECTS=clang;lld',
            "-DLLVM_HOST_TRIPLE=$targetTriple",
            "-DLLVM_DEFAULT_TARGET_TRIPLE=$targetTriple",
            "-DLLVM_TABLEGEN=$(Cmake-Path $llvmTablegen)",
            "-DCLANG_TABLEGEN=$(Cmake-Path $clangTablegen)"
        ) + $common
        Invoke-Checked $cmake $targetArgs
        $cache = Get-Content -LiteralPath (Join-Path $TargetBuildDirectory 'CMakeCache.txt') -Raw
        foreach ($probe in @('C_SUPPORTS_FPIC', 'CXX_SUPPORTS_FPIC')) {
            if ($cache -notmatch "(?m)^${probe}:INTERNAL=1`r?$") {
                throw "$probe failed; inspect $TargetBuildDirectory/CMakeFiles/CMakeConfigureLog.yaml"
            }
        }
        if (-not $ConfigureOnly) {
            Invoke-Checked $cmake @('--build', $TargetBuildDirectory, '--target', 'clang', 'lld', '--parallel', "$Jobs")
        }
    }
} finally {
    $env:Path = $originalPath
}
