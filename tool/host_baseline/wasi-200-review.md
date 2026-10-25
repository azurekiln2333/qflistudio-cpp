# Independent review of the WASI 200-example host run

Review date: 2026-10-26.
Evidence directory: `build/baseline-200-v2-wasi-20261025T172552Z-f5f939bf`.
Run ID: `20261025T172552Z-f5f939bf`.
Consumed grant: `C-wasi200-20261026-01`.
Archived raw records:
`.trellis/tasks/10-22-offline-standalone-ide/research/host-baseline-20261026/wasi/`.

## Result

A separate read-only calculation reproduced **200/200 passing examples**:
100 C IDs (`c-example-001` through `c-example-100`) and 100 C++ IDs
(`cpp-example-001` through `cpp-example-100`). The frozen inventory and result
list contain exactly these 200 unique IDs.

The calculation read the raw evidence without importing or running the
verifier, compiler, runtime probe, examples, WSL, or process-control helpers.
It checked each frozen source, stdin fixture, chosen expected output, compile
step, and execute step. All 200 compile steps and 200 execute steps exited
with code 0. All example execution stderr streams were empty. Every example
compile command records the compiler probe's `--threads` option.

All **200 stdout streams matched their chosen expected outputs byte for byte**.
There were **zero byte-exact differences**.

## Expected outputs and normalization

The comparison policy decodes strict UTF-8, replaces CRLF with LF, strips all
final LF characters, requires execution exit status 0, and requires empty
execution stderr. It preserves spaces and internal newlines. The independent
calculation reproduced that policy. No normalization change was required to
make any of these 200 recorded outputs pass.

The WASI phase chooses `portableExpectedOutput` when that frozen field exists.
Only two examples have that override:

| Example | Native expectation | WASI expectation |
| --- | --- | --- |
| `c-example-067` | `errno=2` | `errno=44` |
| `c-example-072` | `os=linux` | `os=wasi` |

The remaining lines in `c-example-067` are identical. These are explicit
frozen platform expectations, not output normalization or post-run edits.

## Actual finite-stdin transport

The first three ledger steps compile the `fgets`/`fputs` control and execute
it twice with distinct finite input files. The compilation exits with code 0.
The following two recorded executions each exit with code 0, have empty
stderr, and return stdout exactly equal to their own input marker:

| Step | Input and expected stdout |
| --- | --- |
| `0001` | `baseline-stdin-alpha\n` |
| `0002` | `baseline-stdin-beta\n` |

The markers end in an actual LF byte. The control source reads from `stdin`
with `fgets` and writes the received bytes with `fputs`. This establishes
finite stdin transport through the recorded host compiler/runtime probes.
It does not establish interactive stdin in a packaged app or on a device.

## Ledger, identities, and cleanup

There are **403 sequential ledger steps and 403 distinct leader identities**:
one stdin-control compile, two stdin-control executions, and 200 example
compile/execute pairs. Each recorded leader PID equals its private process
group and session ID. Each before-cleanup list contains its matching leader
PID/start-tick identity. Members belong to the recorded group, and any members
left before reaping are recorded as zombies in that group.

All **403 steps** record verified cleanup and empty `remainingAfterReap` lists.
All 403 JSON sidecars match their ledger entries. All 1,209 stream files match
their SHA256 values, and every stdout/stderr Base64 payload matches its file.
The 400 example step references are distinct and point to the correct
example directories and compile/execute step types.

The report's embedded ledger matches `steps.json`. Start, report, completion,
and launch records agree on run identity, nonce, and supervisor identity.
The manifest, report, ledger, and SDK-inventory hashes match their references.
No inconsistency arose in these checks.

The Windows owner record reports suspended creation and assignment before
resume for PID `58204`, creation FILETIME `134374310758372397`.
It records terminal exit code 0, Job active-process count 0, closed handles,
no cleanup errors, verified evidence, and a released slot.
Its recorded elapsed time is 751.145 seconds. This audit checks the durable
record rather than independently observing the historical live handle.

## Recorded tool identities and SDK inventory

| Recorded tool path | Recorded SHA256 |
| --- | --- |
| `native/build/compiler-linux/qfli_compiler_probe` | `86287e7dad2a24f87ae28d0f5a0795aa075dc5d10e13340a32db56936b0ae44d` |
| `native/build/ohos-wasi-thread-probe/runtime-probe-reviewed` | `297a9f77e7fb56ba9da6939bb1a11cb5b7a78b4a73405424c9d0f50008e2440f` |

The recorded SDK inventory contains **18,739 entries with 18,739 unique paths**.
Its file SHA256 is
`1168956804a38fef4caeaacde271f41c21e43816abce3e6aa9d6a97f01a24e9e`.
This review read the inventory and checked its file hash. It did not rescan
the SDK or rehash the current probe binaries.

## Evidence fingerprints and archive checks

| Raw file | Recomputed SHA256 |
| --- | --- |
| `manifest.json` | `afaa872ee30da2cebc1f0b4d03de9b0c99b7b41f66aede6dc56a53a8fad053ad` |
| `report.json` | `6db6a293cb3f1c8939ea7b928e15e329e6c584fc2f64a155ad1d2811b0244373` |
| `steps.json` | `f6faa357535938b3ae85644d794d00a5dba0dd9de53518d537858e87e1768f0f` |

All eight files listed in the archived `sha256.json` match their corresponding
raw run files byte for byte. Their recomputed hashes and lengths match the
archive inventory. This includes the SDK inventory and Windows owner record.
The archived records do not contain every per-example stream sidecar; this
review checked those against the original run directory.

## Limits

This is actual host WASI evidence for the frozen inputs and recorded probes.
It does not establish current source-to-binary correspondence, packaged OHOS
behavior, or installed-device behavior. The run report explicitly marks
binary-source correspondence `UNPROVEN`, host-only evidence, and false
packaged/device evidence flags.

Local nonces, hashes, identities, and sidecars detect inconsistent or stale
records. They do not authenticate evidence against arbitrary same-user
forgery. Private POSIX process groups do not contain deliberate session escape.
A completed historical run does not authorize replay of its consumed grant.

This review added only this Markdown file. It did not modify scripts,
original evidence, SDK files, source files, or the Git index.
