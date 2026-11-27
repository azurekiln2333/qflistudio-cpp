# Forge OHOS toolchain size audit (2026-10-17)

Read-only audit of `ohos/entry/src/main/resources/rawfile/qfli_toolchain/ohos-wasi.zip`
(16,703,195 B / 15.9 MiB) against its producer
`native/toolchain/package-ohos-portable.ps1` and the runtime consumer
`ohos/entry/src/main/ets/plugins/QfliCNative.ets` +
`ohos/entry/src/main/cpp/qfli_ohos_portable.cpp`.

No edits, no repackaging, no build. Root does not authorize production removal;
everything below is advisory.

## 1. What is inside

| Metric | Value |
| --- | --- |
| entries | 4,115 |
| uncompressed | 60.98 MiB |
| compressed payload | 15.04 MiB, including manifest/licenses; ZIP container total 15.9 MiB |

| Tree | Files | Uncompressed |
| --- | --- | --- |
| `share/wasi-sysroot/lib` | 55 | 28.13 MiB |
| `share/wasi-sysroot/include` | 3,784 | 24.75 MiB |
| `lib/clang/22` | 269 | 8.04 MiB |
| licenses + `toolchain.json` | 7 | 0.07 MiB |

Bulk is four archives: `eh/libc++.a` 8.37 MiB x2 (wasip1 + -threads),
`libc.a` 3.21 + 2.95 MiB, `libc++abi.a` 1.38 MiB x2, plus
`wasm32-wasip1/libc.so` 1.94 MiB (compressed 0.72 MiB).

## 2. Duplicates

Root verified both include trees have the same relative paths and byte-identical
content: 1,892 files, 12,976,420 B raw and 2,633,997 B compressed payload **each**.
The two trees are `share/wasi-sysroot/include/wasm32-wasip1/` and
`share/wasi-sysroot/include/wasm32-wasip1-threads/`.
Whole-archive duplicate-content accounting reports 2,636,944 B (2.51 MiB) of
compressed payload; that includes small duplicates beyond the two header trees.
This does not mean all single and threaded library archives are identical.

**Verdict: dedup opportunity only.** Both trees are *separate, hard-required
runtime paths*:
- `package-ohos-portable.ps1` `required[]` lists 25 paths spanning both trees.
- `QfliCNative.ets` `REQUIRED_RESOURCES` (25 entries) and
  `qfli_ohos_portable.cpp:430-448` re-verify the same two-tree list.
- `manifest.supportedTargets` must contain both triples and
  `threading === 'wasi-threads'` or the toolchain is rejected (lines 251-254).

Deduplicating requires manifest + extractor changes (e.g. one physical copy +
per-target link at extract time). **Not a safe direct deletion.**

## 3. Removable-candidate analysis

### 3a. Architecture-intrinsic Clang headers — 129 files, 5.81 MiB raw / 0.47 MiB compressed

`lib/clang/22/include/` ships x86/AVX-512/NEON/Altivec/Hexagon/RISC-V/PPC/
MIPS/AMD/NVPTX/OpenCL/HLSL/SPIRV intrinsics. These are source headers, not
additional OHOS ABI binaries. Their transitive include dependencies have not
been fully checked; **compressed cost is only ~0.47 MiB**. Keep all of them.

### 3b. `share/wasi-sysroot/lib/wasm32-wasip1/libc.so` — 1.94 MiB raw / 0.72 MiB compressed

This file is **WASI Wasm data**, not an additional OHOS architecture library.
The initial report incorrectly inferred pass-through compilation from Dart
forwarding argv to `qfli_compiler_command`. The actual native entry calls
`native/compiler/compiler.cpp::parse_command` (lines 291-430), which has a flag
whitelist and rejects `-shared`, `-fPIC` and other unknown dash flags with
`Unsupported compiler flag`. Shared/reactor builds were not verified to work.

Ordinary supported links use static libraries. This makes dynamic data a
research candidate, but a complete dependency/removal regression audit has not
been performed. It is **not classified as safe to remove**, and no saving from
it is counted. Keep it intact under the user's toolchain constraint.

### 3c. Retain (required, do not touch)

- Both sysroot trees in full (validated above).
- All `.a` archives incl. `eh/` and `libwasi-emulated-*`.
- `lib/clang/22/include` wasm-relevant: `stddef.h`, `stdint.h`, `stdarg.h`,
  `intrin.h`, `wasm_simd128.h`.
- `lib/clang/22/lib/wasm32-unknown-wasip1{,-threads}/libclang_rt.builtins.a`.
- `toolchain.json`, licenses.

## 4. Result under the user's constraint

**Keep the toolchain ZIP and runner intact.** Duplicate header storage is
measurable, but preserving both runtime paths currently requires it. No SDK
removal or repackaging was performed or proposed for this audit's delivery.

Compressed payload groups are 5,080,719 B single libraries, 4,416,302 B threaded
libraries, 2,633,997 B each header tree, 258,852 B compiler builtins, 719,940 B
Clang builtin headers and 24,024 B licenses/manifest. These measurements do not
support the initial report's claim that 93 percent is reachable static archives,
or its estimate of a proven minimal viable trim. Those claims are withdrawn.
