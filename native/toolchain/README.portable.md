# Portable C/C++ Runtime

Forge's iOS backend embeds a signed static Clang/LLD compiler and a static
WasmEdge interpreter. User programs are compiled into WASI Preview 1 WebAssembly
data. The runtime does not enable LLVM AOT or JIT, load generated native code,
redirect the application's stdio, or change its current directory.

## Dependency Contract

`portable-dependencies.json` pins archive checksums for LLVM/Clang 22.1.0,
WASI SDK 33, WasmEdge commit `845df599e7b71c98b0c77990c3aa3a10022bbaae`, fmt, and
spdlog. Compiler/resource versions must stay synchronized. C uses C17; C++ uses
C++20. Each translation unit is compiled separately, and any C++ unit selects
C++ linking. Standard Wasm exceptions and the SDK's matching `libunwind` are
required; disabling C++ exceptions does not satisfy this backend's contract.

The tracked `native/portable/patches/wasmedge-interruptible-poll.patch` makes
WASI polling and sleep interruptible without changing their deadlines.
`wasmedge-static-archive.patch` replaces an old archive during incremental
builds; the pinned upstream archive already includes fmt/spdlog. Runtime CMake validates both
checksums and applies them to extracted source paths and FetchContent downloads.
The iOS script invokes the same checked helper before recording the approved
source digest and includes both patch hashes in `toolchain.json`.

The interpreter limits linear memory to 256 MB. WASI exposes the selected
project as `/`, independent stdin/stdout/stderr descriptors, and no inherited
environment. Missing `input.txt` means immediate stdin EOF. Input must be a
regular file. Files created by the program remain in the project. WASI Preview
1 does not provide general native OS APIs, process spawning, arbitrary native
dynamic libraries, or ordinary desktop networking/thread semantics.

## Build On macOS

Install Xcode with the iPhoneOS and simulator SDKs, CMake 3.24+, Ninja, Python 3,
and command line tools. From the repository root:

```bash
bash native/toolchain/build-ios-portable.sh --jobs 2
```

This downloads and verifies immutable archives, builds native host TableGen
tools, then cross-compiles three static slices: iPhoneOS arm64 and simulator
arm64/x86_64. Host SDK executables are not bundled. Compilation uses LLVM's
WebAssembly target only. WasmEdge is built with LLVM/JIT, plugins, optional tools,
and shared libraries disabled. The script merges native dependencies into one
archive per slice and combines simulator architectures with `lipo`.

Use `--device-only` or `--simulator-only` to build a subset. Xcode then supports
only the built platform; selecting an absent platform fails with its missing
library path. `--build-root PATH` selects a separate build cache. Existing
source trees are hashed before reuse; modified trees fail without overwriting
them. LLVM builds are large; lower `--jobs` when memory is constrained.

Default output:

```text
native/build/ios-portable/package/
  iphoneos/libqfli_portable.a
  iphonesimulator/libqfli_portable.a
  include/qfli_compiler.h
  include/qfli_wasm.h
  resources/sdk/
    toolchain.json
    share/wasi-sysroot/
    lib/clang/22/
    licenses/
ios/Flutter/NativeRuntime.generated.xcconfig
```

The generated, ignored xcconfig enables the native bridge and links the selected
static archive into Runner. Xcode's resource phase copies the SDK into
`Runner.app/forge-wasi-sdk` before normal app signing. The static archive becomes
part of the signed application executable; it is not a downloaded runtime
library. Without the generated xcconfig, Runner still compiles its channel
plugin and reports `available: false`. An enabled build fails if artifacts are
missing. Runtime availability additionally requires all SDK sentinel resources
and a recognized manifest in the actual app bundle. To disable the package,
remove the generated xcconfig; the next build removes stale bundled SDK data.

Dependency license texts are staged with the SDK. Distribution also requires
reviewing the WASI SDK release's wasi-libc and transitive license notices; the
SDK binary archive does not provide a complete separate notice collection.

## Flutter Channel Contract

The plugin registers through AppDelegate's implicit Flutter engine registry.
The existing FlutterSceneDelegate owns scene setup. Channels match Android:

| Channel or method | Payload |
| --- | --- |
| `qfli_forge/native`, `start` | `runId`, `type` (`c` or `cpp`), absolute `projectPath`, absolute `entryFile` |
| Start reply | `{available: true}` for accepted work, `{available: false}` for an unpackaged runtime |
| `qfli_forge/native`, `cancel` | `runId` |
| `qfli_forge/native/events` | `{runId, kind: stdout or stderr, text}` or `{runId, kind: exit, exitCode}` |

One run is active per plugin. Start requires a connected event listener and
rejects malformed arguments or an already active run. Compiler diagnostics are
stderr events. Pipe readers run concurrently with native work and preserve
empty lines and UTF-8 characters split across read buffers. The terminal event
is emitted once, after the compiler/interpreter returns, both pipe readers
finish, native sessions are destroyed, and temporary build files are removed.
No prior module executes after a compiler or link failure. Accepted cancellation
reports 130 after cleanup. Cancelling the event subscription or detaching the
engine also cancels native work. Events from a previous listener are not sent to
a new subscription.

Compiler and interpreter sessions retain borrowed descriptors until native work
returns. The bridge does not close active descriptors to interrupt a run.
Cancellation is cooperative in the compiler and interruptible in the Wasm
interpreter. Unlike Android's child process, the embedded compiler runs in the
app process; a native compiler/runtime fault can therefore terminate the app.

## Verification

Run portable compiler/interpreter fixtures using the host probes before shipping
an iOS package. These cover mixed C/C++, project headers/files, C++ exceptions,
stdin, separate output streams, nonzero exits, traps, memory limits, cancellation,
and repeated runs. Host fixtures verify the common native adapters. They do not
verify the Objective-C++ channel, Apple SDK compilation, signing, or device
execution.

On this Windows implementation host, Bash syntax and build-script input gates
can be checked. Xcode builds, XCTest, iOS simulator/channel execution and signed
physical-device execution are skipped because no Apple host/SDK is available.
No OHOS or device debugging is part of this task. Before declaring iOS runtime
verified, use macOS/Xcode to build Runner for each required platform and run the
same fixture matrix through its Flutter channel, including output drain and
cancel during compilation and execution.
