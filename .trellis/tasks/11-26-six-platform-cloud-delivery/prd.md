# Six-platform cloud delivery verification

## Goal

Provide complete GitHub-hosted validation and package workflows for Windows, Linux, macOS, iOS, Android, and OHOS.

## Requirements

- Cover native preparation, Flutter validation/builds, package assembly, metadata, digests, upload, and retention.
- Bind native input provenance to an explicitly accepted source/dependency baseline.
- Execute tests, lint, and package validation in GitHub only.
- Identify exact platform package names and signing states. Record unsupported install/device gates truthfully.
- Retain reusable intermediates in bounded cloud artifacts/caches without adding binaries to source.
- Inspect current runs and artifact metadata. Never treat workflow presence or an old green run as current acceptance.

## Acceptance

All required jobs pass for the reviewed source and accepted inputs. Each platform has a complete output inventory and checksum/provenance records. Missing signing or device proof stays visible. No product validation runs locally.

## Dependency

Wait for safe source reconciliation and portable dependency decisions before changing pins or triggering final cloud runs.
