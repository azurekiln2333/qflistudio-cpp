[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Apk,
    [ValidateSet('arm64-v8a', 'x86_64')]
    [string[]]$TargetArchitectures = @('arm64-v8a', 'x86_64'),
    [string]$AndroidSdk = 'D:/ProgramData/Android/Sdk',
    [string]$NdkVersion = '27.0.12077973',
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot '../build/apk-verification' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Apk = [IO.Path]::GetFullPath($Apk)
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$readobj = Join-Path $AndroidSdk "ndk/$NdkVersion/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-readobj.exe"
foreach ($file in @($Apk, $readobj)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Required file does not exist: $file" }
}

function Require-Entry {
    param([IO.Compression.ZipArchive]$Archive, [string]$Name)
    $entry = $Archive.GetEntry($Name)
    if ($null -eq $entry) { throw "Missing APK/archive entry: $Name" }
    return $entry
}

function Read-EntryText {
    param([IO.Compression.ZipArchiveEntry]$Entry)
    $reader = [IO.StreamReader]::new($Entry.Open())
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Entry-Hash {
    param([IO.Compression.ZipArchiveEntry]$Entry)
    $stream = $Entry.Open()
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $hash.Dispose() }
}

$apkArchive = [IO.Compression.ZipFile]::OpenRead($Apk)
try {
    foreach ($abi in $TargetArchitectures) {
        $resourceEntry = Require-Entry $apkArchive "assets/qfli_toolchain/$abi.zip"
        $expectedHash = (Read-EntryText (Require-Entry $apkArchive "assets/qfli_toolchain/$abi.zip.sha256")).Trim().Split(' ')[0]
        if ((Entry-Hash $resourceEntry) -ne $expectedHash) { throw "Resource archive SHA256 mismatch: $abi" }
        $resourceStream = $resourceEntry.Open()
        $resources = [IO.Compression.ZipArchive]::new($resourceStream, [IO.Compression.ZipArchiveMode]::Read)
        try {
            foreach ($entry in $resources.Entries) {
                if ($entry.FullName.Contains('\')) {
                    throw "Resource ZIP paths must use forward slashes for Android: $abi/$($entry.FullName)"
                }
            }
            $manifest = Read-EntryText (Require-Entry $resources 'toolchain.json') | ConvertFrom-Json
            if ($manifest.architecture -ne $abi) { throw "Resource manifest architecture mismatch: $abi" }
            if ($manifest.validation.deviceExecutionVerified -ne $false) { throw 'Local artifacts must not claim device verification' }
            $nativeNames = [ordered]@{
                compiler = 'libqfli_clang.so'
                linker = 'libqfli-ld.lld-.so'
                executor = 'libqfli_executor.so'
            }
            foreach ($field in $nativeNames.Keys) {
                if ($manifest.$field -ne $nativeNames[$field]) {
                    throw "Resource manifest $field filename does not match the Android bridge: $abi"
                }
            }
            $null = Require-Entry $resources 'sysroot/usr/include/stdio.h'
            $null = Require-Entry $resources 'sysroot/usr/include/c++/v1/vector'
            $null = Require-Entry $resources "$($manifest.resourceDirectory)/include/stddef.h"
            $machine = if ($abi -eq 'arm64-v8a') { 183 } else { 62 }
            $destination = Join-Path $OutputDirectory $abi
            New-Item -ItemType Directory -Path $destination -Force | Out-Null
            foreach ($name in @($nativeNames.Values) + @('libc++_shared.so')) {
                $entry = Require-Entry $apkArchive "lib/$abi/$name"
                $file = Join-Path $destination $name
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $file, $true)
                # AGP can strip the STL; the three executor/compiler files are kept intact.
                if ($name -ne 'libc++_shared.so' -and (Entry-Hash $entry) -ne $manifest.binaryMetadata.$name.sha256) {
                    throw "Packaged native executable SHA256 mismatch: $abi/$name"
                }
                $json = & $readobj --elf-output-style=JSON --file-headers --program-headers --needed-libs $file
                if ($LASTEXITCODE -ne 0) { throw "Cannot inspect APK ELF: $file" }
                $elf = @(($json -join "`n") | ConvertFrom-Json)[0]
                if ($elf.ElfHeader.Machine.Value -ne $machine) { throw "APK ELF architecture mismatch: $abi/$name" }
                if ($elf.ElfHeader.Ident.Class.Value -ne 2 -or
                    $elf.ElfHeader.Ident.DataEncoding.Value -ne 1 -or
                    $elf.ElfHeader.Type -ne 'SharedObject (0x3)') {
                    throw "APK native file must be a 64-bit little-endian ET_DYN ELF: $abi/$name"
                }
                $headers = @($elf.ProgramHeaders | ForEach-Object { $_.ProgramHeader })
                $loads = @($headers | Where-Object { $_.Type.Value -eq 1 })
                if ($loads.Count -eq 0) { throw "APK ELF has no LOAD segments: $abi/$name" }
                foreach ($load in $loads) {
                    if ($load.Alignment -lt 16384 -or (($load.VirtualAddress - $load.Offset) % 16384) -ne 0) {
                        throw "APK ELF is not 16 KB aligned: $abi/$name"
                    }
                }
                foreach ($library in @($elf.NeededLibraries)) {
                    if ($library -notin @('libc.so', 'libm.so', 'libdl.so', 'liblog.so', 'libc++_shared.so')) {
                        throw "Unexpected APK ELF dependency: $abi/$name needs $library"
                    }
                }
                if ($name -ne 'libc++_shared.so') {
                    $interpreter = @($headers | Where-Object { $_.Type.Value -eq 3 })
                    if ($interpreter.Count -ne 1 -or $interpreter[0].FileSize -lt 2 -or $interpreter[0].FileSize -gt 128) {
                        throw "APK native executable has no valid interpreter: $abi/$name"
                    }
                    $stream = [IO.File]::OpenRead($file)
                    $reader = [IO.BinaryReader]::new($stream)
                    try {
                        $null = $stream.Seek($interpreter[0].Offset, [IO.SeekOrigin]::Begin)
                        $loaderBytes = $reader.ReadBytes($interpreter[0].FileSize)
                        if ($loaderBytes.Length -ne $interpreter[0].FileSize -or $loaderBytes[-1] -ne 0) {
                            throw "Native executable interpreter is truncated or not NUL terminated: $abi/$name"
                        }
                        $loader = [Text.Encoding]::ASCII.GetString($loaderBytes).TrimEnd([char]0)
                        if ($loader -ne '/system/bin/linker64') { throw "Native executable uses another platform loader: $loader" }
                    } finally { $reader.Dispose() }
                }
                Write-Output "Verified APK ELF: $abi/$name"
            }
            Write-Output "Verified resource archive and compiler headers: $abi"
        } finally { $resources.Dispose(); $resourceStream.Dispose() }
    }
} finally { $apkArchive.Dispose() }
Write-Output "Android APK artifacts verified: $Apk"
Write-Output 'Device execution remains unverified.'
