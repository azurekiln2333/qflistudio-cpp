# Browser Editor Input

## Actual Failure and Root Cause

The rebuilt Forge Chrome UI accepted a complete multiline replacement into its
accessible textarea, but Ctrl+S saved only `#include <stdio.h>`. Ordinary Chrome
mode passed the same multiline input, save, reload and clipboard reopen check.

The installed Flutter engine's
`engine/src/flutter/lib/web_ui/lib/src/engine/semantics/text_field.dart`
implements `SemanticsTextEditingStrategy.addEventHandlers` with `input`,
`keydown` and `selectionchange` listeners. Unlike the default strategy, it does
not register `beforeinput`. The default strategy's `handleBeforeInput` captures
inserted text and its replacement range. Without it, `inferDeltaState` leaves
the delta text empty and its range at -1. The client receives a non-text update
containing the old line instead of the actual pasted value.

The editor projects the current line as its IME value even when the document
selection spans many lines. Applying that unchanged old line to the whole
selection reduces the document to the old line, matching the observed failure.
The semantic `onSetText` callback is not the handler for DOM textarea input;
changing that callback alone does not repair the text input channel.

## Contract

- Web accessibility connections set `enableDeltaModel: false`, allowing the
  engine to deliver the actual complete `TextEditingValue` from the textarea.
- Normal Web connections and native connections retain the existing delta
  path and its smart symbol transformations.
- A Web semantics-enabled listener updates active connection configuration
  when accessibility is enabled after the editor receives focus.
- Full-value Web updates use the existing controller edit and mobile-prefix
  application logic. They retain selection, composing, multiline replacement,
  subsequent typing and read-only protection. The per-line IME projection is
  retained; no document-sized editing buffer or custom delta inference is added.
- Accessibility full-value input uses literal platform text. Delta-based smart
  symbol expansion is not invoked in this mode; shortcuts remain available.
- The SDK and actual sibling shared-core repository remain untouched. Product
  changes live in the staged vendor copy and reviewable task patch templates.

## Verification

The new browser regression sends `TextInputClient.updateEditingState` through
`TestTextInput.updateEditingValue`, covering composition and selection, full
multiline replacement, trailing-line typing, newline insertion and read-only
updates. A second regression verifies switching an already-focused connection
from deltas to full values when semantics are enabled.

Actual rebuilt normal and accessibility Chrome UI checks passed multiline
replacement, Ctrl+S save to the exact IndexedDB file, reload/reopen and copied
source confirmation. All six focused browser widget regressions now pass in
installed Edge, including composition, delta input and semantics activation.

The harness needs local CanvasKit assets in the review app's test directory.
Direct tool snapshot invocations also need Dart's --packages argument pointing
to the Flutter SDK tool package config. Widget fixture platform changes use
TargetPlatformVariant so cleanup precedes binding invariant checks. Start with
semanticsEnabled:false and acquire explicit semantics handles when the test
needs them; default enabled semantics invalidate normal-input preconditions.

These editor results do not prove browser compilation, runtime file writeback
or UI run/stop, whose compiler artifacts remain unavailable.
