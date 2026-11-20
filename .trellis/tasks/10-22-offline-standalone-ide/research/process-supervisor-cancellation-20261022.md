# Shared process supervisor cancellation audit

Started: 2026-10-22. Final validation: 2026-10-23 (Asia/Shanghai).
Scope: shared core process supervision and dedicated checks.
No C code, device deployment, debugger API/UI, import service or Python content
was modified by this batch. No commit or push was made by this worker.

## Confirmed baseline

`ManagedProcess._cancelInternal` closed stdin, sent the default TERM signal on
POSIX and then awaited the raw parent exit indefinitely. It did not enumerate or
terminate descendants. Cancellation cleaned up subscriptions immediately after
parent exit, unlike natural exit, so final pipe output could be discarded.

An additional race existed when natural exit had already begun waiting for
inherited pipes before cancellation started: that observer could clean up while
the cancellation operation was still pending. The new test holds stdin close
pending, completes the inherited output pipes and checks that ownership remains
until cancellation finishes.

## Implemented behavior

TERM has a 500 ms grace interval before KILL. Actual forced exit and final stdout
and stderr drain each have bounded two-second waits. A bounded failure retains
ownership; an independent observer waits for real resource completion instead of
reporting an elapsed timer as cleanup. Windows taskkill and its direct-handle
fallback are preserved.

Linux with libc pidfd functions and readable procfs pins the actual root identity,
checks child parent/start-time identity before and after pinning, pauses owned
parents while enumerating every thread's children, and signals only pinned
identities. No bare descendant PID, command-name matching or unowned group kill is
used. Inspection always resumes processes in finally. Waiting parents can reap
terminated children and emit final output. Acquired child identities survive
reparenting. Other POSIX/old libc/kernel paths provide bounded parent cancellation
only. Already-detached, unobserved daemons are outside this ownership boundary.

## Validation evidence

Windows host, configured Flutter SDK:

```text
flutter test --no-pub --reporter expanded test/process_supervisor_test.dart test/shell_command_test.dart test/terminal_manager_delegate_test.dart
48 passed

dart analyze lib/services/process_supervisor.dart lib/services/process_identity_ffi.dart lib/services/process_identity_stub.dart test/process_supervisor_test.dart tool/verify_process_supervisor.dart
No issues found
```

Windows SDKs: `D:/ProgramFiles/flutter_ohos/bin/flutter.bat` and
`D:/ProgramFiles/flutter_ohos/bin/cache/dart-sdk/bin/dart.exe` (Dart 3.11.5).
All commands exited successfully. Actual final output, relative to
`D:/MyNewProjects/qfli_studio_core/`:

| Log | Result |
| --- | --- |
| `build/process-supervisor-tests.log` | 48 passed |
| `build/process-supervisor-analyze.log` | No issues found |
| `build/process-supervisor-js-before.log` | Baseline standalone JS compile passed |
| `build/process-supervisor-js-after.log` | Final standalone JS compile passed |
| `build/process-supervisor-linux.log` | Four native Linux cases passed |

Native Linux checks used the working `qfli-java-build` WSL distribution, Linux
6.6.114.1-microsoft-standard-WSL2, glibc 2.39. Default Ubuntu was not changed; its
registered VHDX is missing. A separate earlier test distribution clears its tmp
directory on restart, so the verified SDK was placed in a persistent root cache.

Official pinned Dart 3.11.5 stable Linux x64 SDK was downloaded from the official
Dart archive, and `sha256sum -c` verified the published digest:

```text
57f3ab5ac24883060b1ff12bcdac472ed76563ec7364e88f8a6d41e4f0db075f
```

SDK cache: `/root/.cache/qfli-process-supervisor-sdk-3.11.5`.
The standalone check uses an empty temporary package config and imports only the
service plus Dart SDK libraries, avoiding the Windows Flutter package config.

```text
dart --packages=empty_packages.json /mnt/d/MyNewProjects/qfli_studio_core/tool/verify_process_supervisor.dart
PASS: ignored TERM escalates (521 ms)
PASS: background sleep is gone and shell output is drained (6 ms)
PASS: TERM-ignoring descendant is gone; unrelated sibling survives (523 ms)
PASS: TERM trap final stdout and stderr are drained (2 ms)
```

Both child checks require disappearance of the actual `/proc/<child>` directory,
not only parent exit or a zombie state. Each check also retains a separate sibling
sleep process and verifies it survives. Failure-only fixture cleanup uses pinned
identities too. Running this native check on Windows reports an explicit Linux
capability skip.

## Compatibility review

Standalone JS compilation of a consumer importing the baseline supervisor passed.
The first in-file FFI implementation failed compilation because dart:ffi is not
available on Web. This was caught before delivery and fixed in the approved
`lib/services/process_identity_ffi.dart` and `process_identity_stub.dart` helpers.
The supervisor selects the native helper only when `dart.library.ffi` exists.
The stub has no native dependency. Native handles check Linux, optional libc
symbols, successful pidfd acquisition and signal-zero support. Close is
idempotent and sends after close fail. Procfs ownership policy remains in the
supervisor; no descendant signal falls back to a numeric PID.

Final verification compiled the same minimal consumer for both baseline and
current supervisor using:

```text
dart compile js --no-source-maps <probe>/before.dart -o <probe>/before.js
dart compile js --no-source-maps <probe>/after.dart -o <probe>/after.js
```

`<probe>` is `%TEMP%/qfli-process-supervisor-web-probe`. Both consumers import
their supervisor and execute `void main() { print(ProcessSupervisor); }`.
`before.dart` imports the unchanged supervisor captured from core HEAD before the
change; `after.dart` imports the actual current core service through a file URI.
Both commands passed (96,520 JavaScript characters each). These are import/compile
checks, not a claim of browser process execution support.

Final changed code: `lib/services/process_supervisor.dart`, the two identity
helpers, `test/process_supervisor_test.dart` and
`tool/verify_process_supervisor.dart`. The dedicated core spec is
`.trellis/spec/backend/process-supervision.md`; core ignores that spec directory,
so an integrating commit must add this exact new spec path explicitly with force.

No host result proves OHOS packaged-process behavior. The shipped app's sandbox,
libc symbols and device lifecycle remain a distinct acceptance gate.
