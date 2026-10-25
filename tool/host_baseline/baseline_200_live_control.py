#!/usr/bin/env python3
"""Short live cross-process control window for the Windows coordinator.

SOURCE ONLY. This module authored no live process. It starts nothing at import
and performs no build. Authoring review is AST/compile only. Every real Job,
WSL, Linux worker and cancellation below is UNRUN until a separate grant.

Purpose: prove the control plane, not the 200-example baseline. One <=60 second
window exercises, with the same local OwnedJob implementation:

  W1 windows-normal-exit   root exits, Job active 0, real creation time kept
  W2 windows-child-alive   root terminal while a child lives -> empty() False
  W3 windows-timeout       per-step timeout -> TerminateJobObject drains group
  L1 linux-worker          one private Job runs the WSL Linux worker, real
                           owner-heartbeat loss cancels it, and release needs
                           per-step /proc identities and group-empty evidence

All three Windows controls run the frozen current Python executable
(sys.executable) with sleep children only. No network tool, no shell builtin
and no visible window: the path and sha256 are frozen into the manifest and
re-checked before execute.

The Windows phase must fit the total budget and refuses to start when the budget
is below the minimum needed. A missing or partial proof is a HOLD (return 2),
never a pass. Only our own Job is terminated; no foreign process is signalled and
no WSL distro is reset.

======================================================================
SHARED INTERFACE CONTRACT with p4 (build/baseline_200_linux_control.py)
======================================================================
Agree this contract with p4 BEFORE either side runs. p4 owns the worker file;
this coordinator only copies and binds it. Do not edit each other's files.

Paths. W is the Windows work directory. L = linux(W) is the same directory as a
``/mnt/<drive>/...`` path. All files below live directly in W / L.

Coordinator writes before the worker starts:
  control-launch.json   {schema:1, runId, nonce, linuxBudgetSeconds,
                         leaseFile, cancelFile, heartbeatStopRequestFile,
                         resultFile, heartbeatSeconds, leaseStaleSeconds}
  lease                 ascii counter; rewritten every 0.2 s while the
                        heartbeat holds. The coordinator STOPS rewriting it once
                        heartbeat-stop-request.json appears (real heartbeat loss).
  cancel                ascii reason; written on cooperative budget cancellation
  linux_runner.py       the root candidate module (build/baseline_200_linux.py)
  owned_job.py          the local OwnedJob candidate (build/baseline_200_owned_job.py)

Worker CLI is fixed:

  python3 <L>/linux_control.py --work <L> --budget 25

Worker obligations:
  1. Read <L>/control-launch.json and import linux_runner from <L>.
  2. Use linux_runner.Window(work, budget) and Window.run(...) for its control
     cases, so the reported steps are byte-for-byte Window.run records
     (stepId, command, cwdRelative, stem, timeoutSeconds, cleanupVerified,
      stdinSha256, leader, beforeCleanup, remainingBeforeReap, exitCode,
      remainingAfterReap, elapsedSeconds, stdoutSha256/stdoutB64,
      stderrSha256/stderrB64, plus failure/cleanupFailure when present).
  3. For the LAST case, write <L>/heartbeat-stop-request.json once. The
     coordinator then stops refreshing the lease, so Window.check() raises
     "Owner heartbeat stopped changing" after leaseStaleSeconds. Run that final
     control through Window.run so the raised step records failure exactly
     "Owner heartbeat stopped changing"; the heartbeat-loss case must list
     that stepId. That raised step must still carry cleanupVerified true.
  4. Clean up every owned process group, then write <L>/linux-control-result.json
     atomically (temp + replace + fsync) with exactly:

     {
       "schemaVersion": 1,
       "runId":   "<control-launch runId>",
       "nonce":   "<control-launch nonce>",
       "hostOnly": true,
       "installedDeviceEvidence": false,
       "cleanupVerified": true,
       "complete": true,
       "supervisor": {"pid": int, "pgrp": int, "session": int, "startTicks": int},
       "cases": [ {"name": str, "ok": true, "cleanupProof": "empty",
                   "stepIds": ["0000", ...]} ],
       "steps": [ <Window.run record>, ... ]
     }

  Cases must appear in this exact order (complete true):
  normal, descendant-survives-root, ignore-term-timeout,
  signal-latch-in-cleanup, heartbeat-loss. The heartbeat-loss case must
  reference a step whose "failure" is exactly "Owner heartbeat stopped
  changing"; scanning case prose or observed.checkError is never accepted.
  Per-case identity and group emptiness are re-derived from the referenced
  steps. Each step must also carry beforeCleanup (the leader identity is a
  member, every member in the leader group/private session) and
  remainingBeforeReap (the still-unreaped members, all zombies in that group).

  5. Never signal a process outside its own groups; never reset the distro.

  6. Window.run writes steps.json and one per-step {stem}.json sidecar in the
     case working directory. The coordinator re-reads both and requires them to
     equal the reported cases/steps; a result blob alone cannot release a slot.

Coordinator validation (a single boolean never releases the slot): nonce and
runId must match; schemaVersion == 1; hostOnly true; installedDeviceEvidence
false; complete true; the five cases must be present in the fixed order; every
case and every step must have cleanupVerified true AND remainingAfterReap == [];
every step leader must be a valid private-session identity (pid == pgrp ==
session, positive ints, distinct startTicks, never the supervisor pid); every
step's beforeCleanup/remainingBeforeReap identities, sidecar, stdout and stderr
bytes and sha256 must re-read from disk and match the reported step; and the
heartbeat-loss case must reference a step whose failure is exactly "Owner
heartbeat stopped changing", proving the loss actually fired rather than being
asserted in prose.
"""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
OWNER = ROOT / 'build/baseline_200_owned_job.py'
LINUX_RUNNER = ROOT / 'build/baseline_200_linux.py'
LINUX_WORKER = ROOT / 'build/baseline_200_linux_control.py'
SELF = ROOT / 'build/baseline_200_live_control.py'

