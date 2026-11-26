# CI readiness audit

Status: `READY FOR CLOUD RUN`

The three Node.js 24 action pins were checked against public action metadata.
Checkout v7.0.1, upload-artifact v7.0.2 and download-artifact v8.0.2 declare
`node24`. Their workflow inputs remain valid.

The installer workflow keeps `contents: read` and `actions: read`. `GH_TOKEN`
appears only in the three native artifact download steps. No repository secret
is used.

The locked AppImage downloads were fetched and verified:

- `appimagetool-x86_64.AppImage`: 15,092,216 bytes, SHA-256
  `ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0`
- `runtime-x86_64`: 944,632 bytes, SHA-256
  `2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d`

WSL cannot start on this computer because Hyper-V is unavailable. The Linux
AppImage must be verified by the cloud Linux job.

The previous cloud record predates the portable Windows and Linux packages. The
README labels that record and lists the new package names separately.
