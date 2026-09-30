[CmdletBinding()]
param(
    [string]$AndroidSdk = 'D:/ProgramData/Android/Sdk',
    [ValidateSet('27.0.12077973')]
    [string]$NdkVersion = '27.0.12077973',
    [Parameter(Mandatory = $true)]
    [string]$TargetBuildDirectory,
    [ValidateSet('arm64-v8a', 'x86_64')]
    [string]$TargetArchitecture = 'x86_64',
    [ValidateRange(21, 35)]
    [int]$ApiLevel = 21,
    [string]$OutputDirectory,
    [string]$SourceDirectory,
    [string]$ValidationCompiler,
    [switch]$ResourcesOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$version = '15.0.7'
$commit = '8dfdcc7b7bf66834a761bd8de445840ef68e4d1a'
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot '../build/android-package' }
if (-not $SourceDirectory) { $SourceDirectory = Join-Path $PSScriptRoot '../build/llvm-project' }
$TargetBuildDirectory = [IO.Path]::GetFullPath($TargetBuildDirectory)
$SourceDirectory = [IO.Path]::GetFullPath($SourceDirectory)
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$ndk = Join-Path $AndroidSdk "ndk/$NdkVersion"
$prebuilt = Join-Path $ndk 'toolchains/llvm/prebuilt/windows-x86_64'
$readobj = Join-Path $prebuilt 'bin/llvm-readobj.exe'
$strip = Join-Path $prebuilt 'bin/llvm-strip.exe'
$hostClang = Join-Path $prebuilt 'bin/clang.exe'
$hostLld = Join-Path $prebuilt 'bin/ld.lld.exe'
if (-not $ValidationCompiler) { $ValidationCompiler = $hostClang }
$cpu = if ($TargetArchitecture -eq 'arm64-v8a') { 'aarch64' } else { 'x86_64' }
$machine = if ($TargetArchitecture -eq 'arm64-v8a') { 183 } else { 62 }
$triple = "$cpu-linux-android"
$resources = Join-Path $OutputDirectory "resources/$TargetArchitecture"
$jni = Join-Path $OutputDirectory "jniLibs/$TargetArchitecture"
$archive = Join-Path $OutputDirectory "assets/qfli_toolchain/$TargetArchitecture.zip"

function Require-File {
    param([string]$File)
    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { throw "Required file does not exist: $File" }
}

function Invoke-Checked {
    param([string]$File, [string[]]$Arguments)
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$File failed with exit code $LASTEXITCODE" }
}

function Copy-RequiredFile {
    param([string]$Source, [string]$Destination)
    Require-File $Source
    New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Copy-RequiredDirectory {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw "Required directory does not exist: $Source" }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | Copy-Item -Destination $Destination -Recurse -Force
}

