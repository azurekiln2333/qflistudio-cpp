/// Public CLI entry for the scoped, freshness-checked C/C++ content merge.
///
/// The implementation lives under `tool/forge_content/`; this thin entry keeps
/// the documented command (`dart run tool/merge_forge_content.dart`) working.
/// It is a dry run unless `--apply` is passed, and it never executes the shared
/// external write on its own (the coordinator escalation gate does that).
///
///   dart run tool/merge_forge_content.dart            # dry run + report
///   dart run tool/merge_forge_content.dart --apply    # write (gate-controlled)
library;

export 'forge_content/merge_forge_content.dart' show main;
