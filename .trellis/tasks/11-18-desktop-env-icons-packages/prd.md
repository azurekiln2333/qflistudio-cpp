# Desktop toolchain setup, unified icons, single-file packages, Node 24 actions

## Goal

The desktop application offers an environment page with a one-click setup of
clang and gcc. Every platform shows the OHOS icon. Windows and Linux get a
single-file edition. The workflow actions run on Node.js 24.

## Source requests (2026-11-18)

- "为什么linux windows都只有x64 没有x86_64 为什么都是安装版没有安装版和单文件版？"
- "nodejs能不能更新一下"
- "windows linux macos 在软件设置内能不能加个环境配置的？？能不能加上一键配置clang、gcc环境的"
- "还有 图标能不能跟随ohos已配置的图标 几个平台都一样"
- "制定完计划立马派下去给herdr同工作区的4个pi先做"
- "做完立马gitcommit不带上你的署名 cicd"

## Requirements

- R1 Node.js 24: every action of `app-installers.yml` and
  `native-artifacts.yml` runs on Node.js 24.
- R2 Single-file editions: `qfli-forge-windows-x64-portable.exe` and
  `qfli-forge-linux-x64.AppImage`. The existing packages stay.
- R3 Names: the job names and the README state that x64 equals x86_64. No
  artifact and no package file gets a new name.
- R4 Environment page on Windows, Linux and macOS: the compiler in use, the
  preferred compiler family, the toolchain directory. The application has an
  entry to the page.
- R5 One-click setup: one action makes clang usable, one action makes gcc
  usable, where the platform allows it.
- R6 Icon: Android, iOS, OHOS, Windows, Linux, macOS and the web show the
  OHOS-configured icon.
- R7 Publication: conventional commit messages without an AI signature, a scan
  before each push, a green cloud run, then GitHub `main`.

## Constraints

- Local `main` holds unpublished commits with a release signing
  configuration. Never push local `main`. Publication goes through the branch
  `ci/app-installers`, which starts from GitHub `main`.
- The shared core is pinned at `573d1b6`. This task changes no file of the
  core and pushes nothing to the core repository.
- No secret, key, token or keystore path enters the repository or an
  artifact.
- The OHOS product stays offline (`offline-platform-policy.md`). The
  environment page and its network use exist on desktop only.
- The application downloads only after the user confirmed an action that
  shows the exact address.
- A report states what a real computer or a cloud run verified, and what
  nobody verified.

## Acceptance criteria

- [ ] The cloud run on the pushed commit ends with all jobs `success` and
      shows no Node.js 20 annotation.
- [ ] `app-windows-x64` holds the setup program, the zip and the portable
      executable. `app-linux-x64` holds the `.deb`, the `.tar.gz` and the
      AppImage. `SHA256SUMS` lists each package.
- [ ] `python -m unittest discover -s tool/ci -p "test_*.py"` passes.
- [ ] `python tool/icons/generate_app_icons.py --check` passes, and the two
      byte copies have the blob `4a004e995ec9534bbc36f1cb8830d5f2d65f6f44`.
- [ ] `flutter analyze` reports no issues and `flutter test` passes on the
      integrated branch.
- [ ] On Windows, one real run of each setup action ends with a compiled and
      started C program and C++ program.
- [ ] The outgoing commits hold no `claude`, `anthropic` or `co-authored` text
      in author, committer or message.
- [ ] The final report names the Linux and macOS parts that no real computer
      ran.

## Out of scope

- An entry inside the Settings page of the shared core. It needs a change and
  a push in `qflistudio-core`, which the user did not authorize.
- Desktop packages for arm64 and for 32-bit x86.
- Code signing and notarization.