function Inspect-Elf {
    param([string]$File)
    $json = & $readobj --elf-output-style=JSON --file-headers --program-headers --needed-libs $File
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect ELF: $File" }
    $elf = @(($json -join "`n") | ConvertFrom-Json)[0]
    if ($elf.ElfHeader.Machine.Value -ne $machine) { throw "ELF architecture does not match ${TargetArchitecture}: $File" }
    $loads = @($elf.ProgramHeaders | ForEach-Object { $_.ProgramHeader } | Where-Object { $_.Type.Value -eq 1 })
    if ($loads.Count -eq 0) { throw "ELF has no LOAD segments: $File" }
    foreach ($load in $loads) {
        if ($load.Alignment -lt 16384 -or (($load.VirtualAddress - $load.Offset) % 16384) -ne 0) {
            throw "ELF LOAD segment is not 16 KB aligned: $File"
        }
    }
    $needed = @($elf.NeededLibraries)
    foreach ($library in $needed) {
        if ($library -notin @('libc.so', 'libm.so', 'libdl.so', 'liblog.so', 'libc++_shared.so')) {
            throw "Unexpected dynamic dependency $library in $File"
        }
    }
    return [ordered]@{
        architecture = $elf.FileSummary.Arch
        neededLibraries = $needed
        loadAlignments = @($loads | ForEach-Object { $_.Alignment })
        sha256 = (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

function Require-ExportedMain {
    param([string]$File)
    $json = & $readobj --elf-output-style=JSON --dyn-symbols $File
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect exported symbols: $File" }
    $elf = @(($json -join "`n") | ConvertFrom-Json)[0]
    $entry = @($elf.DynamicSymbols | ForEach-Object { $_.Symbol } | Where-Object {
        $_.Name.Name -eq 'main' -and $_.Section.Value -ne 0 -and $_.Binding.Value -eq 1 -and $_.Type.Value -eq 2
    })
    if ($entry.Count -ne 1) { throw "Shared fixture must export main for executor dlsym: $File" }
}

foreach ($file in @($readobj, $strip, $hostClang, $hostLld, $ValidationCompiler)) { Require-File $file }
$head = & git -C $SourceDirectory rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $head -ne $commit) { throw "LLVM source must be llvmorg-15.0.7 at $commit" }
Invoke-Checked 'git' @('-C', $SourceDirectory, 'diff', '--quiet', 'HEAD', '--')
$properties = Get-Content -LiteralPath (Join-Path $ndk 'source.properties') -Raw
if ($properties -notmatch "(?m)^Pkg.Revision\s*=\s*$([regex]::Escape($NdkVersion))\s*$") { throw "NDK revision does not match $NdkVersion" }
$cachePath = Join-Path $TargetBuildDirectory 'CMakeCache.txt'
Require-File $cachePath
$cache = Get-Content -LiteralPath $cachePath -Raw
foreach ($setting in @(@('ANDROID_ABI', $TargetArchitecture), @('ANDROID_PLATFORM', "android-$ApiLevel"), @('CMAKE_PROJECT_VERSION', $version))) {
    if ($cache -notmatch "(?m)^$($setting[0]):[^=]+=$([regex]::Escape($setting[1]))`r?$") {
        throw "Build cache must have $($setting[0])=$($setting[1])"
    }
}
foreach ($path in @($resources, $jni, $archive)) {
    if (Test-Path -LiteralPath $path) { throw "Output already exists; select a fresh OutputDirectory: $path" }
}
if (-not $ResourcesOnly) {
    Require-File (Join-Path $TargetBuildDirectory 'bin/clang')
    Require-File (Join-Path $TargetBuildDirectory 'bin/lld')
}

$resourceDirectory = "lib/clang/$version"
$includes = Join-Path $resources 'sysroot/usr/include'
New-Item -ItemType Directory -Path $includes -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $prebuilt 'sysroot/usr/include') -Force |
    Where-Object { $_.Name -ne 'c++' } | Copy-Item -Destination $includes -Recurse -Force
Copy-RequiredDirectory (Join-Path $SourceDirectory 'libcxx/include') (Join-Path $includes 'c++/v1')
# LLVM 15 headers use the stable Android ABI exported by the NDK runtime.
$configuration = @"
#ifndef _LIBCPP___CONFIG_SITE
#define _LIBCPP___CONFIG_SITE
#define _LIBCPP_ABI_VERSION 1
#define _LIBCPP_ABI_NAMESPACE __ndk1
#define _LIBCPP_HAS_THREAD_API_PTHREAD
#define _LIBCPP_HAS_NO_VENDOR_AVAILABILITY_ANNOTATIONS
#define _LIBCPP_ENABLE_ASSERTIONS_DEFAULT 0
#endif
"@
[IO.File]::WriteAllText((Join-Path $includes 'c++/v1/__config_site'), $configuration)
$sdkLibraryDirectory = Join-Path $prebuilt "sysroot/usr/lib/$triple"
$libraryDirectory = Join-Path $resources "sysroot/usr/lib/$triple"
New-Item -ItemType Directory -Path $libraryDirectory -Force | Out-Null
Get-ChildItem -LiteralPath $sdkLibraryDirectory -File | Copy-Item -Destination $libraryDirectory
Copy-RequiredDirectory (Join-Path $sdkLibraryDirectory "$ApiLevel") (Join-Path $libraryDirectory "$ApiLevel")
Copy-RequiredFile (Join-Path $prebuilt "lib/clang/18/lib/linux/$cpu/libunwind.a") (Join-Path $libraryDirectory 'libunwind.a')
Copy-RequiredFile (Join-Path $prebuilt "lib/clang/18/lib/linux/$cpu/libatomic.a") (Join-Path $libraryDirectory 'libatomic.a')
# Upstream Clang 15 links -lc++; NDK Clang's private -lc++_shared default differs.
[IO.File]::WriteAllText((Join-Path $libraryDirectory 'libc++.so'), 'INPUT ( libc++_shared.so )')
Copy-RequiredDirectory (Join-Path $TargetBuildDirectory "$resourceDirectory/include") (Join-Path $resources "$resourceDirectory/include")
Copy-RequiredFile (Join-Path $prebuilt "lib/clang/18/lib/linux/libclang_rt.builtins-$cpu-android.a") `
    (Join-Path $resources "$resourceDirectory/lib/linux/libclang_rt.builtins-$cpu-android.a")
Copy-RequiredFile (Join-Path $SourceDirectory 'llvm/LICENSE.TXT') (Join-Path $resources 'licenses/LLVM.txt')
Copy-RequiredFile (Join-Path $SourceDirectory 'libcxx/LICENSE.TXT') (Join-Path $resources 'licenses/libcxx.txt')
Copy-RequiredFile (Join-Path $ndk 'NOTICE') (Join-Path $resources 'licenses/Android-NDK.txt')

$metadata = [ordered]@{}
$metadata['libc++_shared.so'] = Inspect-Elf (Join-Path $libraryDirectory 'libc++_shared.so')
if (-not $ResourcesOnly) {
    Copy-RequiredFile (Join-Path $TargetBuildDirectory 'bin/clang') (Join-Path $jni 'libqfli_clang.so')
    Copy-RequiredFile (Join-Path $TargetBuildDirectory 'bin/lld') (Join-Path $jni 'libqfli-ld.lld-.so')
    Copy-RequiredFile (Join-Path $libraryDirectory 'libc++_shared.so') (Join-Path $jni 'libc++_shared.so')
    Invoke-Checked $hostClang @(
        "--target=$triple$ApiLevel", '-std=c17', '-O2', '-fPIE', '-pie',
        '-Werror', '-Wall', '-Wextra', '-Wl,-z,max-page-size=16384,-z,common-page-size=16384',
        (Join-Path $PSScriptRoot 'android-executor.c'), '-ldl', '-o', (Join-Path $jni 'libqfli_executor.so')
    )
    foreach ($name in @('libqfli_clang.so', 'libqfli-ld.lld-.so', 'libqfli_executor.so')) {
        Invoke-Checked $strip @('--strip-unneeded', (Join-Path $jni $name))
        $metadata[$name] = Inspect-Elf (Join-Path $jni $name)
    }
}

$validationDirectory = Join-Path $OutputDirectory "validation/$TargetArchitecture"
New-Item -ItemType Directory -Path $validationDirectory -Force | Out-Null
$fixture = Join-Path $PSScriptRoot 'tests/fixture'
$common = @("--target=$triple$ApiLevel", "--sysroot=$(Join-Path $resources 'sysroot')", '-resource-dir', (Join-Path $resources $resourceDirectory), '-fPIC')
Invoke-Checked $ValidationCompiler ($common + @('--driver-mode=gcc', '-std=c17', '-I', (Join-Path $fixture 'include'), '-c', (Join-Path $fixture 'answer.c'), '-o', (Join-Path $validationDirectory 'answer.o')))
Invoke-Checked $ValidationCompiler ($common + @('--driver-mode=gcc', '-std=c17', '-I', (Join-Path $fixture 'include'), '-c', (Join-Path $fixture 'main.c'), '-o', (Join-Path $validationDirectory 'main-c.o')))
Invoke-Checked $ValidationCompiler ($common + @('--driver-mode=g++', '-std=c++20', '-I', (Join-Path $fixture 'include'), '-c', (Join-Path $fixture 'main.cpp'), '-o', (Join-Path $validationDirectory 'main-cpp.o')))
Invoke-Checked $ValidationCompiler ($common + @('--driver-mode=g++', '-std=c++20', '-I', (Join-Path $fixture 'include'), '-c', (Join-Path $PSScriptRoot 'tests/android/answer.cpp'), '-o', (Join-Path $validationDirectory 'answer-cpp.o')))
Invoke-Checked $ValidationCompiler ($common + @('--driver-mode=gcc', '-std=c17', '-c', (Join-Path $PSScriptRoot 'tests/android/math.c'), '-o', (Join-Path $validationDirectory 'math.o')))
$links = @("--ld-path=$hostLld", '-Wl,-z,defs', '-Wl,-z,max-page-size=16384,-z,common-page-size=16384', '-latomic', '-lm')
$cases = @(
    @{ name = 'c'; mode = 'gcc'; objects = @('answer.o', 'main-c.o') },
    @{ name = 'cpp'; mode = 'g++'; objects = @('answer.o', 'main-cpp.o') },
    @{ name = 'c-cpp-helper'; mode = 'g++'; objects = @('answer-cpp.o', 'main-c.o') },
    @{ name = 'c-math'; mode = 'gcc'; objects = @('math.o') }
)
foreach ($case in $cases) {
    $objects = @($case.objects | ForEach-Object { Join-Path $validationDirectory $_ })
    foreach ($format in @('shared', 'executable')) {
        $output = Join-Path $validationDirectory "$($case.name)-$format"
        $formatArguments = if ($format -eq 'shared') { @('-shared') } else { @() }
        Invoke-Checked $ValidationCompiler ($common + @("--driver-mode=$($case.mode)") + $links + $formatArguments + $objects + @('-o', $output))
        $null = Inspect-Elf $output
        if ($format -eq 'shared') { Require-ExportedMain $output }
    }
}
$invalidArguments = $common + @('--driver-mode=gcc', '-std=c17', '-x', 'c', '-fsyntax-only', '-')
$unresolvedArguments = $common + @('--driver-mode=gcc', "--ld-path=$hostLld", '-shared', '-Wl,-z,defs', (Join-Path $validationDirectory 'main-c.o'), '-o', (Join-Path $validationDirectory 'unresolved-shared'))
$previousErrorAction = $ErrorActionPreference
try {
    # Windows PowerShell turns redirected native stderr into error records.
    $ErrorActionPreference = 'Continue'
    $invalidDiagnostics = 'int main(void) { return missing_symbol; }' | & $ValidationCompiler @invalidArguments 2>&1
    $invalidExitCode = $LASTEXITCODE
    $unresolvedDiagnostics = & $ValidationCompiler @unresolvedArguments 2>&1
    $unresolvedExitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousErrorAction
}
if ($invalidExitCode -eq 0 -or ($invalidDiagnostics -join "`n") -notmatch 'error:') {
    throw 'Invalid C source did not produce a compiler error'
}
[IO.File]::WriteAllText((Join-Path $validationDirectory 'invalid-source.txt'), ($invalidDiagnostics -join "`n"))
if ($unresolvedExitCode -eq 0 -or ($unresolvedDiagnostics -join "`n") -notmatch 'undefined symbol: answer') {
    throw 'Missing C helper did not produce the expected linker error'
}
[IO.File]::WriteAllText((Join-Path $validationDirectory 'unresolved-symbol.txt'), ($unresolvedDiagnostics -join "`n"))
$compilerVersion = (& $ValidationCompiler --version) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect validation compiler version' }
if ($compilerVersion -notmatch 'clang version 15\.') { Write-Warning 'Fixture validation used a non-LLVM15 host compiler; repeat with -ValidationCompiler <host-clang15> to check header compatibility.' }
$manifest = [ordered]@{
    formatVersion = 1
    llvmVersion = $version
    llvmCommit = $commit
    ndkVersion = $NdkVersion
    architecture = $TargetArchitecture
    targetTriple = $triple
    apiLevel = $ApiLevel
    resourceDirectory = $resourceDirectory
    sysroot = 'sysroot'
    compiler = 'libqfli_clang.so'
    linker = 'libqfli-ld.lld-.so'
    executor = 'libqfli_executor.so'
    cppHeaderVersion = $version
    cppAbiNamespace = '__ndk1'
    binaryMetadata = $metadata
    validation = [ordered]@{
        compilerVersion = $compilerVersion
        fixturesCrossLinked = @('c-shared', 'c-executable', 'cpp-shared', 'cpp-executable', 'c-cpp-helper-shared', 'c-cpp-helper-executable', 'c-math-shared', 'c-math-executable')
        exportedMainVerified = @('c-shared', 'cpp-shared', 'c-cpp-helper-shared', 'c-math-shared')
        expectedFailures = @('invalid-c-source', 'unresolved-user-symbol')
        deviceExecutionVerified = $false
    }
}
[IO.File]::WriteAllText((Join-Path $resources 'toolchain.json'), ($manifest | ConvertTo-Json -Depth 10))
New-Item -ItemType Directory -Path (Split-Path -Parent $archive) -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($resources, $archive, [IO.Compression.CompressionLevel]::Optimal, $false)
$archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$archive.sha256", "$archiveHash  $TargetArchitecture.zip`n")
Write-Output "Packaged $TargetArchitecture Android LLVM $version resources: $archive"
Write-Output "Archive SHA256: $archiveHash"
Write-Output "C17/C++20 multi-file and mixed C/C++ fixtures cross-linked; no device was executed."
if ($ResourcesOnly) { Write-Output 'ResourcesOnly output does not contain the native compiler/linker/executor and cannot enable the app runtime.' }
