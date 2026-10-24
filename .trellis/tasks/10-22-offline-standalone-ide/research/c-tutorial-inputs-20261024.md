# C/C++ tutorial input fixtures — October 24, 2026

Status: published source checkpoint `5c7bae3c5922cf9813ed423c89a41f03dad034b8`
has exact tested tree `f268e0fe1d2df4b926ecc2f2ecdecc10ee7b5439`, against core
`2f9039a3ba95449679b17257b0313c1ee3644a2c`. All 31 selected tests, three-file
analysis, isolated generator parity and 200-pair staged consistency passed. No
C program or device was executed. Global Note551 explicitly released to C546;
C accepted at 554 and automatically released to SQL527 at 555. SQL then deferred
to Rust533. No historical window was replayed.

The production tutorial JSON omitted `inputFixtures` for four original lessons:

| Tutorial | Exact stdin |
| --- | --- |
| c-tutorial-026 | `17 5\n` |
| c-tutorial-027 | `hello world\n` |
| cpp-tutorial-004 | `7 35\n` |
| cpp-tutorial-021 | `Alice 25\nHello World\n` |

The paired examples already carry those bytes. `LocalContentAdapter` can recover
them through its paired-example fallback, so this audit does not establish a
failure of the ordinary tutorial UI. It establishes incomplete raw lesson data
and a verifier gap: the old verifier never compared tutorial/example stdin.

The source batch preserves the existing one-line generator fix and its verifier
`--report` option. It adds only the four lesson fields to bundled data, requires
exact authored/staged identities and stdin, rejects duplicate/empty row IDs, and
independently retains all original C/C++ example IDs 001..100. Exact author/asset
equality alone would accept jointly truncated sets; the original-ID check and a
negative test retaining all three levels prevent that false success. Extra future
authored IDs remain possible.

`test/forge_tutorial_fixture_test.dart` has nine cases. Four load the production
repository in native and portable modes, assert raw lesson input before fallback,
then use the actual adapter and `CodeImportService` to check source and
`input.txt` bytes. Five cover complete inventory, input corruption, equal-count
substitution/authored duplicates, row-reader duplicates, and joint truncation.
These are content/import checks, not C execution or OHOS device acceptance.

The isolated generator produced equivalent tutorial/example documents while
ignoring only `updatedAt`; it never changed the tested candidate's assets. The
verifier's `--no-native` stdout now explicitly says staged consistency with no
execution. The actual nine new cases, two repository cases and twenty pipeline
cases passed together. Three changed Dart files analyzed cleanly. This is a
selected suite, not a full app or shared-core pass.

The source checkpoint's four files were frozen with 339 input hashes, including
the app-local runtime package. Package mappings bind this exact C archive, the
published core archive and its vendored editor. Seven private step Jobs and the
separate publisher were terminal with zero active processes and exit 0.
Validation and commit took 16.646 seconds before bounded channel publication.
`c-tutorial-inputs-publication-20261024.json` and its `.artifacts` directory retain
the exact logs, commands, source/file identities and terminal records. Later
documentation commits leave these tested source blobs unchanged.

Read-only JSON comparison confirmed that the bundled change consists solely of
the four lesson fields: every original ID, source, output and metadata value is
unchanged. The example asset is unchanged. Prior native/portable reports retain
their original asset hashes and must not be relabelled as executions of the new
tutorial JSON. Current packaging, all-example toolchain rechecks, owning-app
header execution, device evidence and the later 160 additions remain open.

Only these four product paths belong to the tested source checkpoint:

- `tool/forge_content/generate_forge_content.dart`
- `tool/forge_content/verify_forge_content.dart`
- `tool/forge_content/staging/forge_tutorials.json`
- `test/forge_tutorial_fixture_test.dart`

The curriculum spec and this evidence are separate documentation. Shared core,
foreign assets, startup, signing, native and terminal work remain excluded.
