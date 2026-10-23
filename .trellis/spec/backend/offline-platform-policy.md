# Standalone C/C++ platform policy

## Scope and behavior

`ohos/entry/src/main/ets/entryability/EntryAbility.ets` owns the OHOS method
channel policy. This standalone product defines `OFFLINE_ONLY = true`.
`qflistudio/platform.openAgreement` and `openUrl`, and
`qflistudio/huawei_account.login`, return exactly one `OFFLINE_ONLY` error before
reading arguments or constructing browser, agreement-router or Account Kit
providers. All URL schemes are refused, including loopback and file URLs; local
file access uses the picker bridge.

Keep local `startupProgress`, `shareText` and picker dispatch reachable. Startup
progress accepts only finite numbers, clamps to 0..1 and emits the established
event. Preserve window background setup, superclass and generated plugin setup,
and `registerQfliNativeChannel(engine, abilityContext)` with its existing error
handling. Platform policy must not alter startup, signing or compiler ownership.

## Permission boundary

The C/C++ OHOS backend uses the signed in-process LLVM/WASI/WasmEdge route. It
has no JDWP transport or local preview listener requiring a network permission.
`module.json5` therefore omits `ohos.permission.INTERNET`; retain its other
permissions and product/device configuration. Changes to another product's
loopback requirements do not authorize adding this permission to C/C++.

## Behavioral checks and evidence limits

`node tool/test_c_offline_platform.cjs [EntryAbility.ets] [--require-startup]` transpiles the actual
handler with the installed SDK TypeScript compiler and executes it against local
platform doubles. It downloads nothing. The optional source path supports exact
staged-source and policy-disabled negative controls without replacing production
files. Both negative controls must fail because a remote path becomes reachable.

The check verifies zero argument reads and zero provider calls for denied
requests, exactly one result, native registration, dark/light window setup,
finite/clamped startup progress, local picker/share and unknown-method behavior.
The default accepts a source edition without a startup-progress handler and
checks its actual `notImplemented` behavior. Use `--require-startup` for an
edition containing the separately owned startup-progress implementation; that
mode requires finite/clamped progress and its real event dispatch. A policy-only
commit must not absorb that startup implementation just to satisfy this check.

It also checks the manifest's absence of INTERNET. It does not establish ArkTS
SDK type correctness, compiler execution, HAP permissions or installed-device
behavior. Run the existing compiler/runtime gates and preserve separate actual
HAP/device evidence before claiming those outcomes.