SCHEMA = 1
WORK_PREFIX = 'baseline-200-live-'
DEFAULT_DISTRO = 'qfli-java-build'

TOTAL_MAX_SECONDS = 60
LINUX_BUDGET_SECONDS = 25
MIN_WINDOWS_SECONDS = 20
CLOSE_RESERVE_SECONDS = 6
MINIMUM_BUDGET = LINUX_BUDGET_SECONDS + MIN_WINDOWS_SECONDS + CLOSE_RESERVE_SECONDS  # 51

HEARTBEAT_SECONDS = 0.2
LEASE_STALE_SECONDS = 5
CANCEL_LEAD_SECONDS = 3
CASE_CLOSE_GRACE_SECONDS = 3

CASE_ORDER = ('normal', 'descendant-survives-root', 'ignore-term-timeout',
              'signal-latch-in-cleanup', 'heartbeat-loss')
HEARTBEAT_FAILURE = 'Owner heartbeat stopped changing'

# Windows controls use the frozen sys.executable and sleep children only: no
# network tool, no shell builtin and no visible window (CREATE_NO_WINDOW).
WINDOWS_NORMAL_SOURCE = 'import sys;sys.exit(0)'
WINDOWS_ROOT_SOURCE = (
    "import subprocess,sys,time;"
    "subprocess.Popen([sys.executable,'-c','import sys,time;time.sleep(float(sys.argv[1]))',sys.argv[1]],"
    "creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0));"
    "time.sleep(float(sys.argv[2]));"
    "sys.exit(0)"
)
CHILD_SLEEP_ARG = '30'
ROOT_SLEEP_ARG = '0'
TIMEOUT_SLEEP_ARG = '60'
NORMAL_CASE_SECONDS = 3
CHILD_CASE_SECONDS = 3
TIMEOUT_CASE_SECONDS = 2

LAUNCH_FILE = 'control-launch.json'
LEASE_FILE = 'lease'
CANCEL_FILE = 'cancel'
HEARTBEAT_STOP_FILE = 'heartbeat-stop-request.json'
RESULT_FILE = 'linux-control-result.json'
OWNER_FILE = 'windows-control-owner.json'
MANIFEST_FILE = 'manifest.json'

EVIDENCE_NAMES = (LAUNCH_FILE, LEASE_FILE, CANCEL_FILE, HEARTBEAT_STOP_FILE,
                  RESULT_FILE, OWNER_FILE, 'windows-control-owner.recovery.json',
                  'linux-worker.stdout', 'linux-worker.stderr')


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def linux(path):
    value = Path(path).resolve().as_posix()
    if len(value) < 3 or value[1:3] != ':/':
        raise ValueError('Only local Windows drive paths are supported')
    return '/mnt/' + value[0].lower() + value[2:]


