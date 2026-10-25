#!/usr/bin/env python3
"""SOURCE-ONLY candidate: short Linux control worker for the serial host window.

The parent copies this file into ``<work>/linux_control.py`` and runs it with::

    python3 <work>/linux_control.py --work <work> --budget 25

It imports the copied ``<work>/linux_runner.py`` (schema-2 ``Window``) and drives
five containment controls against real Python children. Every child stays in the
private POSIX process group that ``Window.run`` creates. Nothing calls ``setsid``,
``setpgid`` or ``start_new_session`` outside ``Window.run``.

Cleanup proof is three-valued: ``empty``, ``live``, ``unprovable``.
``unprovable`` keeps a hold. Permission failures are never treated as empty.
EPERM from ``killpg`` is never swallowed. No non-owned group is signalled.

UNRUN: this candidate has never been executed. It has launched no WSL session,
no compiler, no SDK probe, no real control window and no device action.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import sys
import threading
import time

SCHEMA_VERSION = 1
RESULT_NAME = 'linux-control-result.json'
LEDGER_NAME = 'steps.json'
STOP_REQUEST_NAME = 'heartbeat-stop-request.json'
RUNNER_NAME = 'linux_runner.py'
LAUNCH_NAME = 'control-launch.json'

CHILD_SOURCE = '''\
import signal
import sys
import time

mode = sys.argv[1]
if mode == 'ignore-term':
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
time.sleep(float(sys.argv[2]))
'''

ROOT_SOURCE = '''\
import os
import signal
import subprocess
import sys
import time

here = os.path.dirname(os.path.abspath(__file__))
mode, child_mode = sys.argv[1], sys.argv[2]
if mode == 'wait':
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
child = subprocess.Popen([sys.executable, os.path.join(here, 'child.py'),
                          child_mode, '60'])
sys.stdout.write('spawned %d\\n' % child.pid)
sys.stdout.flush()
time.sleep(60 if mode == 'wait' else 0.3)
'''

NORMAL_SOURCE = '''\
import sys
sys.stdout.write('control-normal\\n')
'''


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def write_json(path, value):
    path = Path(path)
    pending = path.with_suffix('.pending')
    with pending.open('w', encoding='utf-8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())
    pending.replace(path)


def write_probe(directory, name, text):
    path = directory / name
    path.write_text(text, encoding='utf-8')
    return path


def load_runner(work):
    """Import the copied schema-2 runner. Refuse anything that is not schema 2."""
    path = work / RUNNER_NAME
    if not path.is_file():
        raise SystemExit(f'Missing copied runner: {path}')
    spec = importlib.util.spec_from_file_location('baseline_linux_runner_copy', path)
    if spec is None or spec.loader is None:
        raise SystemExit(f'Cannot import runner copy: {path}')
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    for attribute in ('Window', 'identity', 'SCHEMA', 'CANCEL_SIGNALS'):
        if not hasattr(module, attribute):
            raise SystemExit(f'Runner copy lacks {attribute}: {path}')
    if module.SCHEMA != 2:
        raise SystemExit(f'Runner copy is not schema 2: {module.SCHEMA}')
    for method in ('run', 'check', 'cleanup'):
        if not callable(getattr(module.Window, method, None)):
            raise SystemExit(f'Runner copy Window lacks {method}()')
    return module, path


def read_launch(work):
    path = work / LAUNCH_NAME
    if not path.is_file():
        raise SystemExit(f'Missing control launch file: {path}')
    data = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(data, dict):
        raise SystemExit(f'{LAUNCH_NAME} must hold an object')
    for key in ('runId', 'nonce'):
        value = data.get(key)
        if not isinstance(value, str) or not value:
            raise SystemExit(f'{LAUNCH_NAME} requires a non-empty {key}')
    return data


def step_slice(window, before):
    return [step for step in window.steps[before:]]


def proof_of(steps):
    """Three-valued cleanup proof. A missing or unverified step proves nothing."""
    if not steps:
        return 'unprovable'
    if all(bool(step.get('cleanupVerified')) for step in steps):
        return 'empty'
    return 'unprovable'


def same_group_proven(record):
    """Every pre-cleanup member must sit in the leader's own process group."""
    leader = record.get('leader') or {}
    pgid = leader.get('pid')
    members = record.get('beforeCleanup') or []
    if not isinstance(pgid, int) or not members:
        return False
    return all(member.get('pgrp') == pgid for member in members)


