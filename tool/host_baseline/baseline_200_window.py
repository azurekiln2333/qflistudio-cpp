#!/usr/bin/env python3
"""Ignored schema-2 candidate. Prepare only, or execute one granted host window."""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import secrets
import shutil
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
OWNER = ROOT / 'build/baseline_200_owned_job.py'
SCHEMA = 2


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def linux(path):
    value = Path(path).resolve().as_posix()
    if len(value) < 3 or value[1:3] != ':/':
        raise ValueError('Only local Windows drive paths supported')
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
    return json.loads(path.read_text(encoding='utf-8-sig'))


def valid_identity(value):
    return (isinstance(value, dict) and all(type(value.get(k)) is int and value[k] > 0
            for k in ('pid', 'pgrp', 'session', 'startTicks')))


def verified_evidence(work, manifest, launch):
    """Cross-check local non-adversarial evidence. Not an OS anti-forgery boundary."""
    completion = read_json(work / 'linux-completion.json')
    start = read_json(work / 'linux-start.json')
    report = read_json(work / 'report.json')
    steps = read_json(work / 'steps.json')
    if launch.get('manifestSha256') != sha(work / 'manifest.json'):
        return False
    for record in (start, completion, report):
        if (record.get('schema') != SCHEMA or record.get('runId') != manifest['runId'] or
                record.get('nonce') != launch['nonce']):
            return False
    supervisor = start.get('supervisor')
    if (not valid_identity(supervisor) or completion.get('supervisor') != supervisor or
            report.get('linuxSupervisor') != supervisor):
        return False
    for record in (completion, report):
        if (record.get('phase') != manifest['phase'] or record.get('hostOnly') is not True or
                record.get('installedDeviceEvidence') is not False or record.get('packagedOhosEvidence') is not False or
                record.get('cleanupVerified') is not True or record.get('stepsObserved') != len(steps)):
            return False
    if (not steps or completion.get('reportSha256') != sha(work / 'report.json') or
            completion.get('stepsSha256') != sha(work / 'steps.json') or report.get('steps') != steps):
        return False
    leaders = set()
    for index, step in enumerate(steps):
        leader = step.get('leader')
        if (step.get('stepId') != f'{index:04d}' or step.get('cleanupVerified') is not True or
                not valid_identity(leader) or leader['pid'] != leader['pgrp'] or
                leader['pid'] != leader['session'] or leader['pid'] == supervisor['pid']):
            return False
        stamp = (leader['pid'], leader['startTicks'])
        if stamp in leaders:
            return False
        leaders.add(stamp)
        before = step.get('beforeCleanup')
        remaining = step.get('remainingBeforeReap')
        if (not isinstance(before, list) or not any(p.get('pid') == leader['pid'] and
                p.get('startTicks') == leader['startTicks'] for p in before) or
                not isinstance(remaining, list) or step.get('remainingAfterReap') != [] or
                any(not valid_identity(p) or p['pgrp'] != leader['pid'] for p in before) or
                any(not valid_identity(p) or p['pgrp'] != leader['pid'] or p.get('state') != 'Z' for p in remaining) or
                type(step.get('exitCode')) is not int or not step.get('command')):
            return False
        relative, stem = step.get('cwdRelative'), step.get('stem')
        if not isinstance(relative, str) or not isinstance(stem, str) or Path(stem).name != stem:
            return False
        cwd = (work / relative).resolve()
        if not cwd.is_relative_to(work.resolve()):
            return False
        if read_json(cwd / f'{stem}.json') != step:
            return False
        for label in ('stdin', 'stdout', 'stderr'):
            path = cwd / f'{stem}.{label}'
            if sha(path) != step.get(label + 'Sha256'):
                return False
            if label != 'stdin' and base64.b64decode(step.get(label + 'B64', ''), validate=True) != path.read_bytes():
                return False
    # No claim of cryptographic authentication against arbitrary same-user code:
    # host snippets and the supervisor share user permissions. Stale and malformed
    # completion files fail nonce/hash/identity/ledger checks.
    return True



