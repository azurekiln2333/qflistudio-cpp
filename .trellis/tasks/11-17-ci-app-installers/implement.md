# Implementation plan

All product edits happen in the worktree `D:/MyNewProjects/_wt/qfli_c-ci-app-installers` (branch `ci/app-installers`, base `github/main`). Do not edit product files in `D:/MyNewProjects/qfli_c`. Do not touch `D:/MyNewProjects/qfli_studio_core` or `D:/MyNewProjects/qfli_dart` (read only).

## Steps

1. [x] Create the worktree and branch from `github/main`.
2. [x] Helper agent: write `tool/ci/` helpers and tests per `design.md` contracts.
3. [x] Main session: write `.github/workflows/app-installers.yml`.
4. [x] Local checks (see below).
5. [x] Commit with conventional messages, no AI signature. Scan `git log github/main..HEAD` before the push.
6. [x] Push `ci/app-installers` to `github`. Watch the run. Fix failures. Repeat until green.
7. [x] Write `tool/ci/README.md` with the verified run. Lint it.
8. [x] `trellis-check` on the branch diff.
9. [x] Fast-forward GitHub `main`. Confirm the `main` run. Merge `github/main` into local `main`. Not done: the branch and worktree stay (see `design.md`, Deviations).
10. [x] Update specs, commit Trellis files on local `main` (not pushed to GitHub).

## Results (2026-11-17 UTC)

- Step 4: 85 unit tests pass. The workflow YAML parses and holds six jobs. The README lint reports 0 findings. `pyflakes`, `actionlint` and `shellcheck` were not run.
- Step 4: `git diff --check ba5c33a 1969ef4` reports eight lines, all in `tool/ci/stock-flutter-core.patch`. Each line is a blank context line of the unified diff and needs its single space. No other file has a finding.
- Step 4: cloud evidence covers the patch check. `prepare_core.py` applied the patch to the pinned core in the five stock Flutter jobs of both green runs.
- Step 6: run `44120892921` on `ci/app-installers` (commit `5a9522a`) ended with seven of seven jobs `success`.
- Step 8: the `trellis-check` sub-agent failed twice with a gateway timeout. The main session ran the check through the `trellis-check` skill.
- Step 9: GitHub `main` moved `ba5c33a..1969ef4` by fast-forward. Run `44125206686` on `main` ended with seven of seven jobs `success`. The local merge commit is `b2408cd`. 85 unit tests pass in the main checkout after the merge.
- Step 10: the spec files and the task files are commits on local `main`. Nothing from local `main` was pushed.

## Local checks

```bash
cd D:/MyNewProjects/_wt/qfli_c-ci-app-installers
python -m py_compile tool/ci/*.py
python -m unittest discover -s tool/ci -p "test_*.py" -v
python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/app-installers.yml', encoding='utf-8'))"
python scripts/ste-lint-zh.py tool/ci/README.md
```

Patch check against a clean core clone (scratch only):

```bash
git clone -q D:/MyNewProjects/qfli_studio_core D:/MyNewProjects/_scratch/ci-app-plan/core-clone
git -C D:/MyNewProjects/_scratch/ci-app-plan/core-clone checkout -q 573d1b6eecf1c2b392ad753264a5a09f62f8335e
git -C D:/MyNewProjects/_scratch/ci-app-plan/core-clone apply --check <worktree>/tool/ci/stock-flutter-core.patch
```

## Risk points

- iOS application build has never run anywhere. Expect iterations in the Runner link step.
- OHOS: 2.3 GB tools download and API 18 static libraries linked by the API 26 toolchain.
- Windows: Inno Setup location on the hosted image.
- Push safety: never push `main` from the main checkout. Only `ci/app-installers` and its fast-forward to `github main`.