def write_json(path, value):
    pending = path.with_suffix('.pending')
    with pending.open('w', encoding='utf-8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())
    pending.replace(path)


def read_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def load_owned_job(work):
    specification = importlib.util.spec_from_file_location('live_owned_job', work / 'owned_job.py')
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module.OwnedJob


def _open_streams(work, stem):
    return (work / f'{stem}.stdout').open('wb'), (work / f'{stem}.stderr').open('wb')


def close_case(job, case, grace=CASE_CLOSE_GRACE_SECONDS):
    """Always empty the private Job, record it, and close handles.

    Mirrors the reviewed schema-2 finalizer: a failing empty/stop/write never
    bypasses CloseHandle, and any cleanup error keeps the case non-passing.
    """
    errors = case.setdefault('cleanupErrors', [])
    empty = False
    proven = False
    try:
        try:
            empty = job.empty()
        except BaseException as error:
            errors.append('empty: ' + str(error))
        if not empty:
            try:
                job.stop()
            except BaseException as error:
                errors.append('stop: ' + str(error))
            deadline = time.monotonic() + grace
            while True:
                try:
                    empty = job.empty()
                except BaseException as error:
                    errors.append('empty after stop: ' + str(error))
                    break
                if empty or time.monotonic() >= deadline:
                    break
                time.sleep(0.05)
        case['jobAfterCleanup'] = dict(job.record)
        proven = bool(empty) and not errors
    finally:
        try:
            job.close()
            case['handlesClosed'] = True
        except BaseException as error:
            errors.append('close: ' + str(error))
            case['handlesClosed'] = False
            proven = False
    return proven


def case_normal_exit(OwnedJob, work, seconds, close_deadline, python_exe):
    job = OwnedJob()
    case = {'name': 'windows-normal-exit', 'command': [python_exe, '-c', WINDOWS_NORMAL_SOURCE],
            'ok': False}
    out = err = None
    try:
        out, err = _open_streams(work, 'windows-normal-exit')
        job.start(case['command'], ROOT, dict(os.environ), out, err)
        deadline = time.monotonic() + seconds
        empty = False
        while time.monotonic() < deadline:
            empty = job.empty()
            if empty:
                break
            time.sleep(0.05)
        record = dict(job.record)
        case['job'] = record
        case['createdSuspended'] = record.get('createdSuspended') is True
        case['assignedBeforeResume'] = record.get('assignedBeforeResume') is True
        case['creationFiletime100ns'] = record.get('creationFiletime100ns')
        case['rootTerminal'] = record.get('terminal') is True
        case['jobActiveProcesses'] = record.get('jobActiveProcesses')
        case['exitCode'] = record.get('exitCode')
        case['emptyAfterExit'] = bool(empty)
        case['ok'] = (case['emptyAfterExit'] and case['rootTerminal'] and
                      case['jobActiveProcesses'] == 0 and case['exitCode'] == 0 and
                      case['createdSuspended'] and case['assignedBeforeResume'] and
                      bool(case['creationFiletime100ns']))
    except BaseException as error:
        case['failure'] = str(error)
    finally:
        for stream in (out, err):
            if stream is not None:
                try:
                    stream.close()
                except BaseException as close_error:
                    case.setdefault('cleanupErrors', []).append('stream: ' + str(close_error))
        grace = max(0.0, close_deadline - time.monotonic())
        if not close_case(job, case, grace=grace):
            case['ok'] = False
    return case


def case_child_outlives_root(OwnedJob, work, seconds, close_deadline, python_exe):
    job = OwnedJob()
    case = {'name': 'windows-child-outlives-root', 'ok': False,
            'command': [python_exe, '-c', WINDOWS_ROOT_SOURCE, CHILD_SLEEP_ARG, ROOT_SLEEP_ARG]}
    out = err = None
    try:
        out, err = _open_streams(work, 'windows-child-outlives-root')
        job.start(case['command'], ROOT, dict(os.environ), out, err)
        deadline = time.monotonic() + seconds
        root_terminal = False
        observed_empty = None
        while time.monotonic() < deadline:
            empty = job.empty()
            if job.record.get('terminal') is True:
                root_terminal = True
                observed_empty = bool(empty)
                if not empty:
                    break
            time.sleep(0.05)
        record = dict(job.record)
        case['job'] = record
        case['creationFiletime100ns'] = record.get('creationFiletime100ns')
        case['rootTerminalBeforeStop'] = root_terminal
        case['emptyWhileChildAlive'] = observed_empty
        case['jobActiveProcesses'] = record.get('jobActiveProcesses')
        case['ok'] = (root_terminal and observed_empty is False and
                      isinstance(record.get('jobActiveProcesses'), int) and
                      record.get('jobActiveProcesses', 0) >= 1 and
                      bool(case['creationFiletime100ns']))
    except BaseException as error:
        case['failure'] = str(error)
    finally:
        for stream in (out, err):
            if stream is not None:
                try:
                    stream.close()
                except BaseException as close_error:
                    case.setdefault('cleanupErrors', []).append('stream: ' + str(close_error))
        grace = max(0.0, close_deadline - time.monotonic())
        case['emptyAfterStop'] = close_case(job, case, grace=grace)
        if not case['emptyAfterStop']:
            case['ok'] = False
    return case


def case_timeout_cleanup(OwnedJob, work, seconds, close_deadline, python_exe):
    job = OwnedJob()
    case = {'name': 'windows-timeout-cleanup', 'ok': False,
            'command': [python_exe, '-c', WINDOWS_ROOT_SOURCE, TIMEOUT_SLEEP_ARG, TIMEOUT_SLEEP_ARG]}
    out = err = None
    try:
        out, err = _open_streams(work, 'windows-timeout-cleanup')
        job.start(case['command'], ROOT, dict(os.environ), out, err)
        began = time.monotonic()
        still_running = True
        while time.monotonic() - began < seconds:
            if job.empty():
                still_running = False
                break
            time.sleep(0.05)
        record = dict(job.record)
        case['creationFiletime100ns'] = record.get('creationFiletime100ns')
        case['stillRunningAtTimeout'] = still_running
        case['timeoutSeconds'] = seconds
        case['jobBeforeStop'] = record
        case['jobActiveProcesses'] = record.get('jobActiveProcesses')
    except BaseException as error:
        case['failure'] = str(error)
    finally:
        for stream in (out, err):
            if stream is not None:
                try:
                    stream.close()
                except BaseException as close_error:
                    case.setdefault('cleanupErrors', []).append('stream: ' + str(close_error))
        grace = max(0.0, close_deadline - time.monotonic())
        case['emptyAfterStop'] = close_case(job, case, grace=grace)
        case['ok'] = (case.get('stillRunningAtTimeout') is True and
                      case['emptyAfterStop'] is True and
                      bool(case.get('creationFiletime100ns')))
    return case


def validate_identity(value):
    return (isinstance(value, dict) and
            all(type(value.get(key)) is int and value[key] > 0
                for key in ('pid', 'pgrp', 'session', 'startTicks')))


def valid_member(value, pgid):
    return validate_identity(value) and value.get('pgrp') == pgid


def ledger_problems(result, run_id, nonce, work):
    """Return every reason the Linux result cannot release the slot.

    No summary boolean releases the slot: the result must be complete, carry the
    fixed five cases in order, and re-point at steps whose /proc identities,
    group emptying, stdout/stderr bytes and hashes all re-read from disk.
    """
    problems = []
    if not isinstance(result, dict):
        return ['result-not-object']
    if result.get('schemaVersion') != SCHEMA:
        problems.append('schemaVersion')
    if result.get('runId') != run_id:
        problems.append('runId')
    if result.get('nonce') != nonce:
        problems.append('nonce')
    if result.get('hostOnly') is not True:
        problems.append('hostOnly')
    if result.get('installedDeviceEvidence') is not False:
        problems.append('installedDeviceEvidence')
    if result.get('cleanupVerified') is not True:
        problems.append('cleanupVerified')
    if result.get('complete') is not True:
        problems.append('complete')

    supervisor = result.get('supervisor')
    supervisor_pid = supervisor.get('pid') if validate_identity(supervisor) else None

    cases = result.get('cases')
    steps = result.get('steps')
    if not isinstance(cases, list) or not cases:
        problems.append('cases-empty')
        cases = []
    if not isinstance(steps, list) or not steps:
        problems.append('steps-empty')
        steps = []

    if [case.get('name') if isinstance(case, dict) else None for case in cases] != list(CASE_ORDER):
        problems.append('cases-order')

    step_by_id = {step.get('stepId'): step for step in steps if isinstance(step, dict)}
    leaders = set()
    for index, step in enumerate(steps):
        tag = f'step{index}'
        if not isinstance(step, dict):
            problems.append(tag + '.not-object')
            continue
        if step.get('stepId') != f'{index:04d}':
            problems.append(tag + '.stepId')
        if step.get('cleanupVerified') is not True:
            problems.append(tag + '.cleanupVerified')
        if step.get('remainingAfterReap') != []:
            problems.append(tag + '.remainingAfterReap')
        if type(step.get('exitCode')) is not int:
            problems.append(tag + '.exitCode')
        if not step.get('command'):
            problems.append(tag + '.command')
        leader = step.get('leader')
        if not validate_identity(leader):
            problems.append(tag + '.leader')
            continue
        if not (leader['pid'] == leader['pgrp'] == leader['session']):
            problems.append(tag + '.leader-not-private-session')
        if supervisor_pid is not None and leader['pid'] == supervisor_pid:
            problems.append(tag + '.leader-is-supervisor')
        stamp = (leader['pid'], leader['startTicks'])
        if stamp in leaders:
            problems.append(tag + '.leader-reused')
        leaders.add(stamp)
        before = step.get('beforeCleanup')
        remaining = step.get('remainingBeforeReap')
        if not isinstance(before, list) or not before:
            problems.append(tag + '.beforeCleanup')
        else:
            if any(not valid_member(p, leader['pid']) for p in before):
                problems.append(tag + '.beforeCleanup-group')
            if not any(p.get('pid') == leader['pid'] and p.get('startTicks') == leader['startTicks']
                       for p in before):
                problems.append(tag + '.beforeCleanup-leader')
        if not isinstance(remaining, list):
            problems.append(tag + '.remainingBeforeReap')
        elif any(not valid_member(p, leader['pid']) or p.get('state') != 'Z' for p in remaining):
            problems.append(tag + '.remainingBeforeReap-state')

    # Re-read sidecar, stdout and stderr bytes from disk for every step.
    if steps:
        steps_path = work / 'steps.json'
        if not steps_path.is_file():
            problems.append('steps.json-missing')
        else:
            try:
                if read_json(steps_path) != steps:
                    problems.append('steps.json-mismatch')
            except BaseException as error:
                problems.append('steps.json-unreadable:' + str(error))
    work_root = work.resolve()
    for index, step in enumerate(steps):
        tag = f'step{index}'
        if not isinstance(step, dict):
            continue
        relative, stem = step.get('cwdRelative'), step.get('stem')
        if not isinstance(relative, str) or not isinstance(stem, str) or Path(stem).name != stem:
            problems.append(tag + '.cwd')
            continue
        cwd = (work / relative).resolve()
        if not cwd.is_relative_to(work_root):
            problems.append(tag + '.cwd-escape')
            continue
        sidecar = cwd / f'{stem}.json'
        if not sidecar.is_file():
            problems.append(tag + '.sidecar-missing')
        else:
            try:
                if read_json(sidecar) != step:
                    problems.append(tag + '.sidecar-mismatch')
            except BaseException as error:
                problems.append(tag + '.sidecar-unreadable:' + str(error))
        for label in ('stdout', 'stderr'):
            path = cwd / f'{stem}.{label}'
            if not path.is_file():
                problems.append(tag + '.' + label + '-missing')
                continue
            data = path.read_bytes()
            if sha(path) != step.get(label + 'Sha256'):
                problems.append(tag + '.' + label + '-sha')
            try:
                if base64.b64decode(step.get(label + 'B64', ''), validate=True) != data:
                    problems.append(tag + '.' + label + '-b64')
            except BaseException as error:
                problems.append(tag + '.' + label + '-b64-unreadable:' + str(error))

    step_ids = set(step_by_id)
    for index, case in enumerate(cases):
        tag = f'case{index}'
        if not isinstance(case, dict):
            problems.append(tag + '.not-object')
            continue
        if not isinstance(case.get('name'), str) or not case.get('name'):
            problems.append(tag + '.name')
        ids = case.get('stepIds')
        if not isinstance(ids, list) or not ids:
            problems.append(tag + '.stepIds')
            continue
        if any(item not in step_ids for item in ids):
            problems.append(tag + '.stepIds-unknown')
        case_steps = [step_by_id[item] for item in ids if item in step_by_id]
        if not case_steps:
            problems.append(tag + '.no-steps')
            continue
        if case.get('ok') is not True:
            problems.append(tag + '.ok')
        if case.get('cleanupProof') != 'empty':
            problems.append(tag + '.cleanupProof')
        if not all(step.get('cleanupVerified') is True and step.get('remainingAfterReap') == []
                   for step in case_steps):
            problems.append(tag + '.step-ledger')
        if not any(validate_identity(step.get('leader')) for step in case_steps):
            problems.append(tag + '.leader')

    # Heartbeat proof must be the heartbeat case's referenced step failure text.
    heartbeat = next((case for case in cases
                      if isinstance(case, dict) and case.get('name') == 'heartbeat-loss'), None)
    if heartbeat is None:
        problems.append('heartbeat-case-missing')
    else:
        ids = heartbeat.get('stepIds')
        referenced = [step_by_id[item] for item in ids
                      if isinstance(ids, list) and item in step_by_id]
        if not any(isinstance(step, dict) and step.get('failure') == HEARTBEAT_FAILURE
                   for step in referenced):
            problems.append('heartbeat-loss-unproven')

    return problems


def case_problems(cases):
    """Return reasons the three Windows control cases are not a proven pass."""
    problems = []
    expected = ['windows-normal-exit', 'windows-child-outlives-root', 'windows-timeout-cleanup']
    names = [case.get('name') for case in cases]
    if names != expected:
        problems.append('windows-cases-order')
    for case in cases:
        if case.get('ok') is not True:
            problems.append('windows-case-failed:' + str(case.get('name')))
        if case.get('handlesClosed') is not True:
            problems.append('windows-case-handles-open:' + str(case.get('name')))
        if case.get('cleanupErrors'):
            problems.append('windows-case-cleanup-error:' + str(case.get('name')))
    return problems


def prepare(distro):
    for source, label in ((OWNER, 'owned_job'), (LINUX_RUNNER, 'linux_runner'),
                          (LINUX_WORKER, 'linux_control'), (SELF, 'live_control')):
        if not source.is_file() or source.stat().st_size == 0:
            raise ValueError(f'Required prepared input is missing or empty: {source} ({label}). '
                             'Confirm the shared interface with p4 before preparing.')
    python_exe = Path(sys.executable).resolve()
    if not python_exe.is_file():
        raise ValueError('Current Python executable is unavailable for the Windows controls')
    run_id = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8]
    work = ROOT / 'build' / (WORK_PREFIX + run_id)
    work.mkdir()
    copies = [(LINUX_RUNNER, 'linux_runner.py'), (LINUX_WORKER, 'linux_control.py'),
              (OWNER, 'owned_job.py')]
    for source, name in copies:
        shutil.copyfile(source, work / name)
    inputs = [SELF, LINUX_RUNNER, LINUX_WORKER, OWNER] + list(work.iterdir())
    manifest = {'schema': SCHEMA, 'sourceOnlyCandidate': True, 'runId': run_id,
                'nonce': uuid.uuid4().hex, 'distro': distro,
                'linuxBudgetSeconds': LINUX_BUDGET_SECONDS,
                'totalMaxSeconds': TOTAL_MAX_SECONDS,
                'minimumBudgetSeconds': MINIMUM_BUDGET,
                'heartbeatSeconds': HEARTBEAT_SECONDS,
                'leaseStaleSeconds': LEASE_STALE_SECONDS,
                'pythonExecutable': {'path': str(python_exe), 'sha256': sha(python_exe)},
                'preparedAt': now_iso(), 'executed': False,
                'inputs': [{'windowsPath': str(p.resolve()), 'linuxPath': linux(p),
                            'sha256': sha(p)} for p in inputs]}
    write_json(work / MANIFEST_FILE, manifest)
    print(work)
    print('PREPARED ONLY. Real Job creation, WSL start, Linux cancellation and the '
          'heartbeat-loss control remain UNRUN. Confirm the p4 interface before any grant.')
    return 0