def successful_report(work, manifest, report):
    if report.get('complete') is not True or report.get('passed') != 200:
        return False
    entries = {x['id']: x for x in read_json(work / 'examples.json')['entries']}
    ids = {f'{lang}-example-{i:03d}' for lang in ('c', 'cpp') for i in range(1, 101)}
    results = report.get('results', [])
    if len(entries) != 200 or set(entries) != ids or len(results) != 200 or {x.get('id') for x in results} != ids:
        return False
    steps = {x['stepId']: x for x in report['steps']}
    for item in results:
        entry = entries[item['id']]
        expected = entry['expectedOutput']
        if manifest['phase'] == 'wasi' and 'portableExpectedOutput' in entry:
            expected = entry['portableExpectedOutput']
        if (item.get('ok') is not True or
                item.get('sourceSha256') != hashlib.sha256(entry['code'].encode()).hexdigest() or
                item.get('stdinSha256') != hashlib.sha256(entry.get('inputFixtures', {}).get('stdin', '').encode()).hexdigest() or
                item.get('expectedOutputSha256') != hashlib.sha256(expected.encode()).hexdigest()):
            return False
        compiled = steps.get(item.get('compileStepId'), {})
        executed = steps.get(item.get('executeStepId'), {})
        if (compiled.get('cwdRelative') != item['id'] or compiled.get('stem') != 'compile' or
                executed.get('cwdRelative') != item['id'] or executed.get('stem') != 'execute' or
                compiled.get('exitCode') != 0 or executed.get('exitCode') != 0 or
                compiled.get('cleanupVerified') is not True or executed.get('cleanupVerified') is not True):
            return False
        try:
            stdout = base64.b64decode(executed['stdoutB64'], validate=True).decode('utf-8', errors='strict')
            stderr = base64.b64decode(executed['stderrB64'], validate=True)
        except (ValueError, UnicodeDecodeError, KeyError):
            return False
        if stderr or stdout.replace('\r\n', '\n').rstrip('\n') != expected.replace('\r\n', '\n').rstrip('\n'):
            return False
    return manifest['phase'] != 'wasi' or report.get('stdinTransportVerified') is True


def finalize_job(job, work, record, proof, writer=write_json, grace=3):
    """Always attempt durable records and close, including empty/stop/write failures."""
    record['slotReleased'] = False
    errors = record.setdefault('cleanupErrors', [])
    empty = False
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
        record['windowsJob'] = dict(job.record)
        job_proven = (empty and record['windowsJob'].get('assignedBeforeResume') is True and
                      record['windowsJob'].get('createdSuspended') is True and
                      record['windowsJob'].get('terminal') is True and
                      record['windowsJob'].get('jobActiveProcesses') == 0 and
                      type(record['windowsJob'].get('pid')) is int and
                      bool(record['windowsJob'].get('creationFiletime100ns')))
        if job_proven and not errors:
            try:
                record['evidenceVerified'] = proof()
            except BaseException as error:
                errors.append('evidence: ' + str(error))
        record['slotReleased'] = bool(job_proven and not errors and record.get('evidenceVerified') is True)
    except BaseException as error:
        errors.append('finalizer: ' + str(error))
        record['slotReleased'] = False
    finally:
        # A failed disk write cannot bypass CloseHandle.
        try:
            try:
                writer(work / 'windows-owner.json', record)
            except BaseException as error:
                errors.append('initial durable write: ' + str(error))
                record['slotReleased'] = False
        finally:
            try:
                job.close()
                record['handlesClosed'] = True
            except BaseException as error:
                errors.append('close: ' + str(error))
                record['handlesClosed'] = False
                record['slotReleased'] = False
        try:
            writer(work / 'windows-owner.json', record)
        except BaseException as error:
            errors.append('final durable write: ' + str(error))
            record['slotReleased'] = False
            # Separate best-effort fallback. Total storage failure cannot be
            # represented as durable success, but handle closure was attempted.
            try:
                write_json(work / 'windows-owner.recovery.json', record)
            except BaseException as recovery_error:
                record['durabilityFailure'] = str(recovery_error)
    return record


def prepare(phase, budget):
    if budget < 60 or budget > 1200:
        raise ValueError('Phase budget must be 60..1200 seconds')
    run_id = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8]
    work = ROOT / 'build' / ('baseline-200-v2-' + phase + '-' + run_id)
    work.mkdir()
    for source, name in [(ROOT / 'tool/forge_content/staging/forge_examples.json', 'examples.json'),
                         (ROOT / 'tool/forge_content/staging/forge_tutorials.json', 'tutorials.json'),
                         (ROOT / 'build/baseline_200_linux.py', 'linux_runner.py'), (OWNER, 'owned_job.py')]:
        shutil.copyfile(source, work / name)
    relative_inputs = ['tool/forge_content/staging/forge_examples.json', 'tool/forge_content/staging/forge_tutorials.json',
                       'native/compiler/compiler.cpp', 'native/compiler/include/qfli_compiler.h',
                       'native/portable/wasm_runtime.cpp', 'native/portable/include/qfli_wasm.h',
                       'native/portable/tests/runtime_probe.cpp',
                       'native/toolchain/portable-dependencies.json', 'native/toolchain/tests/portable-curriculum-regression.py',
                       'build/baseline_200_linux.py', 'build/baseline_200_window.py', 'build/baseline_200_owned_job.py']
    compiler = ROOT / 'native/build/compiler-linux/qfli_compiler_probe'
    runtime = ROOT / 'native/build/ohos-wasi-thread-probe/runtime-probe-reviewed'
    sdk = ROOT / 'native/build/portable-deps/wasi-sdk-33.0-x86_64-linux'
    inputs = [ROOT / p for p in relative_inputs] + list(work.iterdir())
    if phase == 'wasi':
        inputs += [compiler, runtime, sdk / 'VERSION']
    manifest = {'schema': SCHEMA, 'sourceOnlyCandidate': True, 'runId': run_id, 'phase': phase,
                'distro': 'qfli-java-build', 'phaseBudgetSeconds': budget, 'outerBudgetSeconds': budget + 20,
                'compiler': linux(compiler), 'runtime': linux(runtime), 'sdk': linux(sdk),
                'preparedAt': datetime.now(timezone.utc).isoformat(), 'executed': False,
                'inputs': [{'windowsPath': str(p.resolve()), 'linuxPath': linux(p), 'sha256': sha(p)} for p in inputs]}
    write_json(work / 'manifest.json', manifest)
    print(work)
    print('PREPARED ONLY. Real process creation and cancellation remain UNRUN.')
    return 0


