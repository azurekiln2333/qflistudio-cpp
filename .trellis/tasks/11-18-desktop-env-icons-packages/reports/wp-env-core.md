# WP-ENV-CORE report

Status: `DONE` for this work package. Full desktop acceptance is still pending.

The worktree changes remain uncommitted. The report does not establish cloud
build success or an end-to-end Windows, Linux or macOS setup flow.

The desktop toolchain environment now stores settings in application storage,
shares compiler lookup with `ClangProgramRunner`, supports managed toolchains,
and provides platform-specific setup actions. Desktop child processes receive
toolchain runtime paths. Web and mobile builds keep an inert environment.

Validation: `flutter analyze` passed. The toolchain lookup suite ran 17 tests
and passed. The real Windows download and compile flow was not run in this
integration pass. Linux and macOS setup actions were covered by injected tests
only.

## Follow-up verification

The 2025-03-05 LLVM-MinGW archive downloaded at 151,580,565 bytes. Its
SHA-256 is `d955112db27ebbefec0b1fc77d4fcfe7b51ed767912e74e4e00b4a63e9d3ac97`.
This corrects the earlier package constant.

The WinLibs archive inspection found its compiler under `mingw64/bin`. Its
configured archive root is now `mingw64`.

Code review found that setup moved the archive root directory itself to the
managed toolchain directory. Compiler lookup expects the archive root below
that directory. Setup now preserves the expected layout and removes the new
directory when compiler detection fails.

The setup button and UI flow were not run in a real Flutter desktop window.
The download, extraction and C/C++ compile-run path remains unverified end to
end.