def run_linux_worker(OwnedJob, work, manifest, record, began, deadline, active_deadline):
    run_id = manifest['runId']
    nonce = manifest['nonce']
    launch = {'schema': SCHEMA, 'runId': run_id, 'nonce': nonce,
              'linuxBudgetSeconds': LINUX_BUDGET_SECONDS,
              'leaseFile': LEASE_FILE, 'cancelFile': CANCEL_FILE,
              'heartbeatStopRequestFile': HEARTBEAT_STOP_FILE, 'resultFile': RESULT_FILE,
              'heartbeatSeconds': HEARTBEAT_SECONDS, 'leaseStaleSeconds': LEASE_STALE_SECONDS,
              'createdAt': now_iso()}
    write_json(work / LAUNCH_FILE, launch)
    lease = work / LEASE_FILE
    lease.write_text('0', encoding='ascii')
    linux_work = linux(work)
    command = ['wsl.exe', '-d', manifest['distro'], '--', 'python3',
               linux_work + '/linux_control.py', '--work', linux_work,
               '--budget', str(LINUX_BUDGET_SECONDS)]
    record['linuxCommand'] = command
    job = OwnedJob()
    sequence = 0
    heartbeat_stopped_at = None
    cancel_at = None
    drained = False
    out = err = None
    try:
        out, err = _open_streams(work, 'linux-worker')
        job.start(command, ROOT, dict(os.environ), out, err)
        record['linuxJobStart'] = dict(job.record)
        worker_start = time.monotonic()
        linux_hard = min(worker_start + LINUX_BUDGET_SECONDS, active_deadline)
        cancel_from = max(worker_start, linux_hard - CANCEL_LEAD_SECONDS)
        while True:
            now = time.monotonic()
            stop_requested = (work / HEARTBEAT_STOP_FILE).exists()
            if stop_requested and heartbeat_stopped_at is None:
                heartbeat_stopped_at = now
                record['heartbeatStoppedAtSeconds'] = round(now - began, 3)
            if heartbeat_stopped_at is None:
                sequence += 1
                lease.write_text(str(sequence), encoding='ascii')
            if cancel_at is None and now >= cancel_from:
                try:
                    (work / CANCEL_FILE).write_text('outer budget', encoding='ascii')
                except BaseException as error:
                    record.setdefault('errors', []).append('cancel write: ' + str(error))
                cancel_at = now
            if now >= linux_hard:
                job.stop()
                record['forcedStop'] = True
                break
            if job.empty() and (work / RESULT_FILE).exists():
                break
            time.sleep(HEARTBEAT_SECONDS)
        # Hold the handle until BOTH the Linux result and the Job are terminal,
        # but never poll past the active deadline (close reserve is untouched).
        while time.monotonic() < active_deadline:
            if job.empty() and (work / RESULT_FILE).exists():
                break
            time.sleep(0.1)
    except BaseException as error:
        record.setdefault('errors', []).append('linux phase: ' + str(error))
        try:
            (work / CANCEL_FILE).write_text('Windows owner failure', encoding='ascii')
        except BaseException as cancel_error:
            record.setdefault('errors', []).append('cancel write: ' + str(cancel_error))
    finally:
        for stream in (out, err):
            if stream is not None:
                try:
                    stream.close()
                except BaseException as close_error:
                    record.setdefault('errors', []).append('stream: ' + str(close_error))
        grace = max(0.0, deadline - time.monotonic())
        drained = close_case(job, record, grace=grace)
    record['linuxJobEmptyAfterClose'] = bool(drained)
    return drained


