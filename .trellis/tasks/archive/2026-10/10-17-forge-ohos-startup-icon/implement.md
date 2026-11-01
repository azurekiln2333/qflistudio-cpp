# Execution

1. Herdr forge-native owns Index.ets and the EntryAbility progress handler.
2. Herdr forge-terminal owns Dart OHOS startup control and focused lifecycle tests.
3. Herdr forge-core independently reviews JVMX parity, icon references and package verification.
4. Root integrates and reviews, runs relevant Dart checks and the signed production build, inspects HAP icons/bundle and installs with `hdc install -r`.
5. Root captures native startup and confirms home/About on the authorized phone, recording exact artifact evidence. Keep app data. Update specs and journal without committing.

If a splash lifecycle check fails, correct the handshake before installation. Do not replace the validated compiler/runtime archives for this presentation-only change.