def case_normal(window, ctx):
    case = ctx['case_root'] / 'normal'
    case.mkdir()
    probe = write_probe(case, 'normal.py', NORMAL_SOURCE)
    record, stdout, stderr = window.run([sys.executable, str(probe)], case, 'normal', 10)
    return {
        'proves': 'A plain child in a private group exits and cleans up empty.',
        'observed': {'exitCode': record['exitCode'],
                     'stdoutText': stdout.decode('utf-8', 'replace').strip()},
        'ok': record['exitCode'] == 0 and stdout == b'control-normal\n' and not stderr,
    }


def case_descendant(window, ctx):
    case = ctx['case_root'] / 'descendant'
    case.mkdir()
    write_probe(case, 'child.py', CHILD_SOURCE)
    probe = write_probe(case, 'root.py', ROOT_SOURCE)
    record, stdout, _stderr = window.run(
        [sys.executable, str(probe), 'exit', 'once'], case, 'descendant', 10)
    before = record.get('beforeCleanup') or []
    remaining = record.get('remainingAfterReap')
    observed = {
        'beforeCleanupCount': len(before),
        'beforeCleanupStates': [member.get('state') for member in before],
        'remainingAfterReapCount': None if remaining is None else len(remaining),
        'sameGroupProven': same_group_proven(record),
    }
    ok = (len(before) > 1 and observed['sameGroupProven'] and
          record.get('cleanupVerified') is True and remaining == [])
    return {
        'proves': 'Root leaves a same-group descendant; the group is really empty before release.',
        'observed': observed,
        'ok': ok,
    }


def case_ignore_term(window, ctx):
    case = ctx['case_root'] / 'ignore-term'
    case.mkdir()
    write_probe(case, 'child.py', CHILD_SOURCE)
    probe = write_probe(case, 'root.py', ROOT_SOURCE)
    failure = None
    before = len(window.steps)
    try:
        window.run([sys.executable, str(probe), 'wait', 'ignore-term'],
                   case, 'ignore-term', 2)
    except RuntimeError as error:
        failure = str(error)
    steps = step_slice(window, before)
    record = steps[-1] if steps else {}
    before_members = record.get('beforeCleanup') or []
    observed = {
        'failure': failure,
        'beforeCleanupCount': len(before_members),
        'elapsedSeconds': record.get('elapsedSeconds'),
        'cleanupVerified': record.get('cleanupVerified'),
    }
    ok = (failure is not None and 'Per-step deadline exceeded' in failure and
          len(before_members) > 1 and record.get('cleanupVerified') is True)
    return {
        'proves': 'A step deadline escalates SIGTERM to SIGKILL and still ends empty.',
        'observed': observed,
        'ok': ok,
    }


