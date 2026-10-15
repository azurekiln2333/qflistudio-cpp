#!/usr/bin/env python3
"""Compile and interpret every staged curriculum example with real portable tools."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


def normalized(value):
    return value.replace('\r\n', '\n').rstrip('\n')


def file_digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def validate_pairs(tutorials, examples):
    expected = {f'{language}-example-{number:03d}'
                for language in ('c', 'cpp') for number in range(1, 101)}
    ids = [entry['id'] for entry in examples]
    if len(ids) != 200 or len(set(ids)) != 200 or set(ids) != expected:
        raise ValueError('Expected exactly 100 C and 100 C++ example IDs, each once.')
    lessons = {entry['id']: entry for entry in tutorials}
    if len(tutorials) != 200 or len(lessons) != 200:
        raise ValueError('Expected exactly 200 unique paired tutorials.')
    for entry in examples:
        language = entry['id'].split('-')[0]
        if any(entry.get(key) != language for key in ('language', 'type', 'templateType')):
            raise ValueError(f"{entry['id']}: inconsistent source language.")
        tutorial = lessons.get(entry['id'].replace('-example-', '-tutorial-'))
        if not tutorial or tutorial.get('language') != language or len(tutorial.get('lessons', [])) != 1:
            raise ValueError(f"{entry['id']}: missing paired tutorial lesson.")
        lesson = tutorial['lessons'][0]
        if (entry.get('sourceLessonId') != lesson.get('id') or
                entry.get('code') != lesson.get('code') or
                entry.get('expectedOutput') != lesson.get('output') or
                entry.get('portableExpectedOutput') != lesson.get('portableOutput')):
            raise ValueError(f"{entry['id']}: tutorial/example source or output differs.")
        if len(entry['code'].strip().splitlines()) < 2 or 'weighted=' in entry['code']:
            raise ValueError(f"{entry['id']}: placeholder or incomplete program.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-root', type=Path,
                        default=Path(__file__).resolve().parents[3])
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--runtime', type=Path, required=True)
    parser.add_argument('--sdk', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    options = parser.parse_args()
    root = options.project_root.resolve()
    example_file = root / 'tool/forge_content/staging/forge_examples.json'
    tutorial_file = root / 'tool/forge_content/staging/forge_tutorials.json'
    entries = json.loads(example_file.read_text(encoding='utf-8'))['entries']
    tutorials = json.loads(tutorial_file.read_text(encoding='utf-8'))['entries']
    try:
        validate_pairs(tutorials, entries)
    except (KeyError, TypeError, ValueError) as error:
        parser.error(str(error))
    results = []
    compiler_sha256 = file_digest(options.compiler)
    runtime_sha256 = file_digest(options.runtime)
    with tempfile.TemporaryDirectory(prefix='curriculum-portable-',
                                     dir=root / 'native/build') as temporary:
        for entry in entries:
            case = Path(temporary) / entry['id']
            case.mkdir()
            (case / ('main.c' if entry['language'] == 'c' else 'main.cpp')) \
                .write_text(entry['code'], encoding='utf-8')
            output = case / 'build'
            output.mkdir()
            result = {'id': entry['id'], 'ok': False,
                      'sourceSha256': hashlib.sha256(entry['code'].encode()).hexdigest(),
                      'expectedOutputSha256': hashlib.sha256(entry.get(
                          'portableExpectedOutput', entry['expectedOutput']).encode()).hexdigest(),
                      'stdinSha256': hashlib.sha256(entry.get(
                          'inputFixtures', {}).get('stdin', '').encode()).hexdigest()}
            try:
                compiled = subprocess.run([str(options.compiler), '--threads', str(options.sdk),
                                           str(case), str(output)], capture_output=True,
                                          text=True, timeout=60)
                result['compileExit'] = compiled.returncode
                if compiled.returncode:
                    result['diagnostic'] = compiled.stderr
                else:
                    executed = subprocess.run([str(options.runtime),
                                               str(output / 'program.wasm'), str(case)],
                                              input=entry.get('inputFixtures', {}).get('stdin', ''),
                                              capture_output=True, text=True, timeout=30)
                    result.update(exit=executed.returncode, stdout=executed.stdout,
                                  stderr=executed.stderr)
                    expected = entry.get('portableExpectedOutput', entry['expectedOutput'])
                    result['ok'] = (executed.returncode == 0 and not executed.stderr and
                                    normalized(executed.stdout) ==
                                    normalized(expected))
                    if not result['ok']:
                        result['expectedOutput'] = expected
            except subprocess.TimeoutExpired:
                result['diagnostic'] = 'Actual compiler/runtime exceeded its time limit.'
            results.append(result)
            print(f"{entry['id']}: {'PASS' if result['ok'] else 'FAIL'}", flush=True)
    passed = sum(item['ok'] for item in results)
    report = {'compiler': str(options.compiler), 'runtime': str(options.runtime),
              'sdk': str(options.sdk), 'passed': passed, 'total': len(results),
              'hostOnly': True, 'threadsEnabled': True,
              'execution': 'wasmedge-interpreter',
              'generatedAt': datetime.now(timezone.utc).isoformat(),
              'compilerSha256': compiler_sha256, 'runtimeSha256': runtime_sha256,
              'stagedExamplesSha256': file_digest(example_file),
              'stagedTutorialsSha256': file_digest(tutorial_file),
              'pairedTutorials': len(tutorials),
              'results': results}
    options.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n',
                              encoding='utf-8')
    print(f'{passed}/{len(results)} host portable curriculum checks passed.')
    return 0 if passed == len(results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
