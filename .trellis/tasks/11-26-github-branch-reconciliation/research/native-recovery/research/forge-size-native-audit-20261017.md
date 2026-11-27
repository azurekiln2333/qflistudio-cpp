# Forge OHOS native size audit — 2026-10-17 (measurement record, no production change)

Status: **audit only**. No CMake/config/production edit was made. The toolchain
(`qfli_toolchain/ohos-wasi.zip`) and the shipped `libqfli_ohos_runner.so` are
byte-identical to before this audit. Nothing below is a shipping recommendation.

HAP `build/ohos/hap/entry-default-signed.hap` component sizes (measured, bytes):

| component | bytes | notes |
| --- | --- | --- |
| `libqfli_ohos_runner.so` | 93,430,096 | already stripped in HAP |
| `qfli_toolchain/ohos-wasi.zip` | 16,703,195 | asset |
| `libflutter.so` | 16,286,544 | Flutter engine (arm64) |
| `libapp.so` | 13,321,136 | Dart AOT |
| `libc++_shared.so` | 1,262,504 | SDK runtime |

Runner ELF (from `.cxx/.../release/arm64-v8a/build.ninja`, `CMAKE_BUILD_TYPE=Release`,
`-O2 -DNDEBUG -fvisibility=hidden -ffunction-sections -fdata-sections`): `.debug*=0`,
`.symtab/.strtab=0`, exported dynamic symbols = 2. No debug bloat in the shipped lib.

## Measured experiment (scratch only, NOT validated, NOT shipped)

Relinked the exact production link line (`ninja -t commands libqfli_ohos_runner.so`,
unchanged flags, same `.o` + `libqfli_compiler.a` + `libqfli_wasm.a`, same SDK
`clang++`/`ld.lld`) into `native/build/forge-size-experiment/` with only
`-Wl,--gc-sections` appended. Current `.so`/HAP/toolchain untouched.

| build | unstripped | `llvm-strip --strip-unneeded` |
| --- | --- | --- |
| baseline | 125,245,760 | 93,430,096 |
| `--gc-sections` | 111,276,832 | 84,015,296 |

**Measured scratch delta, stripped: 9,414,800 B (10.08%), i.e. 93,430,096 →
84,015,296.** Unstripped delta: 13,968,928 B (11.15%). Section changes:
`.text` 66,217,584 → 60,231,896; `.rodata` 6,851,229 → 6,479,822;
`.eh_frame` 8,353,764 → 7,148,860; `.rela.dyn` 5,239,992 → 4,357,632.
Exported dynamic symbols still 2.

This is a size measurement only. It carries **no runtime validation** — the
scratch library was never installed, launched or exercised, so nothing is
claimed about exceptions, threads, unwinding, compiler or interpreter behavior.

## Already-applied build characteristics (observed, unchanged)

- Release `-O2 -DNDEBUG`, hidden visibility, function/data sections, `--exclude-libs,ALL`.
- HAP stripping is active: the unstripped→stripped gap is
  125,245,760 − 93,430,096 = **31,815,664 B** of symbol/debug data, already removed
  from the shipped library.

## Deferred candidate (not approved, not applied)

`-Wl,--gc-sections` on the `qfli_ohos_runner` link step: measured 9,414,800 B
scratch reduction. Deferred because it has had no device/runtime validation and
would change the linked image of the validated compiler/runtime path.

## Toolchain asset composition (inventory only — keep intact)

`qfli_toolchain/ohos-wasi.zip` = 16,703,195 B compressed, 4,115 entries:
`share/wasi-sysroot` 14,765,015 B, `lib` (clang runtime libs) 978,792 B,
`licenses` 21,618 B, `toolchain.json` 2,406 B compressed.

Within the sysroot: `include` 5,267,994 B over 3,784 entries, split evenly between
`wasm32-wasip1` (1,892 files) and `wasm32-wasip1-threads` (1,892 files) at equal
compressed size; `lib` 9,497,021 B over 55 entries, dominated by
`lib/wasm32-wasip1/eh/libc++.a` (2,674,786 B comp),
`lib/wasm32-wasip1-threads/eh/libc++.a` (2,675,058 B comp),
`libc.a` (1,056,420 / 1,144,193 B comp) and `libc.so` (742,541 B comp).

Static archives participate in supported linking; other files have not been
verified safe to remove. Exception, thread,
unwind, `libc`/`libc++` and clang-runtime resources are **out of scope**: no
pruning, dedup or repackaging is proposed; the toolchain must stay intact.

## Risky / out of scope

- Any LLVM/WasmEdge TU trimming, LTO, `-Os`, target or thread-loss change: needs a
  full `native/toolchain/build-ohos-portable.sh` rebuild and alters the validated
  archives.
- Any change to the packaged WASI libc/libc++/unwind/thread resources.
- Flutter engine and Dart AOT sizes are SDK/toolchain owned; not adjustable here.

## Conclusion

The shipped native library is already release-optimized and stripped; the
31,815,664 B unstripped→stripped gap is already reclaimed in the HAP. The only
measurement produced here is the deferred `--gc-sections` scratch delta of
9,414,800 B, recorded for later evaluation only.