def case_signal_latch(window, ctx):
    case = ctx['case_root'] / 'signal-latch'
    case.mkdir()
    write_probe(case, 'child.py', CHILD_SOURCE)
    probe = write_probe(case, 'root.py', ROOT_SOURCE)
    latched = ctx['latched']
    latched.clear()
    del ctx['runner'].CANCEL_SIGNALS[:]
    stop_at = time.monotonic() + 1.7

    def burst():
        # Let the initial Window.check() and the spawn finish first, so this
        # case always owns a real step to prove cleanup against.
        time.sleep(0.2)
        while time.monotonic() < stop_at:
            for sig in (signal.SIGTERM, signal.SIGINT):
                try:
                    os.kill(os.getpid(), sig)
                except ProcessLookupError:
                    return
            time.sleep(0.04)

    thread = threading.Thread(target=burst, name='control-signal-burst', daemon=True)
    failure = None
    before = len(window.steps)
    thread.start()
    try:
        window.run([sys.executable, str(probe), 'exit', 'ignore-term'],
                   case, 'signal-latch', 10)
    except RuntimeError as error:
        failure = str(error)
    finally:
        thread.join(timeout=2.0)
        if thread.is_alive():
            thread.join(timeout=3.0)
    burst_stopped = not thread.is_alive()
    steps = step_slice(window, before)
    record = steps[-1] if steps else {}
    signals_seen = sorted(set(latched))
    if burst_stopped:
        # The case injected these signals on purpose. Clear the shared latch so
        # the later heartbeat control is not masked by a deliberate cancellation.
        # A still-running burst is never cleared: that would hide a real cancel.
        del ctx['runner'].CANCEL_SIGNALS[:]
    observed = {
        'failure': failure,
        'latchedSignals': signals_seen,
        'latchedCount': len(latched),
        'burstStopped': burst_stopped,
        'cleanupVerified': record.get('cleanupVerified'),
        'beforeCleanupCount': len(record.get('beforeCleanup') or []),
    }
    ok = (burst_stopped and len(signals_seen) >= 2 and
          record.get('cleanupVerified') is True and
          'signal' not in (failure or '').lower())
    return {
        'proves': 'Repeated SIGTERM/SIGINT only latch; cleanup never raises from a handler.',
        'observed': observed,
        'ok': ok,
    }


def case_heartbeat(window, ctx):
    """Prove a stalled lease cancels a live same-group child, then cleans up."""
    case = ctx['case_root'] / 'heartbeat-loss'
    case.mkdir()
    write_probe(case, 'child.py', CHILD_SOURCE)
    probe = write_probe(case, 'root.py', ROOT_SOURCE)

    # Stop the parent heartbeat first, then start a real sleeping root plus a
    # TERM-ignoring child in the same private group. The run's own poll loop
    # must observe the stall and cancel the live group, not just report it.
    request = ctx['work'] / STOP_REQUEST_NAME
    write_json(request, {
        'schemaVersion': SCHEMA_VERSION,
        'runId': ctx['launch']['runId'],
        'nonce': ctx['launch']['nonce'],
        'reason': 'control: stalled lease must cancel a live same-group child',
        'requestedAt': time.time(),
    })
    before = len(window.steps)
    failure = None
    began = time.monotonic()
    try:
        window.run([sys.executable, str(probe), 'wait', 'ignore-term'],
                   case, 'heartbeat-loss', 12)
    except RuntimeError as error:
        failure = str(error)
    wall = round(time.monotonic() - began, 3)
    steps = step_slice(window, before)
    record = steps[-1] if steps else {}
    before_members = record.get('beforeCleanup') or []
    remaining = record.get('remainingAfterReap')
    observed = {
        'failure': failure,
        'wallSeconds': wall,
        'elapsedSeconds': record.get('elapsedSeconds'),
        'beforeCleanupCount': len(before_members),
        'beforeCleanupStates': [member.get('state') for member in before_members],
        'remainingAfterReapCount': None if remaining is None else len(remaining),
        'cleanupVerified': record.get('cleanupVerified'),
        'sameGroupProven': same_group_proven(record),
    }
    ok = (failure is not None
          and 'Owner heartbeat stopped changing' in failure
          and len(before_members) > 1
          and observed['sameGroupProven']
          and record.get('cleanupVerified') is True
          and remaining == [])
    return {
        'proves': 'A stalled lease cancels a live same-group child and still ends empty.',
        'observed': observed,
        'ok': ok,
    }


CASES = (
    ('normal', case_normal),
    ('descendant-survives-root', case_descendant),
    ('ignore-term-timeout', case_ignore_term),
    ('signal-latch-in-cleanup', case_signal_latch),
    ('heartbeat-loss', case_heartbeat),
)


