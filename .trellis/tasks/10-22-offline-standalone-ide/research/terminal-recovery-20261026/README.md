# Shared terminal recovery evidence

The terminal output-error repair is committed and pushed at shared-core64f0aa75a773c632a1101ce16e1900615b274960. The final narrow window passed all47 terminal tests and scoped analysis. Production source SHA256 is `7bf7d36524eb4db8b4d57d10aace5227446769f95622879af80ac7216d6beffd`. Public signatures are unchanged. Do not infer successful acceptance from clean scoped analysis or the 36 existing tests.

The reports retain exact child PID/creation FILETIME, terminal/Job-active0/handle-close records, exit status and raw stdout/stderr. Every listed window ended and was explicitly released. Consumed windows must never be replayed. Runner durations are not end-to-end publication durations. Several publications exceeded their budgets during request failures and recovery.

One attempt exhausted the frontend compiler heap before running any tests. Other attempts reached the first new transport-error case and timed out. A diagnostic eventually localized the wait to the first WidgetTester pump after the cancellation completer finished. Earlier guesses about the awaited mapped result were not established causes.

A source-only reviewer found root-zone singleton completion futures for controllers closed after cancellation. The latest test-only candidate captures controller done futures before errors occur. This candidate passed fresh actual validation in C-terminal-errors-20261026-10. No production source changed during downstream Web/Dart windows.

`core-lib-config-freeze.json` is a current working-tree binding, independently checked against all 164 captured files. It is not an archive or a clean commit. Tests and docs are excluded. Peers must recheck exact bytes before execution. SDK internals, external Pub-cache bytes, current ARM64 package correspondence and installed-device acceptance remain outside this evidence.

Web782 returned terminal with all owned Jobs empty; its app test gate failed and final publication exceeded 180 seconds. Dart791 was separately granted only after that final sender was terminal. Lua793 approves one exact source protocol only, with no execution authority. The full umbrella goal remains in progress.

Final checkpoint: source7bf7d365/test295e3901 exact tested bytes match committed blobs. Original outer69439 exit0; format82996, analyze22976 and tests69892 each terminal/Jobactive0/handlesClosed. Runner15.570s. End-to-end grant797 to release801370.202s exceeded110, so the code/test pass does not imply publication-budget success. All4 configured core remotes were pushed and independently verified.
