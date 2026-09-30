[CmdletBinding()]
param(
    [string]$AndroidSdk = 'D:/ProgramData/Android/Sdk',
    [ValidateSet('27.0.12077973')]
    [string]$NdkVersion = '27.0.12077973',
    [string]$CmakeVersion = '3.22.1',
    [ValidateSet('arm64-v8a', 'x86_64')]
    [string]$TargetArchitecture = 'x86_64',
    [ValidateRange(21, 35)]
    [int]$ApiLevel = 21,
    [ValidateRange(1, 32)]
    [int]$Jobs = 1,
    [string]$BuildRoot,
    [string]$SourceDirectory,
    [string]$HostBuildDirectory,
    [string]$TargetBuildDirectory,
    [string]$MsysRoot,
    [switch]$ConfigureOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$llvmCommit = '8dfdcc7b7bf66834a761bd8de445840ef68e4d1a'

function Invoke-Checked {
    param([string]$File, [string[]]$Arguments)
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$File failed with exit code $LASTEXITCODE" }
}

function Require-File {
    param([string]$File)
    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { throw "Required file does not exist: $File" }
}

function Cmake-Path {
    param([string]$Value)
    return [IO.Path]::GetFullPath($Value).Replace('\', '/')
}

if (-not $BuildRoot) { $BuildRoot = Join-Path $PSScriptRoot '../build' }
$BuildRoot = [IO.Path]::GetFullPath($BuildRoot)
if (-not $SourceDirectory) { $SourceDirectory = Join-Path $BuildRoot 'llvm-project' }
if (-not $HostBuildDirectory) { $HostBuildDirectory = Join-Path $BuildRoot 'llvm-host-msys2-working' }
if (-not $TargetBuildDirectory) { $TargetBuildDirectory = Join-Path $BuildRoot "llvm-android-$TargetArchitecture" }
if (-not $MsysRoot) { $MsysRoot = Join-Path $BuildRoot 'msys64' }
$SourceDirectory = [IO.Path]::GetFullPath($SourceDirectory)
$TargetBuildDirectory = [IO.Path]::GetFullPath($TargetBuildDirectory)
$ndk = Join-Path $AndroidSdk "ndk/$NdkVersion"
$cmake = Join-Path $AndroidSdk "cmake/$CmakeVersion/bin/cmake.exe"
$ninja = Join-Path $AndroidSdk "cmake/$CmakeVersion/bin/ninja.exe"
$toolchain = Join-Path $ndk 'build/cmake/android.toolchain.cmake'
$llvmTablegen = Join-Path $HostBuildDirectory 'bin/llvm-tblgen.exe'
$clangTablegen = Join-Path $HostBuildDirectory 'bin/clang-tblgen.exe'
foreach ($file in @($cmake, $ninja, $toolchain, $llvmTablegen, $clangTablegen)) { Require-File $file }
$ndkProperties = Get-Content -LiteralPath (Join-Path $ndk 'source.properties') -Raw
if ($ndkProperties -notmatch "(?m)^Pkg.Revision\s*=\s*$([regex]::Escape($NdkVersion))\s*$") {
    throw "NDK revision does not match $NdkVersion"
}
$head = & git -C $SourceDirectory rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $head -ne $llvmCommit) { throw "LLVM source must be llvmorg-15.0.7 at $llvmCommit (found $head)" }
Invoke-Checked 'git' @('-C', $SourceDirectory, 'diff', '--quiet', 'HEAD', '--')

$cachePath = Join-Path $TargetBuildDirectory 'CMakeCache.txt'
if (Test-Path -LiteralPath $cachePath) {
    $existingCache = Get-Content -LiteralPath $cachePath -Raw
    foreach ($setting in @(@('ANDROID_ABI', $TargetArchitecture), @('ANDROID_PLATFORM', "android-$ApiLevel"))) {
        if ($existingCache -notmatch "(?m)^$($setting[0]):[^=]+=([^\r\n]+)") {
            throw "Build directory lacks $($setting[0]); select another TargetBuildDirectory"
        }
        if ($Matches[1] -ne $setting[1]) {
            throw "Build directory has $($setting[0])=$($Matches[1]); select another TargetBuildDirectory"
        }
    }
    if ($existingCache -notmatch '(?m)^CMAKE_TOOLCHAIN_FILE:[^=]+=([^\r\n]+)' -or
        (Cmake-Path $Matches[1]) -ne (Cmake-Path $toolchain)) {
        throw 'Build directory uses another toolchain; select another TargetBuildDirectory'
    }
}

# TableGen was built with MinGW; its DLLs must precede unrelated DLLs on PATH.
$hostTools = Join-Path $BuildRoot 'llvm-host-tools'
New-Item -ItemType Directory -Path $hostTools -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $MsysRoot 'mingw64/bin') -Filter '*.dll' |
    Copy-Item -Destination $hostTools -Force