def run_case(window, ctx, name, function, order):
    before = len(window.steps)
    entry = {'order': order, 'name': name, 'ok': False, 'cleanupProof': 'unprovable'}
    ctx['cases'].append(entry)
    try:
        entry.update(function(window, ctx))
    except Exception as error:
        entry['errorType'] = type(error).__name__
        entry['error'] = str(error)
    finally:
        steps = step_slice(window, before)
        entry['stepIds'] = [step.get('stepId') for step in steps]
        entry['stepsObserved'] = len(steps)
        entry['cleanupProof'] = proof_of(steps)
    return entry


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work', type=Path, required=True,
                        help='Prepared window directory holding linux_runner.py and lease')
    parser.add_argument('--budget', type=int, default=25,
                        help='Window budget in seconds (10..600, default 25)')
    args = parser.parse_args(argv)
    if not 10 <= args.budget <= 600:
        raise SystemExit('--budget must be 10..600')

    work = args.work.resolve()
    if not work.is_dir():
        raise SystemExit(f'--work is not a directory: {work}')
    result_path = work / RESULT_NAME
    result = {
        'schemaVersion': SCHEMA_VERSION,
        'runId': None,
        'nonce': None,
        'hostOnly': True,
        'installedDeviceEvidence': False,
        'cleanupVerified': False,
        'complete': False,
        'budgetSeconds': args.budget,
        'supervisor': None,
        'runnerModule': None,
        'processContainment': 'private POSIX groups created by Window.run; controls use no setsid escape',
        'cleanupProofPolicy': 'empty releases; live and unprovable keep the hold; EPERM is never swallowed',
        'latchedSignals': [],
        'cases': [],
        'steps': [],
        'ledger': None,
        'unrun': 'Live control window not executed by this candidate author.',
    }
    latched = []
    runner = None
    window = None
    try:
        runner, runner_path = load_runner(work)
        result['runnerModule'] = {
            'path': str(runner_path),
            'sha256': sha(runner_path),
            'schema': runner.SCHEMA,
        }
        launch = read_launch(work)
        result['runId'] = launch['runId']
        result['nonce'] = launch['nonce']

        # Handlers only latch. They never raise, so cleanup and report IO survive
        # repeated SIGTERM/SIGINT. Window.check() observes the same latch.
        def on_signal(signum, frame):
            latched.append(int(signum))
            runner.CANCEL_SIGNALS.append(int(signum))

        signal.signal(signal.SIGTERM, on_signal)
        signal.signal(signal.SIGINT, on_signal)

        window = runner.Window(work, args.budget)
        result['supervisor'] = runner.identity(os.getpid())

        case_root = work / 'control'
        case_root.mkdir()
        ctx = {'work': work, 'case_root': case_root, 'launch': launch,
               'runner': runner, 'cases': result['cases'], 'latched': latched}

        for order, (name, function) in enumerate(CASES, 1):
            run_case(window, ctx, name, function, order)

    except Exception as error:
        result['failure'] = f'{type(error).__name__}: {error}'
    finally:
        steps = list(window.steps) if window is not None else []
        cases = result['cases']
        result['steps'] = steps
        result['stepsObserved'] = len(steps)
        result['latchedSignals'] = sorted(set(latched))
        result['cleanupVerified'] = (
            bool(steps)
            and all(bool(step.get('cleanupVerified')) for step in steps)
            and all(case.get('cleanupProof') == 'empty' for case in cases))
        result['complete'] = (
            len(cases) == len(CASES)
            and all(case.get('ok') for case in cases)
            and result['cleanupVerified'])
        if not result['cleanupVerified']:
            result['holdReason'] = 'cleanup proof is live or unprovable; slot must stay held'
        ledger_path = work / LEDGER_NAME
        if result['complete'] and ledger_path.is_file():
            result['ledger'] = {'path': LEDGER_NAME, 'sha256': sha(ledger_path)}
        write_json(result_path, result)
    return 0 if result['complete'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
