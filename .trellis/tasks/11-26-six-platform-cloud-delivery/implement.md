# Execution plan

1. Capture workflow topology and current run/artifact metadata.
2. Identify missing checks, cache/intermediate coverage, provenance gates, and signatures.
3. Implement reviewed workflow/helper fixes after approval.
4. Push reviewed source and run cloud validation.
5. Build exact native inputs and then six-platform packages.
6. Review job results, package inventories, digests, retention, and signing evidence.
7. Commit acceptance metadata and update Trellis gates.

Do not download whole artifact archives locally. Do not run local build/test/lint/install commands.