def execute(work, grant, budget):
    if os.name != 'nt' or not grant.strip():
        raise ValueError('Windows and a concrete coordinator slot grant are required')
    if type(budget) is not int or budget < MINIMUM_BUDGET or budget > TOTAL_MAX_SECONDS:
        raise ValueError(f'Budget must be an integer in {MINIMUM_BUDGET}..{TOTAL_MAX_SECONDS} '
                         f'seconds; refused {budget}. Too small a budget does not start.')
    work = work.resolve()
    if work.parent != (ROOT / 'build').resolve() or not work.name.startswith(WORK_PREFIX):
        raise ValueError('Work directory must be a prepared direct child of this repository build directory')
    manifest = read_json(work / MANIFEST_FILE)
    if manifest.get('schema') != SCHEMA or manifest.get('sourceOnlyCandidate') is not True:
        raise ValueError('Fresh schema-1 live-control manifest required')
    if manifest['executed'] or any((work / name).exists() for name in EVIDENCE_NAMES):
        raise ValueError('Each prepared control window is single-use; preexisting evidence rejected')
    for item in manifest['inputs']:
        if sha(item['windowsPath']) != item['sha256']:
            raise ValueError('Prepared input changed: ' + item['windowsPath'])
    python_record = manifest.get('pythonExecutable') or {}
    python_exe = python_record.get('path')
    if (not isinstance(python_exe, str) or not Path(python_exe).is_file() or
            sha(Path(python_exe)) != python_record.get('sha256')):
        raise ValueError('Frozen Python executable changed or missing; re-prepare required')
    manifest['executed'] = True
    manifest['grant'] = grant
    manifest['budgetSeconds'] = budget
    write_json(work / MANIFEST_FILE, manifest)

    OwnedJob = load_owned_job(work)
    record = {'schema': SCHEMA, 'runId': manifest['runId'], 'nonce': manifest['nonce'],
              'grant': grant, 'budgetSeconds': budget, 'slotReleased': False,
              'hold': True, 'windowsCases': [], 'windowsProven': False,
              'linuxJobProven': False, 'evidenceVerified': False,
              'heartbeatLossObserved': False, 'errors': [], 'cleanupErrors': []}
    began = time.monotonic()
    deadline = began + budget
    active_deadline = deadline - CLOSE_RESERVE_SECONDS
    windows_deadline = active_deadline - LINUX_BUDGET_SECONDS
    try:
        plan = [(case_normal_exit, NORMAL_CASE_SECONDS),
                (case_child_outlives_root, CHILD_CASE_SECONDS),
                (case_timeout_cleanup, TIMEOUT_CASE_SECONDS)]
        for builder, seconds in plan:
            remaining = windows_deadline - time.monotonic()
            if remaining <= 0:
                record['errors'].append('windows budget exhausted before: ' + builder.__name__)
                break
            record['windowsCases'].append(
                builder(OwnedJob, work, min(seconds, remaining), windows_deadline, python_exe))
        problems = case_problems(record['windowsCases'])
        record['windowsProblems'] = problems
        record['windowsProven'] = not problems
        if record['windowsProven'] and time.monotonic() < active_deadline:
            record['linuxJobProven'] = bool(run_linux_worker(
                OwnedJob, work, manifest, record, began, deadline, active_deadline))
            result_path = work / RESULT_FILE
            if result_path.exists():
                try:
                    result = read_json(result_path)
                except BaseException as error:
                    record['errors'].append('result parse: ' + str(error))
                else:
                    problems = ledger_problems(result, manifest['runId'], manifest['nonce'], work)
                    record['linuxProblems'] = problems
                    record['evidenceVerified'] = not problems
                    record['heartbeatLossObserved'] = 'heartbeat-loss-unproven' not in problems
                    record['linuxCases'] = len(result.get('cases') or [])
                    record['linuxSteps'] = len(result.get('steps') or [])
            else:
                record.setdefault('linuxProblems', []).append('result-missing')
    except BaseException as error:
        record['errors'].append('execute: ' + str(error))
        try:
            (work / CANCEL_FILE).write_text('Windows owner failure', encoding='ascii')
        except BaseException as cancel_error:
            record['errors'].append('cancel write: ' + str(cancel_error))
    finally:
        record['elapsedSeconds'] = round(time.monotonic() - began, 3)
        record['slotReleased'] = bool(record['windowsProven'] and record['linuxJobProven'] and
                                      record['evidenceVerified'] and record['heartbeatLossObserved'] and
                                      not record['errors'])
        record['hold'] = not record['slotReleased']
        try:
            write_json(work / OWNER_FILE, record)
        except BaseException as error:
            record['errors'].append('durable write: ' + str(error))
            record['slotReleased'] = False
            record['hold'] = True
            try:
                write_json(work / 'windows-control-owner.recovery.json', record)
            except BaseException as recovery_error:
                record['durabilityFailure'] = str(recovery_error)
    print(json.dumps(record, indent=2))
    if not record['slotReleased']:
        print('HOLD: Windows Job, Linux step ledger and heartbeat-loss evidence are not all proven.')
        return 2
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--prepare', action='store_true')
    group.add_argument('--execute', type=Path)
    parser.add_argument('--grant', default='')
    parser.add_argument('--budget', type=int, default=TOTAL_MAX_SECONDS)
    parser.add_argument('--distro', default=DEFAULT_DISTRO)
    args = parser.parse_args()
    if args.prepare:
        return prepare(args.distro)
    return execute(args.execute, args.grant, args.budget)


if __name__ == '__main__':
    raise SystemExit(main())
