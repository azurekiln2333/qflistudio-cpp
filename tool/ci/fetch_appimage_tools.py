#!/usr/bin/env python3
"""Download and verify the AppImage tools that package_app.py linux needs.

The Linux job runs this step before the packaging step. The lock file pins one
address and one SHA-256 per file. A file whose digest differs is not used.
The digests are trust on first use: they come from our own download.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import urllib.parse
import urllib.request

LOCK_FILE = Path(__file__).resolve().parent / 'appimage-tools.lock.json'
# package_app.appimage_tools() reads this variable.
TOOLS_VARIABLE = 'QFLI_APPIMAGE_TOOLS'
USER_AGENT = 'qfli-c-github-actions'


class ToolError(Exception):
    """A missing, unexpected or unverified AppImage tool."""


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def read_lock(path=None):
    """Return the locked downloads. Refuse an address that is not pinned."""
    path = Path(path or LOCK_FILE)
    try:
        document = json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError) as error:
        raise ToolError(f'Cannot read the AppImage tool lock file {path}: {error}') from error
    downloads = document.get('downloads')
    if not isinstance(downloads, list) or not downloads:
        raise ToolError(f'The AppImage tool lock file {path} holds no downloads.')
    for entry in downloads:
        name = entry.get('name')
        if not name or Path(name).name != name:
            raise ToolError(f'The lock file names an unsafe file: {name!r}')
        parsed = urllib.parse.urlsplit(entry.get('url') or '')
        if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password:
            raise ToolError(f'{name} needs an HTTPS address without credentials.')
        if not entry.get('version') or '/continuous/' in parsed.path:
            raise ToolError(f'{name} needs a versioned address, not a moving tag.')
        if len(entry.get('sha256') or '') != 64:
            raise ToolError(f'{name} needs a 64 digit SHA-256 value.')
    return downloads


def download(entry, directory):
    """Download one locked file and verify its SHA-256 before it is used."""
    target = Path(directory) / entry['name']
    request = urllib.request.Request(entry['url'], headers={'User-Agent': USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=120) as source, target.open('wb') as sink:
            for chunk in iter(lambda: source.read(1 << 20), b''):
                sink.write(chunk)
    except OSError as error:
        raise ToolError(f'Cannot download {entry["name"]}: {error}') from error
    actual = sha256(target)
    if actual != entry['sha256']:
        target.unlink(missing_ok=True)
        raise ToolError(
            f'{entry["name"]} has the SHA-256 {actual}, not {entry["sha256"]}. '
            'The file changed; nobody updated the lock file.')
    if 'sizeBytes' in entry and target.stat().st_size != entry['sizeBytes']:
        raise ToolError(f'{entry["name"]} has another size than the lock file records.')
    target.chmod(0o755)
    return target


def fetch(directory, lock=None):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    return [download(entry, directory) for entry in read_lock(lock)]


def main(arguments=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path,
                        help='Directory for the tools; the workflow passes $RUNNER_TEMP')
    parser.add_argument('--lock', type=Path, help=f'Lock file (default: {LOCK_FILE})')
    args = parser.parse_args(arguments)
    try:
        targets = fetch(args.output, args.lock)
    except ToolError as error:
        print(f'error: {error}', file=sys.stderr)
        return 1
    print(f'{TOOLS_VARIABLE}={args.output.resolve()}')
    for target in targets:
        print(f'Verified {target.name} ({target.stat().st_size} bytes).')
    # The workflow copies the assignment into GITHUB_ENV for the packaging step.
    environment_file = os.environ.get('GITHUB_ENV')
    if environment_file:
        with Path(environment_file).open('a', encoding='utf-8') as stream:
            stream.write(f'{TOOLS_VARIABLE}={args.output.resolve()}\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
