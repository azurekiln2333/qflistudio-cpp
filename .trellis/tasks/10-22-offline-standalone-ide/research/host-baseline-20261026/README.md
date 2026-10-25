# Original 200-program host evidence, October 26, 2026

This is host evidence for the original 100 C and 100 C++ programs. It does not close the current OHOS package, installed-device, or binary-to-current-source correspondence gates. No new examples were added.

| Phase | Result | Actual steps | Runner seconds | Grant and channel |
| --- | --- | --- | --- | --- |
| Native GCC C17 / Clang C++20 | 200/200 pass | 402 | 104.184 | C-native200-20261026-01, ACCEPT644 / RELEASE645 |
| Existing WASI compiler / interpreter probes, threads enabled | 200/200 pass | 403 | 751.145 | C-wasi200-20261026-01, ACCEPT646 / RELEASE653 |

The native outputs were independently checked: all 200 also match expected stdout byte for byte. The WASI phase passed the actual two-input stdin transport gate before its 200 programs. It hashed 18,739 SDK files before execution and checked their paths and bytes again afterward. Both phases rechecked all bound source inputs and tools. The verifier compares strict UTF-8 output after CRLF normalization and removal of final newline characters, requires exit zero and empty stderr, and records byte-exact comparison separately.

## Terminal and cleanup observations

The root observed native outer tool session 94737 exit zero. Its exact Windows Job root PID 73608, creation FILETIME 134374307109045573, was terminal with active process count zero. All 402 Linux step groups were empty after reaping. ACCEPT644 at 19:38:30.757Z to RELEASE645 at 19:42:43.165Z was 252.408 seconds, within the separately granted 1,265-second end-to-end limit.

The root observed WASI outer tool session 19358 exit zero. Its exact Windows Job root PID 58204, creation FILETIME 134374310758372397, was terminal with active process count zero. All 403 Linux step groups were empty after reaping. ACCEPT646 at 19:44:35.639Z to RELEASE653 at 20:00:37.689Z was 962.050 seconds, within its separately granted 1,265-second end-to-end limit. Both owners recorded closed handles, verified evidence, and no cleanup errors. UTC dates in these channel records are October 25; local Asia/Shanghai date is October 26.

## Files and reproduction

Each phase folder preserves its raw manifest, launch identity, start/completion reports, final report, complete step ledger and Windows owner record. The native folder also preserves compiler version-step sidecars. The WASI folder preserves the SDK path/hash inventory, not SDK files. Each sha256.json inventories the copied raw bytes. The reports retain original absolute machine paths and process identities; these are historical observations, not portable identifiers.

The full step ledger contains raw stdin/stdout/stderr bytes as base64 with hashes and exact before/after group observations. Original generated case sidecars, executables and module binaries remain in the ignored build run directories; this is a report archive, not a complete runnable copy of those directories. The checked source catalogs remain under tool/forge_content/staging and are bound by the manifests.

The exact experimental verifier snapshot and fresh preparation instructions are in tool/host_baseline. Restore those bytes under build, prepare a new directory, and obtain a new named serial grant before executing. Historical grants and executed directories are single use. Host reports do not prove that the shipped ARM64 compiler/runtime matches current source, that the app can execute user-created mixed projects, or that any installed OHOS target passed.
