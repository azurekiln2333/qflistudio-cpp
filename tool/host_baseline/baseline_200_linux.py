#!/usr/bin/env python3
"""Ignored schema-2 host verification candidate. Live containment remains UNRUN."""
import argparse
import base64
import errno
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import time

SCHEMA = 2
COMPARISON = 'strict UTF-8; CRLF->LF; strip all final LF; zero exit; empty stderr'
CANCEL_SIGNALS = []


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def write_json(path, value):
    pending = path.with_suffix('.pending')
    with pending.open('w', encoding='utf-8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())
    pending.replace(path)


def identity(pid):
    try:
        raw = Path(f'/proc/{pid}/stat').read_text(encoding='utf-8', errors='surrogateescape')
    except OSError as error:
        if error.errno in (errno.ENOENT, errno.ESRCH):
            return None
        raise RuntimeError(f'Process identity unreadable: {pid}: {error}') from error
    fields = raw[raw.rfind(')') + 2:].split()
    if len(fields) < 20:
        raise RuntimeError(f'Malformed process identity: {pid}')
    return {'pid': int(pid), 'state': fields[0], 'pgrp': int(fields[2]),
            'session': int(fields[3]), 'startTicks': int(fields[19])}


def group_members(pgid):
    members = []
    # Enumeration/read permission failures propagate as unknown, never as empty.
    for item in Path('/proc').iterdir():
        if item.name.isdigit():
            current = identity(item.name)
            if current is not None and current['pgrp'] == pgid:
                members.append(current)
    return members


def signal_group(pgid, sig):
    try:
        os.killpg(pgid, sig)
    except ProcessLookupError:
        if group_members(pgid):
            raise RuntimeError('killpg ESRCH contradicted by group enumeration')
    # EPERM is deliberately not swallowed. Caller retains an unverified cleanup.


def normalized(raw):
    return raw.decode('utf-8', errors='strict').replace('\r\n', '\n').rstrip('\n')


def compare_output(stdout, stderr, exit_code, expected):
    expected_bytes = expected.encode('utf-8')
    result = {'comparisonPolicy': COMPARISON, 'byteExactStdout': stdout == expected_bytes}
    try:
        result['normalizedStdoutMatches'] = normalized(stdout) == normalized(expected_bytes)
    except UnicodeDecodeError:
        result['normalizedStdoutMatches'] = False
        result['outputEncodingError'] = True
    result['ok'] = exit_code == 0 and not stderr and result['normalizedStdoutMatches']
    return result


def validate_pairs(entries, tutorials):
    if len(entries) != 200 or len(tutorials) != 200:
        raise ValueError('Exactly 200 original examples and tutorials required')
    expected = {f'{lang}-example-{i:03d}' for lang in ('c', 'cpp') for i in range(1, 101)}
    tutorial_ids = {value.replace('-example-', '-tutorial-') for value in expected}
    if {x['id'] for x in entries} != expected or {x['id'] for x in tutorials} != tutorial_ids:
        raise ValueError('Original IDs must be C/C++ 001..100, each exactly once')
    lessons = {}
    for tutorial in tutorials:
        language = tutorial['id'].split('-')[0]
        if tutorial['language'] != language or len(tutorial['lessons']) != 1:
            raise ValueError('Tutorial language or lesson shape mismatch')
        lessons[tutorial['id']] = tutorial['lessons'][0]
    for entry in entries:
        language = entry['id'].split('-')[0]
        if any(entry.get(k) != language for k in ('language', 'type', 'templateType')):
            raise ValueError('Example language metadata mismatch')
        lesson = lessons[entry['id'].replace('-example-', '-tutorial-')]
        pairs = [('code', 'code'), ('expectedOutput', 'output'), ('portableExpectedOutput', 'portableOutput')]
        if (any(entry.get(a) != lesson.get(b) for a, b in pairs) or
                entry.get('sourceLessonId') != lesson['id'] or
                entry.get('inputFixtures', {}) != lesson.get('inputFixtures', {})):
            raise ValueError('Tutorial/example source, output or stdin mismatch')
        if not isinstance(entry['code'], str) or not isinstance(entry['expectedOutput'], str):
            raise ValueError('Source and expected output must be text')
        if len(entry.get('inputFixtures', {}).get('stdin', '').encode()) > 4096:
            raise ValueError('Fixture stdin exceeds 4096-byte bound')


class Window:
    def __init__(self, work, seconds):
        self.work = work
        self.deadline = time.monotonic() + seconds
        self.lease_token = None
        self.lease_observed = time.monotonic()
        self.steps = []
        self.cancel_signals = CANCEL_SIGNALS

    def check(self):
        now = time.monotonic()
        if self.cancel_signals or (self.work / 'cancel').exists():
            raise RuntimeError('Supervisor cancellation requested')
        if now >= self.deadline:
            raise RuntimeError('Overall phase deadline exceeded')
        try:
            stat = (self.work / 'lease').stat()
        except OSError as error:
            raise RuntimeError('Owner heartbeat unavailable') from error
        token = (stat.st_mtime_ns, stat.st_size)
        if token != self.lease_token:
            self.lease_token, self.lease_observed = token, now
        if now - self.lease_observed > 5:
            raise RuntimeError('Owner heartbeat stopped changing')

    def cleanup(self, child, record):
        record['beforeCleanup'] = group_members(child.pid)
        for sig, grace in ((signal.SIGTERM, 0.3), (signal.SIGKILL, 2.0)):
            if any(p['state'] != 'Z' for p in group_members(child.pid)):
                signal_group(child.pid, sig)
            deadline = time.monotonic() + grace
            while time.monotonic() < deadline:
                if not any(p['state'] != 'Z' for p in group_members(child.pid)):
                    break
                time.sleep(0.05)
        remaining = group_members(child.pid)
        record['remainingBeforeReap'] = remaining
        leader = record['leader']
        if any(p['state'] != 'Z' for p in remaining):
            raise RuntimeError('Owned group still has live members; hold slot')
        if any(p['pid'] == child.pid and p['startTicks'] != leader['startTicks'] for p in remaining):
            raise RuntimeError('Unreaped leader identity changed; hold slot')
        record['exitCode'] = child.wait(timeout=1)
        # Do not signal by PGID after reaping: its number may be reused.
        deadline = time.monotonic() + 0.5
        while True:
            remaining = group_members(child.pid)
            record['remainingAfterReap'] = remaining
            if not remaining or time.monotonic() >= deadline:
                break
            time.sleep(0.05)
        record['cleanupVerified'] = not remaining
        if not record['cleanupVerified']:
            raise RuntimeError('Group emptiness unproven; hold slot')

    def run(self, command, cwd, stem, seconds, stdin=b''):
        self.check()
        began = time.monotonic()
        out_path, err_path = cwd / f'{stem}.stdout', cwd / f'{stem}.stderr'
        in_path = cwd / f'{stem}.stdin'
        in_path.write_bytes(stdin)
        record = {'stepId': f'{len(self.steps):04d}', 'command': list(map(str, command)),
                  'cwdRelative': str(cwd.relative_to(self.work)), 'stem': stem,
                  'timeoutSeconds': seconds, 'cleanupVerified': False,
                  'stdinSha256': sha(in_path)}
        self.steps.append(record)
        failure = None
        child = None
        try:
            with in_path.open('rb') as source, out_path.open('wb') as out, err_path.open('wb') as err:
                child = subprocess.Popen(command, cwd=cwd, stdin=source, stdout=out,
                                         stderr=err, start_new_session=True)
                record['leader'] = identity(child.pid)
                leader = record['leader']
                if not leader or leader['pid'] != leader['pgrp'] or leader['pid'] != leader['session']:
                    raise RuntimeError('Private child session identity unavailable')
                try:
                    while True:
                        state = os.waitid(os.P_PID, child.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
                        if state is not None:
                            break
                        self.check()
                        if time.monotonic() - began >= seconds:
                            raise RuntimeError('Per-step deadline exceeded')
                        time.sleep(0.05)
                except BaseException as error:
                    failure = str(error)
                finally:
                    try:
                        self.cleanup(child, record)
                    except BaseException as error:
                        record['cleanupFailure'] = str(error)
                        failure = failure or str(error)
        except BaseException as error:
            failure = failure or str(error)
            # A failure between spawn and the inner try still needs owned cleanup.
            if child is not None and 'remainingBeforeReap' not in record:
                try:
                    if record.get('leader'):
                        self.cleanup(child, record)
                    else:
                        # Child is still unreaped; it owns the new session. Kill is
                        # attempted but identity loss never permits a release claim.
                        signal_group(child.pid, signal.SIGKILL)
                        child.wait(timeout=1)
                except BaseException as cleanup_error:
                    record['cleanupFailure'] = str(cleanup_error)
                record['cleanupVerified'] = False
        finally:
            record['elapsedSeconds'] = round(time.monotonic() - began, 3)
            for label, path in [('stdout', out_path), ('stderr', err_path)]:
                if path.exists():
                    record[label + 'Sha256'] = sha(path)
                    record[label + 'B64'] = base64.b64encode(path.read_bytes()).decode('ascii')
            if failure:
                record['failure'] = failure
            write_json(cwd / f'{stem}.json', record)
            # Incremental ledger binds every attempted spawn, even on failure.
            write_json(self.work / 'steps.json', self.steps)
        if failure or not record['cleanupVerified']:
            raise RuntimeError(failure or 'Cleanup not verified')
        return record, out_path.read_bytes(), err_path.read_bytes()


def stdin_gate(window, manifest, tools):
    case = window.work / 'stdin-control'
    case.mkdir()
    source = case / 'main.c'
    source.write_text('#include <stdio.h>\nint main(void){char b[128];if(!fgets(b,sizeof b,stdin))return 9;fputs(b,stdout);return 0;}\n', encoding='utf-8')
    output = case / 'output'
    output.mkdir()
    compiled, _, _ = window.run([tools[0], '--threads', manifest['sdk'], str(case), str(output)], case, 'compile', 60)
    if compiled['exitCode'] != 0:
        raise RuntimeError('WASI stdin-control compile failed')
    for index, marker in enumerate((b'baseline-stdin-alpha\n', b'baseline-stdin-beta\n')):
        step, stdout, stderr = window.run([tools[1], str(output / 'program.wasm'), str(case)],
                                          case, f'input-{index}', 30, marker)
        if stdout != marker or stderr or step['exitCode'] != 0:
            raise RuntimeError('Actual WASI runtime failed finite-stdin transport control')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work', type=Path, required=True)
    args = parser.parse_args()
    # Handlers only latch state. Repeated signals cannot interrupt cleanup/report IO.
    def cancelled(signum, frame):
        CANCEL_SIGNALS.append(signum)
    signal.signal(signal.SIGTERM, cancelled)
    signal.signal(signal.SIGINT, cancelled)
    work = args.work.resolve()
    manifest = json.loads((work / 'manifest.json').read_text(encoding='utf-8'))
    launch = json.loads((work / 'launch.json').read_text(encoding='utf-8'))
    if manifest.get('schema') != SCHEMA or manifest.get('phase') not in ('native', 'wasi'):
        raise ValueError('Schema-2 manifest with explicit host phase required')
    if launch['runId'] != manifest['runId'] or launch['manifestSha256'] != sha(work / 'manifest.json'):
        raise ValueError('Launch identity mismatch')
    window = Window(work, manifest['phaseBudgetSeconds'])
    supervisor = identity(os.getpid())
    write_json(work / 'linux-start.json', {'schema': SCHEMA, 'runId': manifest['runId'],
               'nonce': launch['nonce'], 'supervisor': supervisor})
    report = {'schema': SCHEMA, 'runId': manifest['runId'], 'nonce': launch['nonce'],
              'phase': manifest['phase'], 'hostOnly': True, 'installedDeviceEvidence': False,
              'packagedOhosEvidence': False, 'linuxSupervisor': supervisor,
              'comparisonPolicy': COMPARISON, 'results': [], 'complete': False,
              'processContainment': 'private POSIX groups; same-user forgery/session escape not contained',
              'stdinTransportVerified': False, 'binarySourceCorrespondence': 'UNPROVEN'}
    try:
        for item in manifest['inputs']:
            window.check()
            if sha(item['linuxPath']) != item['sha256']:
                raise RuntimeError(f"Input changed: {item['linuxPath']}")
        entries = json.loads((work / 'examples.json').read_text(encoding='utf-8'))['entries']
        tutorials = json.loads((work / 'tutorials.json').read_text(encoding='utf-8'))['entries']
        validate_pairs(entries, tutorials)
        phase = manifest['phase']
        tools = ([shutil.which('gcc'), shutil.which('clang++')] if phase == 'native'
                 else [manifest['compiler'], manifest['runtime']])
        if not all(tools):
            raise RuntimeError('Required actual compiler unavailable')
        report['tools'] = [{'path': str(Path(p).resolve()), 'sha256': sha(Path(p).resolve())} for p in tools]
        if phase == 'native':
            for index, tool in enumerate(tools):
                window.run([tool, '--version'], work, f'tool-{index}', 10)
        else:
            sdk = Path(manifest['sdk'])
            inventory = []
            for path in sorted(sdk.rglob('*')):
                window.check()
                if path.is_file():
                    inventory.append({'path': str(path.relative_to(sdk)), 'sha256': sha(path)})
            write_json(work / 'sdk-inventory.json', inventory)
            report['sdkInventorySha256'] = sha(work / 'sdk-inventory.json')
            stdin_gate(window, manifest, tools)
            report['stdinTransportVerified'] = True
            report['threadsEnabled'] = True
            report['execution'] = 'wasmedge-interpreter'
        for entry in entries:
            window.check()
            case = work / entry['id']
            case.mkdir()
            source = case / ('main.c' if entry['language'] == 'c' else 'main.cpp')
            source.write_bytes(entry['code'].encode())
            stdin = entry.get('inputFixtures', {}).get('stdin', '').encode()
            expected = entry['expectedOutput']
            if phase == 'wasi' and 'portableExpectedOutput' in entry:
                expected = entry['portableExpectedOutput']
            standard = 'c17' if entry['language'] == 'c' else 'c++20'
            item = {'id': entry['id'], 'standardRequested': standard,
                    'standardEvidence': 'explicit driver flag' if phase == 'native' else 'bound compiler source default; binary correspondence UNPROVEN',
                    'sourceSha256': sha(source), 'stdinSha256': hashlib.sha256(stdin).hexdigest(),
                    'expectedOutputSha256': hashlib.sha256(expected.encode()).hexdigest(), 'ok': False}
            report['results'].append(item)
            if phase == 'native':
                command = [tools[0] if entry['language'] == 'c' else tools[1], '-std=' + standard,
                           str(source), '-pthread', '-lm', '-o', str(case / 'program')]
                run_command = [str(case / 'program')]
            else:
                output = case / 'output'
                output.mkdir()
                command = [tools[0], '--threads', manifest['sdk'], str(case), str(output)]
                run_command = [tools[1], str(output / 'program.wasm'), str(case)]
            compiled, _, _ = window.run(command, case, 'compile', 60)
            item['compileStepId'] = compiled['stepId']
            if compiled['exitCode'] == 0:
                executed, stdout, stderr = window.run(run_command, case, 'execute', 30, stdin)
                item['executeStepId'] = executed['stepId']
                item.update(compare_output(stdout, stderr, executed['exitCode'], expected))
            print(f"{entry['id']}: {'PASS' if item['ok'] else 'FAIL'}", flush=True)
            write_json(work / 'report.json', report)
        for item in manifest['inputs']:
            window.check()
            if sha(item['linuxPath']) != item['sha256']:
                raise RuntimeError('Input changed during verification')
        for tool in report['tools']:
            if sha(tool['path']) != tool['sha256']:
                raise RuntimeError('Host tool changed during verification')
        if phase == 'wasi':
            current_paths = sorted(p for p in sdk.rglob('*') if p.is_file())
            if [str(p.relative_to(sdk)) for p in current_paths] != [x['path'] for x in inventory]:
                raise RuntimeError('SDK inventory changed during verification')
            for path, item in zip(current_paths, inventory):
                window.check()
                if sha(path) != item['sha256']:
                    raise RuntimeError('SDK bytes changed during verification')
        window.check()
        report['complete'] = True
    except BaseException as error:
        report['failure'] = str(error)
    finally:
        report['steps'] = window.steps
        report['stepsObserved'] = len(window.steps)
        report['passed'] = sum(x['ok'] for x in report['results'])
        report['totalExecuted'] = len(report['results'])
        report['cancelSignals'] = list(CANCEL_SIGNALS)
        report['cleanupVerified'] = bool(window.steps) and all(x['cleanupVerified'] for x in window.steps)
        write_json(work / 'steps.json', window.steps)
        write_json(work / 'report.json', report)
        write_json(work / 'linux-completion.json', {'schema': SCHEMA, 'runId': manifest['runId'],
                   'nonce': launch['nonce'], 'supervisor': supervisor, 'phase': manifest['phase'],
                   'hostOnly': True, 'installedDeviceEvidence': False, 'packagedOhosEvidence': False,
                   'cleanupVerified': report['cleanupVerified'], 'stepsObserved': len(window.steps),
                   'stepsSha256': sha(work / 'steps.json'), 'reportSha256': sha(work / 'report.json'),
                   'complete': report['complete']})
    return 0 if report['complete'] and report['passed'] == 200 and report['cleanupVerified'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