$originalPath = $env:Path
$env:Path = "$hostTools;$(Join-Path $MsysRoot 'mingw64/bin');$originalPath"
try {
    foreach ($tablegen in @($llvmTablegen, $clangTablegen)) {
        $version = & $tablegen --version
        if ($LASTEXITCODE -ne 0 -or ($version -join "`n") -notmatch 'LLVM version 15\.0\.7(?:\r?\n|$)') {
            throw "TableGen must start and report LLVM 15.0.7: $tablegen"
        }
    }
    $backend = if ($TargetArchitecture -eq 'arm64-v8a') { 'AArch64' } else { 'X86' }
    $triple = if ($TargetArchitecture -eq 'arm64-v8a') { 'aarch64-linux-android' } else { 'x86_64-linux-android' }
    $arguments = @(
        '-S', (Join-Path $SourceDirectory 'llvm'), '-B', $TargetBuildDirectory,
        '-G', 'Ninja', "-DCMAKE_MAKE_PROGRAM=$(Cmake-Path $ninja)",
        "-DCMAKE_TOOLCHAIN_FILE=$(Cmake-Path $toolchain)",
        "-DANDROID_ABI=$TargetArchitecture", "-DANDROID_PLATFORM=android-$ApiLevel",
        '-DANDROID_STL=c++_static', '-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON',
        '-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_C_FLAGS_RELEASE=-O2 -DNDEBUG',
        '-DCMAKE_CXX_FLAGS_RELEASE=-O2 -DNDEBUG',
        '-DCMAKE_EXE_LINKER_FLAGS=-Wl,-z,max-page-size=16384,-z,common-page-size=16384',
        '-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-z,max-page-size=16384,-z,common-page-size=16384',
        '-DLLVM_ENABLE_PROJECTS=clang;lld', "-DLLVM_TARGETS_TO_BUILD=$backend",
        "-DLLVM_HOST_TRIPLE=$triple", "-DLLVM_DEFAULT_TARGET_TRIPLE=$triple$ApiLevel",
        "-DLLVM_TABLEGEN=$(Cmake-Path $llvmTablegen)", "-DCLANG_TABLEGEN=$(Cmake-Path $clangTablegen)",
        '-DLLVM_INCLUDE_TESTS=OFF', '-DLLVM_INCLUDE_EXAMPLES=OFF',
        '-DLLVM_INCLUDE_BENCHMARKS=OFF', '-DLLVM_ENABLE_TERMINFO=OFF',
        '-DLLVM_ENABLE_ZLIB=OFF', '-DLLVM_ENABLE_ZSTD=OFF', '-DLLVM_ENABLE_LIBXML2=OFF',
        '-DLLVM_ENABLE_WARNINGS=OFF', '-DLLVM_ENABLE_ASSERTIONS=OFF',
        '-DLLVM_ENABLE_PIC=ON', '-DCLANG_ENABLE_STATIC_ANALYZER=OFF',
        '-DCLANG_ENABLE_ARCMT=OFF', '-DCLANG_INCLUDE_DOCS=OFF', '-DLLVM_INCLUDE_DOCS=OFF'
    )
    Invoke-Checked $cmake $arguments
    $cache = Get-Content -LiteralPath $cachePath -Raw
    foreach ($probe in @('C_SUPPORTS_FPIC', 'CXX_SUPPORTS_FPIC')) {
        if ($cache -notmatch "(?m)^${probe}:INTERNAL=1`r?$") {
            throw "$probe failed; inspect $TargetBuildDirectory/CMakeFiles/CMakeOutput.log and CMakeError.log"
        }
    }
    if (-not $ConfigureOnly) {
        Invoke-Checked $cmake @('--build', $TargetBuildDirectory, '--target', 'clang-resource-headers', '--parallel', "$Jobs")
        Invoke-Checked $cmake @('--build', $TargetBuildDirectory, '--target', 'clang', 'lld', '--parallel', "$Jobs")
    }
} finally {
    $env:Path = $originalPath
}
