# WP-CI report

Status: `DONE` for the implementation work package; task acceptance remains open.

2026-11-25 checkpoint: coordinator merge `b5896d9` includes this work in local
main, plus helper tests from `d673a23`; `9e34dcc` fixes a core-patch test. The
results below are historical. No new cloud package run is claimed. AppImage,
portable EXE and Node24 annotations still need source-bound GitHub checks. All
future builds run on GitHub; do not rerun historical local build steps.

The CI work package is integrated on `ci/app-installers`. It updates checkout,
upload-artifact and download-artifact to the pinned Node.js 24 releases.
Windows now publishes the setup program, portable ZIP and single-file launcher.
Linux now publishes the Debian package, tar.gz bundle and AppImage. Linux icon
files come from `linux/packaging/icons`. Job names and summaries state that x64
and x86_64 name the same architecture.

Validation: `python -m unittest discover -s tool/ci -p "test_*.py"` ran 86
tests and passed. Both workflow files parse with PyYAML. The Chinese README
passed `scripts/ste-lint-zh.py` with zero findings. NSIS compilation was tested
with a local NSIS 3 binary. Linux AppImage and cloud package jobs remain to be
verified on their target runner.
