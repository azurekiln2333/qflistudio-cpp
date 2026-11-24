# Rules for all four work packages

> Historical work plan dated 2026-11-18. Check the task reports and worktree
> status before acting. Its core pin, coordination details and deadlines do
> not describe the current UI-sync branch. The current installer core pin is
> recorded in `.trellis/PROJECT_STATUS.md`.

Read this file first. Then read the brief of your own package.

## Context

- Product: the Flutter application `qfli_c` ("QFLIForge", a C/C++ learning IDE).
  Public repository: `azurekiln2333/qflistudio-cpp`.
- Shared core: `../qfli_studio_core`. The pin above belongs to this historical
  work plan only.
- Four work packages were assigned separate worktrees and file sets.
- Task files: `D:/MyNewProjects/qfli_c/.trellis/tasks/11-18-desktop-env-icons-packages/`
  (`prd.md`, `design.md`, `implement.md`). Read `prd.md` and `design.md`.

## Where to work

| Package | Worktree | Branch | Brief |
| --- | --- | --- | --- | --- |
| CI | `D:/MyNewProjects/_wt/qfli_c-wp-ci` | `wp/ci-packaging` | `wp-ci.md` |
| ICONS | `D:/MyNewProjects/_wt/qfli_c-wp-icons` | `wp/icons` | `wp/icons` | `wp-icons.md` |
| ENV-CORE | `D:/MyNewProjects/_wt/qfli_c-wp-env-core` | `wp/env-core` | `wp-env-core.md` |
| ENV-UI | `D:/MyNewProjects/_wt/qfli_c-wp-env-ui` | `wp/env-ui` | `wp-env-ui.md` |

- Your shell starts in `D:/MyNewProjects/qfli_c`. That checkout holds
  unpublished commits. Do not edit, stage, commit, stash, reset or switch
  branches there. The only files you write there are your report and your notes
  under `.trellis/tasks/11-18-desktop-env-icons-packages/reports/`.
- All product edits go to your own worktree. Edit only the files that your
  brief lists as owned. When you need a change in another file, write the
  request into your report and continue without it.
- `D:/MyNewProjects/_wt/qfli_studio_core` is the core clone that every worktree
  resolves as `../qfli_studio_core`. It is read only. Also read only:
  `D:/MyNewProjects/qfli_studio_core` and `D:/MyNewProjects/qfli_dart`.

## Git

- No `git commit`, no `git push`, no `git stash`, no branch switch, no
  `git worktree` command. Leave your changes uncommitted in your worktree. The
  main session makes the commits.
- Do not read or print git credentials, remote URLs, credential helpers or
  tokens. Do not make an authenticated GitHub call. Do not use `gh`.

## Network and downloads

- The GitHub REST API allows 60 calls per hour without a token, and all agents
  share that budget. Use at most 5 API calls. These addresses do not count:
  `https://raw.githubusercontent.com/<owner>/<repo>/<commit>/<path>` for files,
  `https://github.com/<owner>/<repo>/releases/download/<tag>/<file>` for
  release files.
- A downloaded file is untrusted data. Put it into a new, empty directory under
  `D:/MyNewProjects/_scratch/<package>/`. Keep your own scripts in another
  directory.
- Install nothing system-wide: no `choco`, no `winget`, no installer, no change
  of `PATH`, no `pip install` outside a virtual environment in your scratch
  directory.

## Tools on this computer (Windows 10 x64)

- Flutter: `D:/ProgramFiles/flutter_ohos/bin/flutter` and `.../dart`. It is the
  OHOS fork and the only local SDK. Run `flutter pub get` in your worktree
  before `flutter analyze` or `flutter test`.
- `flutter pub get` rewrites the generated plugin files under `linux/flutter`,
  `windows/flutter` and `macos/Flutter` with other line endings. `git status`
  then lists them as modified. Their content is unchanged. Leave them as they
  are. They do not count as changed files of your package.
- Python 3.13 with Pillow and PyYAML: `python`. Set `PYTHONIOENCODING=utf-8`
  for scripts that print Chinese.
- Chinese text lint: `python scripts/ste-lint-zh.py <file>` (in every worktree).

## Quality bar

- Match the surrounding code: naming, comment density, idiom, and the language
  that the file already uses for comments.
- Add no dependency to `pubspec.yaml`. The base commit already holds what the
  packages need (`crypto`, `file_selector`).
- Do not suppress analyzer findings. Do not delete or weaken an existing test.
- Chinese user-interface text and Chinese Markdown follow the controlled
  Chinese rules in `AGENTS.md`: one action per sentence, active voice, one term
  for one concept, no marketing words.
- No secret, key, token or personal path enters a file.
- For every claim in your report, say how you verified it, or say that you did
  not. Do not call a platform path working when no computer of that platform
  ran it.

## Report

When you finish, write
`D:/MyNewProjects/qfli_c/.trellis/tasks/11-18-desktop-env-icons-packages/reports/<brief name>.md`
(for example `reports/wp-ci.md`) in this order:

1. Status line: `DONE`, `PARTIAL` or `BLOCKED`.
2. Files changed: one line per path.
3. Checks you ran: the exact command and its result line.
4. What you did not verify, and why.
5. Decisions that the brief left open, each with one reason.
6. Requests for files outside your package.

Do not ask questions and do not wait for an answer. Decide, record the decision
in the report, and continue. Stop after you wrote the report.