def execute(work, grant):
    if os.name != 'nt' or not grant.strip():
        raise ValueError('Windows and concrete coordinator slot grant required')
    work = work.resolve()
    if work.parent != (ROOT / 'build').resolve() or not work.name.startswith('baseline-200-v2-'):
        raise ValueError('Only a fresh schema-2 prepared work directory is accepted')
    manifest = read_json(work / 'manifest.json')
    if manifest.get('schema') != SCHEMA or manifest.get('phase') not in ('native', 'wasi'):
        raise ValueError('Schema-2 manifest and explicit host phase required')
    evidence_names = ('launch.json', 'linux-start.json', 'linux-completion.json', 'windows-owner.json',
                      'steps.json', 'report.json', 'lease', 'cancel', 'wsl.stdout', 'wsl.stderr')
    if manifest['executed'] or any((work / p).exists() for p in evidence_names):
        raise ValueError('Prepared windows are single-use; preexisting execution evidence rejected')
    for item in manifest['inputs']:
        if sha(item['windowsPath']) != item['sha256']:
            raise ValueError('Prepared input changed: ' + item['windowsPath'])
    manifest['executed'] = True
    manifest['grant'] = grant
    write_json(work / 'manifest.json', manifest)
    launch = {'schema': SCHEMA, 'runId': manifest['runId'], 'nonce': secrets.token_hex(32),
              'manifestSha256': sha(work / 'manifest.json')}
    write_json(work / 'launch.json', launch)
    specification = importlib.util.spec_from_file_location('baseline_owned_job', work / 'owned_job.py')
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    job = None
    record = {'schema': SCHEMA, 'runId': manifest['runId'], 'grant': grant, 'slotReleased': False}
    command = ['wsl.exe', '-d', manifest['distro'], '--', 'python3', linux(work / 'linux_runner.py'), '--work', linux(work)]
    lease, cancel = work / 'lease', work / 'cancel'
    began = time.monotonic()
    cancellation_at = None
    try:
        job = module.OwnedJob()
        lease.write_text('0', encoding='ascii')
        sequence = 0
        with (work / 'wsl.stdout').open('wb') as out, (work / 'wsl.stderr').open('wb') as err:
            job.start(command, ROOT, dict(os.environ), out, err)
            while not job.empty():
                try:
                    sequence += 1
                    lease.write_text(str(sequence), encoding='ascii')
                    if time.monotonic() - began >= manifest['outerBudgetSeconds'] and cancellation_at is None:
                        cancel.write_text('outer deadline', encoding='ascii')
                        cancellation_at = time.monotonic()
                    if cancellation_at is not None and time.monotonic() - cancellation_at > 10:
                        break
                    time.sleep(0.2)
                except KeyboardInterrupt:
                    cancel.write_text('keyboard interrupt', encoding='ascii')
                    cancellation_at = cancellation_at or time.monotonic()
    except BaseException as error:
        record['failure'] = str(error)
        try:
            cancel.write_text('Windows owner failure', encoding='ascii')
        except BaseException as cancel_error:
            record['cancelFailure'] = str(cancel_error)
    finally:
        record['elapsedSeconds'] = round(time.monotonic() - began, 3)
        if job is not None:
            finalize_job(job, work, record, lambda: verified_evidence(work, manifest, launch))
        else:
            write_json(work / 'windows-owner.json', record)
    print(json.dumps(record, indent=2))
    if not record['slotReleased']:
        print('SLOT HELD: exact Job/step identity and cleanup evidence not proven.')
        return 2
    report = read_json(work / 'report.json')
    return 0 if successful_report(work, manifest, report) else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--prepare', choices=['native', 'wasi'])
    group.add_argument('--execute', type=Path)
    parser.add_argument('--budget', type=int, default=1200)
    parser.add_argument('--grant', default='')
    args = parser.parse_args()
    return prepare(args.prepare, args.budget) if args.prepare else execute(args.execute, args.grant)


if __name__ == '__main__':
    raise SystemExit(main())
