import collections
import hashlib
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[3]
staging = repo / 'tool/forge_content/staging'
review = repo / 'native/build/forge-curriculum-review-20261016'

def load(path):
    return json.loads(path.read_text(encoding='utf-8'))

def without_timestamps(value):
    if isinstance(value, dict):
        return {k: without_timestamps(v) for k, v in value.items() if k not in ('updatedAt', 'generatedAt')}
    if isinstance(value, list):
        return [without_timestamps(v) for v in value]
    return value

for name in ('forge_tutorials.json', 'forge_examples.json', 'forge_manifest.json'):
    assert without_timestamps(load(staging / name)) == without_timestamps(load(review / 'regenerated' / name)), name
print('PASS: actual generator output equals bundled data apart from timestamps')
tutorials = load(staging / 'forge_tutorials.json')['entries']
examples = load(staging / 'forge_examples.json')['entries']
manifest = load(staging / 'forge_manifest.json')
assert len(tutorials) == len(examples) == 200
paired = {entry['sourceLessonId']: entry for entry in examples}
summary = {}
for language in ('c', 'cpp'):
    items = [entry for entry in tutorials if entry['language'] == language]
    language_examples = [entry for entry in examples if entry['language'] == language]
    assert len(items) == len(language_examples) == 100
    assert len({entry['id'] for entry in items}) == 100
    assert len({entry['id'] for entry in language_examples}) == 100
    levels = collections.Counter(entry['level'] for entry in items)
    assert set(levels) == {'beginner', 'intermediate', 'advanced'} and min(levels.values()) >= 25
    distinct = collections.defaultdict(set)
    portable_ids = []
    for entry in items:
        assert entry['type'] == language and len(entry['lessons']) == 1
        lesson = entry['lessons'][0]
        example = paired[lesson['id']]
        assert all(lesson.get(field) for field in ('objective', 'explain', 'code', 'output', 'pitfalls', 'concepts', 'exercises'))
        assert 'prerequisites' in lesson
        assert len(lesson['code'].strip().splitlines()) >= 2
        assert all(word not in lesson['code'].lower() + lesson['explain'].lower() for word in ('weighted=', 'placeholder', 'todo'))
        assert example['language'] == example['type'] == example['templateType'] == language
        assert example['code'] == lesson['code'] and example['expectedOutput'] == lesson['output']
        assert example.get('portableExpectedOutput') == lesson.get('portableOutput')
        for key in ('explain', 'summary', 'code'):
            distinct[key].add(lesson[key])
        distinct['title'].add(entry['title'])
        distinct['firstExercise'].add(lesson['exercises'][0]['prompt'])
        if 'portableOutput' in lesson:
            portable_ids.append(example['id'])
    assert all(len(values) == 100 for values in distinct.values())
    summary[language] = {'tutorials': 100, 'examples': 100, 'levels': dict(levels), 'distinct': {k: len(v) for k,v in distinct.items()}, 'portableOutputIds': portable_ids}

native = load(repo / '.trellis/tasks/10-12-c-cpp-substantive-curriculum/research/cpp-content-verification.json')
ids = {entry['id'] for entry in examples}
assert native['nativeRequired'] is True and native['passed'] == 200 and native['failed'] == 0
assert not native['shapeErrors'] and not native['stagedAssetErrors']
assert len(native['results']) == 200 and {item['id'] for item in native['results']} == ids
assert all(item['status'] == 'ok' and item['exitCode'] == 0 for item in native['results'])
assert collections.Counter(item['standard'] for item in native['results']) == manifest['standards']
print('PASS: existing native report has exact 200 unique successful IDs and current standards')

report = {'regenerationMatchesBundled': True, 'summary': summary, 'standards': manifest['standards'],
          'nativeEvidence': {'generatedAt': native['generatedAt'], 'passed': native['passed'], 'reexecutedInThisReview': False},
          'assetsSha256': {name: hashlib.sha256((staging / name).read_bytes()).hexdigest() for name in ('forge_tutorials.json', 'forge_examples.json', 'forge_manifest.json')},
          'phoneAuditComplete': False, 'productionUiComplete': False}
(review / 'content-review.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))
