# Experimental host baseline tooling snapshot

This directory preserves six byte-identical Python candidates from `build/`.
It makes the reviewed process-control tooling available in version control.
It does not add a production runtime or an application feature.
`snapshot-sha256.json` records each file's SHA256 and byte count.
The original comments still describe these files as ignored candidates because
this snapshot preserves the reviewed bytes.

## Evidence boundary

The historical C window `C-live-controls-20261026-01` passed eight actual host
controls: three Windows Job controls and five Linux process-group controls.
The controls cover normal exit, surviving descendants, timeout cleanup,
repeated cleanup signals, and owner heartbeat loss.
The root observed the outer command exit with code 0 and verified cleanup.

Those eight controls do not establish the 200-example native or WASI baseline.
The separately granted October 26 host runs subsequently passed all 200 native
programs and all 200 WASI programs, including an actual two-input stdin gate.
Their raw reports are under
`.trellis/tasks/10-22-offline-standalone-ide/research/host-baseline-20261026/`.
Packaged OHOS verification and installed-device verification remain open. Host execution does not prove that a packaged
binary matches the current source. Private POSIX process groups do not contain
a process that deliberately escapes its session.

The fake/stub suite in `baseline_200_control_test.py` is separate from the real
controls. Its historical 34 passing cases did not create subprocesses and do
not prove operating-system containment.

## Restore the reviewed layout

Read the CLI definitions and execution code before using this snapshot.
Run the commands from the repository root in PowerShell.
The launchers derive the repository root from their location under `build/`.
Do not launch them directly from `tool/host_baseline/`.
Restore all six files together after coordinating ownership of existing
`build/baseline_200_*.py` candidates:

```powershell
$baselineFiles = @(
  'baseline_200_window.py',
  'baseline_200_linux.py',
  'baseline_200_owned_job.py',
  'baseline_200_control_test.py',
  'baseline_200_live_control.py',
  'baseline_200_linux_control.py'
)
New-Item -ItemType Directory -Path build -Force | Out-Null
foreach ($baselineFile in $baselineFiles) {
  Copy-Item -LiteralPath (Join-Path tool/host_baseline $baselineFile) -Destination (Join-Path build $baselineFile)
}
```

Verify the restored bytes against `snapshot-sha256.json` before preparation.
The launchers require Windows, Python, WSL, and the selected WSL distribution.
The default distribution is `qfli-java-build`.
Native runs require Linux `gcc` and `clang++`.
WASI runs require the compiler probe, reviewed runtime probe, and WASI SDK at
the paths specified by `baseline_200_window.py`.
These binary dependencies are not included in this snapshot.

## Prepare without execution

Preparation creates a new single-use work directory and freezes its inputs.
It does not start the live process controls or the compiler baseline.
Use the exact directory printed by each command:

```powershell
python -B build/baseline_200_live_control.py --prepare --distro qfli-java-build
python -B build/baseline_200_window.py --prepare native --budget 1200
python -B build/baseline_200_window.py --prepare wasi --budget 1200
```

The baseline phase budget accepts 60 through 1200 seconds.
Its manifest also sets an outer budget of phase budget plus 20 seconds.
Changing `--budget` at execution does not replace the prepared baseline budget.
Prepare a new directory if a bound input changes.

## Execute one freshly granted window

Obtain a new named serial execution grant for the chosen work directory and
budget. A grant must account for cleanup and final publication as well as
execution. Never replay a consumed grant or reuse an executed work directory.
A 60-second control grant does not authorize a 1200-second compiler baseline.

Replace the paths and grant placeholders with the newly prepared directory
and that window's actual grant before executing either command:

```powershell
python -B build/baseline_200_live_control.py --execute 'build/NEW-LIVE-CONTROL-DIRECTORY' --grant 'NEW-LIVE-CONTROL-GRANT' --budget 60
python -B build/baseline_200_window.py --execute 'build/NEW-BASELINE-DIRECTORY' --grant 'NEW-BASELINE-GRANT'
```

The live-control launcher accepts a total budget of 51 through 60 seconds.
The baseline launcher takes the phase budget from its frozen manifest.
The Linux worker scripts and the Windows Job helper are internal components.
Do not invoke the workers to bypass the owning Windows launcher.

Observe the outer command through termination. Review the recorded exact
process identities, terminal status, Job active-process counts, Linux group
cleanup, errors, and output hashes before releasing the serial window.
Keep ownership if cleanup cannot be proved. A timeout observation alone does
not establish that the process tree is terminal.

This publication step copied and hashed the scripts only. It did not execute
the fake suite, live controls, compilers, SDK builds, or device checks.
