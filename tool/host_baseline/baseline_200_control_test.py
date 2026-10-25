#!/usr/bin/env python3
"""Pure Python fake/stub controls. Never creates a subprocess or loads native tools."""
import base64
import copy
import errno
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


W = load('window_candidate', 'baseline_200_window.py')
L = load('linux_candidate', 'baseline_200_linux.py')


class FakeJob:
    def __init__(self, failure=None):
        self.failure = failure
        self.closed = False
        self.stopped = False
        self.record = {'pid': 77, 'creationFiletime100ns': '123456', 'terminal': True,
                       'jobActiveProcesses': 0, 'assignedBeforeResume': True, 'createdSuspended': True}

    def empty(self):
        if self.failure in ('empty', 'both'):
            raise RuntimeError('fake empty failure')
        return self.failure != 'stop'

    def stop(self):
        self.stopped = True
        if self.failure in ('stop', 'both'):
            raise RuntimeError('fake stop failure')

    def close(self):
        self.closed = True
        if self.failure == 'close':
            raise RuntimeError('fake close failure')


class Controls(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='baseline-fake-', dir=ROOT)
        self.work = Path(self.temporary.name)
        self.addCleanup(self.temporary.cleanup)

    def final(self, failure=None, proof=lambda: True, writer=W.write_json):
        job, record = FakeJob(failure), {}
        W.finalize_job(job, self.work, record, proof, writer=writer, grace=0)
        self.assertTrue(job.closed)
        return job, record

    def test_finalizer_success_records_close(self):
        _, record = self.final()
        self.assertTrue(record['slotReleased'])
        self.assertTrue(W.read_json(self.work / 'windows-owner.json')['handlesClosed'])

    def test_empty_error_still_closes_and_records(self):
        _, record = self.final('empty')
        self.assertFalse(record['slotReleased'])
        self.assertIn('fake empty failure', json.dumps(W.read_json(self.work / 'windows-owner.json')))

    def test_stop_error_still_closes_and_records(self):
        job, record = self.final('stop')
        self.assertTrue(job.stopped)
        self.assertFalse(record['slotReleased'])

    def test_both_errors_recorded(self):
        _, record = self.final('both')
        self.assertTrue(any('fake stop failure' in x for x in record['cleanupErrors']))
        self.assertFalse(record['slotReleased'])

    def test_close_error_holds_slot_and_records(self):
        _, record = self.final('close')
        self.assertFalse(record['handlesClosed'])
        self.assertFalse(W.read_json(self.work / 'windows-owner.json')['slotReleased'])

    def test_first_write_error_cannot_bypass_close(self):
        calls = []
        def writer(path, value):
            calls.append(path)
            if len(calls) == 1:
                raise OSError('fake disk failure')
            W.write_json(path, value)
        _, record = self.final(writer=writer)
        self.assertEqual(len(calls), 2)
        self.assertFalse(record['slotReleased'])
        self.assertTrue((self.work / 'windows-owner.json').exists())

    def test_all_writer_errors_attempt_recovery_after_close(self):
        def writer(path, value):
            raise OSError('fake writer fails')
        _, record = self.final(writer=writer)
        self.assertFalse(record['slotReleased'])
        self.assertTrue((self.work / 'windows-owner.recovery.json').exists())

    def test_evidence_exception_cannot_bypass_close(self):
        def proof():
            raise ValueError('fake malformed proof')
        _, record = self.final(proof=proof)
        self.assertFalse(record['slotReleased'])
        self.assertIn('fake malformed proof', json.dumps(record))

    def fixture(self):
        supervisor = {'pid': 10, 'pgrp': 10, 'session': 10, 'startTicks': 100, 'state': 'R'}
        leader = {'pid': 11, 'pgrp': 11, 'session': 11, 'startTicks': 110, 'state': 'Z'}
        manifest = {'schema': 2, 'runId': 'fake-run', 'phase': 'native'}
        W.write_json(self.work / 'manifest.json', manifest)
        launch = {'nonce': 'fresh-nonce', 'manifestSha256': W.sha(self.work / 'manifest.json')}
        identity = {'schema': 2, 'runId': 'fake-run', 'nonce': 'fresh-nonce'}
        step = {'stepId': '0000', 'command': ['fake-tool'], 'cwdRelative': '.', 'stem': 'fake',
                'leader': leader, 'beforeCleanup': [leader], 'remainingBeforeReap': [leader],
                'remainingAfterReap': [], 'exitCode': 0, 'cleanupVerified': True}
        for label, value in [('stdin', b'input\n'), ('stdout', b'output\n'), ('stderr', b'')]:
            path = self.work / f'fake.{label}'
            path.write_bytes(value)
            step[label + 'Sha256'] = W.sha(path)
            if label != 'stdin':
                step[label + 'B64'] = base64.b64encode(value).decode()
        W.write_json(self.work / 'fake.json', step)
        W.write_json(self.work / 'steps.json', [step])
        flags = {'phase': 'native', 'hostOnly': True, 'installedDeviceEvidence': False,
                 'packagedOhosEvidence': False, 'cleanupVerified': True, 'stepsObserved': 1}
        report = {**identity, **flags, 'linuxSupervisor': supervisor, 'steps': [step]}
        W.write_json(self.work / 'report.json', report)
        W.write_json(self.work / 'linux-start.json', {**identity, 'supervisor': supervisor})
        completion = {**identity, **flags, 'supervisor': supervisor,
                      'reportSha256': W.sha(self.work / 'report.json'),
                      'stepsSha256': W.sha(self.work / 'steps.json')}
        W.write_json(self.work / 'linux-completion.json', completion)
        return manifest, launch

    def test_consistent_fake_transcript_is_accepted(self):
        manifest, launch = self.fixture()
        self.assertTrue(W.verified_evidence(self.work, manifest, launch))

    def test_stale_nonce_rejected(self):
        manifest, launch = self.fixture()
        launch['nonce'] = 'different-launch'
        self.assertFalse(W.verified_evidence(self.work, manifest, launch))

    def test_completion_boolean_alone_rejected(self):
        manifest, launch = self.fixture()
        W.write_json(self.work / 'linux-completion.json', {'runId': 'fake-run', 'cleanupVerified': True})
        self.assertFalse(W.verified_evidence(self.work, manifest, launch))

    def test_step_without_identity_rejected_even_if_hashes_updated(self):
        manifest, launch = self.fixture()
        steps = W.read_json(self.work / 'steps.json')
        del steps[0]['leader']
        W.write_json(self.work / 'steps.json', steps)
        report = W.read_json(self.work / 'report.json')
        report['steps'] = steps
        W.write_json(self.work / 'report.json', report)
        completion = W.read_json(self.work / 'linux-completion.json')
        completion.update(reportSha256=W.sha(self.work / 'report.json'), stepsSha256=W.sha(self.work / 'steps.json'))
        W.write_json(self.work / 'linux-completion.json', completion)
        self.assertFalse(W.verified_evidence(self.work, manifest, launch))

    def test_output_tamper_rejected(self):
        manifest, launch = self.fixture()
        (self.work / 'fake.stdout').write_bytes(b'changed')
        self.assertFalse(W.verified_evidence(self.work, manifest, launch))

    def test_report_hash_tamper_rejected(self):
        manifest, launch = self.fixture()
        with (self.work / 'report.json').open('a') as stream:
            stream.write(' ')
        self.assertFalse(W.verified_evidence(self.work, manifest, launch))

    def test_crlf_and_final_newline_tolerance_explicit(self):
        result = L.compare_output(b'a\r\n\n', b'', 0, 'a\n')
        self.assertTrue(result['ok'])
        self.assertFalse(result['byteExactStdout'])
        self.assertIn('strip all final LF', result['comparisonPolicy'])

    def test_spaces_are_not_trimmed(self):
        self.assertFalse(L.compare_output(b'a \n', b'', 0, 'a\n')['ok'])

    def test_stderr_and_exit_rejected(self):
        self.assertFalse(L.compare_output(b'a', b'warning', 0, 'a')['ok'])
        self.assertFalse(L.compare_output(b'a', b'', 1, 'a')['ok'])

    def test_invalid_utf8_rejected(self):
        self.assertFalse(L.compare_output(b'\xff', b'', 0, 'a')['ok'])

    def original_data(self):
        entries = W.read_json(W.ROOT / 'tool/forge_content/staging/forge_examples.json')['entries']
        tutorials = W.read_json(W.ROOT / 'tool/forge_content/staging/forge_tutorials.json')['entries']
        return entries, tutorials

    def test_current_200_pairs(self):
        L.validate_pairs(*self.original_data())

    def test_duplicate_original_rejected(self):
        entries, tutorials = self.original_data()
        entries[1] = copy.deepcopy(entries[0])
        with self.assertRaises(ValueError):
            L.validate_pairs(entries, tutorials)

    def test_out_of_range_id_rejected(self):
        entries, tutorials = self.original_data()
        entries[0]['id'] = 'c-example-101'
        with self.assertRaises(ValueError):
            L.validate_pairs(entries, tutorials)

    def test_wrong_language_rejected(self):
        entries, tutorials = self.original_data()
        entries[0]['language'] = 'cpp'
        with self.assertRaises(ValueError):
            L.validate_pairs(entries, tutorials)

    def test_stdin_mismatch_rejected(self):
        entries, tutorials = self.original_data()
        entries[0]['inputFixtures'] = {'stdin': 'unexpected'}
        with self.assertRaises(ValueError):
            L.validate_pairs(entries, tutorials)

    def test_identity_permission_is_unknown_not_empty(self):
        with patch.object(L.Path, 'read_text', side_effect=PermissionError(errno.EACCES, 'denied')):
            with self.assertRaises(RuntimeError):
                L.identity(42)

    def test_disappeared_identity_returns_none(self):
        with patch.object(L.Path, 'read_text', side_effect=FileNotFoundError(errno.ENOENT, 'gone')):
            self.assertIsNone(L.identity(42))

    def test_killpg_eperm_not_swallowed(self):
        with patch.object(L.os, 'killpg', side_effect=PermissionError(errno.EPERM, 'denied'), create=True):
            with self.assertRaises(PermissionError):
                L.signal_group(42, 15)

    def test_killpg_esrch_requires_empty_recheck(self):
        with patch.object(L.os, 'killpg', side_effect=ProcessLookupError(errno.ESRCH, 'gone'), create=True):
            with patch.object(L, 'group_members', return_value=[]):
                L.signal_group(42, 15)
            with patch.object(L, 'group_members', return_value=[{'pid': 42}]):
                with self.assertRaises(RuntimeError):
                    L.signal_group(42, 15)

    def synthetic_success(self):
        entries, _ = self.original_data()
        W.write_json(self.work / 'examples.json', {'entries': entries})
        report = {'complete': True, 'passed': 200, 'results': [], 'steps': []}
        for index, entry in enumerate(entries):
            compile_id, execute_id = f'c{index}', f'e{index}'
            report['steps'].extend([
                {'stepId': compile_id, 'cwdRelative': entry['id'], 'stem': 'compile', 'exitCode': 0, 'cleanupVerified': True},
                {'stepId': execute_id, 'cwdRelative': entry['id'], 'stem': 'execute', 'exitCode': 0, 'cleanupVerified': True,
                 'stdoutB64': base64.b64encode(entry['expectedOutput'].encode()).decode(), 'stderrB64': ''}])
            report['results'].append({'id': entry['id'], 'ok': True, 'compileStepId': compile_id, 'executeStepId': execute_id,
                'sourceSha256': W.hashlib.sha256(entry['code'].encode()).hexdigest(),
                'stdinSha256': W.hashlib.sha256(entry.get('inputFixtures', {}).get('stdin', '').encode()).hexdigest(),
                'expectedOutputSha256': W.hashlib.sha256(entry['expectedOutput'].encode()).hexdigest()})
        return report

    def test_full_synthetic_success_recomputed(self):
        self.assertTrue(W.successful_report(self.work, {'phase': 'native'}, self.synthetic_success()))

    def test_ok_booleans_without_compile_steps_are_not_success(self):
        report = self.synthetic_success()
        report['steps'] = []
        self.assertFalse(W.successful_report(self.work, {'phase': 'native'}, report))

    def test_wrong_output_with_ok_boolean_is_not_success(self):
        report = self.synthetic_success()
        report['steps'][1]['stdoutB64'] = base64.b64encode(b'wrong output').decode()
        self.assertFalse(W.successful_report(self.work, {'phase': 'native'}, report))

    def fake_step(self, fail_cleanup=False):
        (self.work / 'lease').write_text('1')
        window = L.Window(self.work, 100)
        leader = {'pid': 11, 'pgrp': 11, 'session': 11, 'startTicks': 100, 'state': 'Z'}
        seen = []
        class FakeChild:
            pid = 11
        def spawn(command, **kwargs):
            seen.append(kwargs['stdin'].read())
            self.assertNotEqual(kwargs['stdin'], subprocess.PIPE)
            self.assertTrue(kwargs['start_new_session'])
            kwargs['stdout'].write(b'fake output')
            return FakeChild()
        def cleanup(child, record):
            if fail_cleanup:
                raise PermissionError(errno.EPERM, 'fake group denied')
            record.update(beforeCleanup=[leader], remainingBeforeReap=[leader],
                          remainingAfterReap=[], exitCode=0, cleanupVerified=True)
        with patch.object(L.subprocess, 'Popen', side_effect=spawn):
            with patch.object(L, 'identity', return_value=leader):
                with patch.object(L.os, 'waitid', return_value=object(), create=True):
                    with patch.multiple(L.os, P_PID=1, WEXITED=4, WNOHANG=1, WNOWAIT=8, create=True):
                        with patch.object(window, 'cleanup', side_effect=cleanup):
                            if fail_cleanup:
                                with self.assertRaises(RuntimeError):
                                    window.run(['fake-tool'], self.work, 'fake-run', 10, b'finite stdin')
                            else:
                                result, stdout, stderr = window.run(['fake-tool'], self.work, 'fake-run', 10, b'finite stdin')
                                self.assertEqual(stdout, b'fake output')
                                self.assertEqual(stderr, b'')
                                self.assertTrue(result['cleanupVerified'])
        self.assertEqual(seen, [b'finite stdin'])
        return W.read_json(self.work / 'fake-run.json')

    def test_finite_stdin_file_with_fake_process(self):
        self.fake_step()

    def test_cleanup_permission_failure_keeps_step_and_hold(self):
        record = self.fake_step(True)
        self.assertFalse(record['cleanupVerified'])
        self.assertIn('fake group denied', record['cleanupFailure'])
        self.assertTrue((self.work / 'steps.json').exists())

    def test_lease_uses_monotonic_change_observation(self):
        (self.work / 'lease').write_text('1')
        clock = [0]
        with patch.object(L.time, 'monotonic', side_effect=lambda: clock[0]):
            with patch.object(L.time, 'time', side_effect=AssertionError('wall clock forbidden')):
                window = L.Window(self.work, 100)
                window.check()
                clock[0] = 6
                with self.assertRaisesRegex(RuntimeError, 'stopped changing'):
                    window.check()

    def test_signal_latch_check_requests_cancel(self):
        (self.work / 'lease').write_text('1')
        window = L.Window(self.work, 100)
        window.cancel_signals = [15, 15]
        with self.assertRaisesRegex(RuntimeError, 'cancellation'):
            window.check()


def main():
    # This deny guard covers the full suite. Tests use fake state only.
    with patch.object(subprocess, 'Popen', side_effect=AssertionError('subprocess creation forbidden')):
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(Controls)
        result = unittest.TextTestRunner(verbosity=2).run(suite)
    report = {'kind': 'pure-python-fake-stub-controls', 'testsRun': result.testsRun,
              'failures': len(result.failures), 'errors': len(result.errors),
              'subprocessesStarted': 0, 'realCrossProcessCleanup': 'UNRUN',
              'wslNativeSdkCompilerTests': 'UNRUN'}
    W.write_json(ROOT / 'baseline-200-pure-control-results.json', report)
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    raise SystemExit(main())
