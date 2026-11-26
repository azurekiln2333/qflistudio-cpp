# Design

Audit native-artifacts.yml, app-installers.yml, and their helpers against the installer/native specs. Record application, core, Flutter, native, and workflow revisions separately. Select exact native runs when validating new source. Fail closed on mismatch or missing artifacts.

Separate final install packages from cloud intermediates and diagnostic evidence. Define bounded retention and avoid duplicate local downloads. Production signing uses approved secret mechanisms; it never enters source or Trellis.
