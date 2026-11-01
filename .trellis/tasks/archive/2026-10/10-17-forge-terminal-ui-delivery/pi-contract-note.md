# Coordinator integration note

Target confirmed via HDC: MRT-AL10 nova 14 Ultra, connected 192.168.68.207:46551. No Android builds or installs.

Root refreshed package resolution with flutter_tools.snapshot pub get. Both core and re_editor now reference live sibling. Baseline full application suite 178/178 and full static analysis passed with that current core. Do not waste effort cleaning old ignored snapshot or cache directories; Flutter dependency tracking will rebuild after pub get. Root owns tool/build_ohos_release.ps1 with refresh plus exact dependency-root guards.

Root added tool/ohos_terminal_audit.dart using forgeProfile.terminalCommandDelegate + real SandboxShellBackend, covering version/help, C/C++20 compile to explicit output followed by run, quoted filename/-D and nonzero program exit, -c object output, diagnostics and recovery. Root will build/install that audit then restore production HAP. Existing UI data must be preserved.

Workers should finish scoped implementation and focused tests; report remaining limitations precisely. Compiler argv must never trigger a native subprocess, global chdir or process-wide stdio redirection. Existing editor Run must remain operational.
