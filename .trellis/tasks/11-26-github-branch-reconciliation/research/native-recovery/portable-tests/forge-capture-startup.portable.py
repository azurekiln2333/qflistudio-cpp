"""Capture the authorized OHOS app's cold start without changing its data."""
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import time

TARGET = os.environ.get('QFLI_DEVICE_TARGET', '<device-target>')
BUNDLE = 'com.azurekiln.qfli.cpp'
OUT = Path(__file__).parent / 'forge-startup-device-20261017'
OUT.mkdir(exist_ok=True)

def hdc(*args):
    return subprocess.run(['hdc', '-t', TARGET, *args], capture_output=True,
                          text=True, encoding='utf-8', errors='replace', timeout=25)

hdc('shell', 'aa', 'force-stop', BUNDLE)
started = time.monotonic()
launch = subprocess.Popen(['hdc', '-t', TARGET, 'shell', 'aa', 'start',
                           '-a', 'EntryAbility', '-b', BUNDLE],
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

def capture(kind, extension, count):
    rows = []
    for index in range(count):
        remote = f'/data/local/tmp/forge-native-startup-{kind}-{index}.{extension}'
        stamp = round((time.monotonic() - started) * 1000)
        args = ('screenCap', '-p', remote) if kind == 'screen' else (
            'dumpLayout', '-p', remote, '-b', BUNDLE)
        result = hdc('shell', 'uitest', *args)
        local = OUT / f'{kind}-{index}.{extension}'
        if result.returncode == 0:
            hdc('file', 'recv', remote, str(local))
        rows.append({'file': local.name, 'startedMs': stamp,
                     'endedMs': round((time.monotonic() - started) * 1000),
                     'output': result.stdout.strip()})
        time.sleep(0.1)
    return rows

with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    screens = pool.submit(capture, 'screen', 'jpeg', 12)
    layouts = pool.submit(capture, 'layout', 'json', 12)
    stdout = launch.communicate(timeout=30)[0].decode('utf-8', errors='replace')
    evidence = {'bundle': BUNDLE, 'target': TARGET, 'launch': stdout,
                'screens': screens.result(), 'layouts': layouts.result()}
(OUT / 'capture.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2),
                                  encoding='utf-8')
print(json.dumps(evidence, ensure_ascii=False, indent=2))
