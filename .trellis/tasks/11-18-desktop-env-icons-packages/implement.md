# Implementation plan

## Steps

- [x] 0.1 Base in the worktree `D:/MyNewProjects/_wt/qfli_c-ci-app-installers`:
      interface, stub, `crypto`, `file_selector`, lock file.
- [x] 0.2 Briefs: `wp-common.md`, `wp-ci.md`, `wp-icons.md`, `wp-env-core.md`,
      `wp-env-ui.md`.
- [ ] 0.3 Base commit on `ci/app-installers`, four worktrees, `task.py start`.
- [ ] 1 Dispatch the four packages to `w5C:p2`, `w5C:p3`, `w5C:p4`, `w5C:p5`.
- [ ] 2 Gate A for each package when its report arrives.
- [ ] 3 Integrate on `ci/app-installers`: ICONS, CI, ENV-CORE, ENV-UI.
- [ ] 4 Gate B on the integrated branch.
- [ ] 5 Specs: `app-installers.md`, `desktop-runtime.md`, `forge-tools.md`, a
      new section for the toolchain environment.
- [ ] 6 Commits, signature scan, push `ci/app-installers`, cloud run (gate C).
- [ ] 7 Push to GitHub `main`. Check the runs on `main`.
- [ ] 8 Merge into local `main` without a push. Remove the four worktrees and
      the four package branches.

## Gate A: one package

- The report exists and states `DONE`, `PARTIAL` or `BLOCKED`.
- `git status --short` in the worktree lists owned files only. The generated
  plugin files of `flutter pub get` do not count.
- `git log` shows no new commit. The public branch list shows no new branch.
- The main session reads the whole diff. It reruns the checks of the brief. A
  claim of the report counts only after the rerun.
- No new secret, no new permission in a workflow, no suppressed analyzer
  finding, no weakened test.

## Gate B: integrated branch

```bash
cd D:/MyNewProjects/_wt/qfli_c-ci-app-installers
flutter pub get
flutter analyze
flutter test
python -m unittest discover -s tool/ci -p "test_*.py"
python -m unittest discover -s tool/icons -p "test_*.py"
python tool/icons/generate_app_icons.py --check
git hash-object assets/app_icon.png ohos/AppScope/resources/base/media/app_icon.png
python -c "import yaml,sys; [yaml.safe_load(open(p, encoding='utf-8')) for p in sys.argv[1:]]" .github/workflows/app-installers.yml .github/workflows/native-artifacts.yml
git diff --check github/main
PYTHONIOENCODING=utf-8 python D:/MyNewProjects/qfli_c/scripts/ste-lint-zh.py tool/ci/README.md
```

- One real run of each Windows setup action, with a compiled and started C
  program and C++ program.
- The main session looks at the contact sheet of the icons.

## Gate C: cloud run

- Scan before each push: author, committer and message of every outgoing
  commit hold no `claude`, `anthropic` or `co-authored`.
- The outgoing diff holds no signing material and nothing from the local-only
  commits.
- Push with an explicit refspec: `git push github ci/app-installers:ci/app-installers`.
- Every job of the run ends with `success`. The run shows no Node.js 20
  annotation.
- `app-windows-x64` holds three packages. `app-linux-x64` holds three
  packages. `SHA256SUMS` lists each one.
- Then `git push github ci/app-installers:main`, and the same check for the
  runs on `main`.

## Rollback points

- Before step 3: delete a package worktree and dispatch the package again.
- After step 3: `git revert` of the package commit on `ci/app-installers`.
- After step 7: a revert commit on the branch, a green run, then `main`.

## Reports

`reports/wp-ci.md`, `reports/wp-icons.md`, `reports/wp-env-core.md`,
`reports/wp-env-ui.md`, `reports/wp-icons-contact-sheet.png`.
