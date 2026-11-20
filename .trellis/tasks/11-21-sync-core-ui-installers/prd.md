# Sync shared core UI and build six-platform installers

## Request

Sync the shared UI changes and run the six-platform installer workflow.

## Requirements

- Use the published core main commit cbaa4a4166461baafff7c1a343bd3ca1865fcc4f.
- Preserve Forge identity, offline policy, owned content, tools and native runners.
- Update the pinned core in every installer job and its compatibility helper.
- Build Android ARM64/x86_64, iOS ARM64, OHOS ARM64, Windows x64, Linux x64 and macOS universal packages.
- Preserve all existing uncommitted work in the original application and core checkouts.
- Record commits, validation, cloud run and artifact results for the next AI.

## Acceptance criteria

- Local analysis, app tests and CI helper tests pass against the clean pinned core.
- All seven installer jobs finish successfully and upload the expected artifacts.
- Report signing limits and distinguish package validation from device execution.
- Cloud builds use the new core commit and the existing verified native artifacts.

## Scope

This task synchronizes published main UI. Preview core branches, unfinished desktop-toolchain work, release signing and independent desktop native artifacts remain separate tasks.

