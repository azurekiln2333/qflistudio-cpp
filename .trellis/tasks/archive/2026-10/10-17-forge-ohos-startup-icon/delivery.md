# Delivery — OHOS native startup and icon

Delivered the JVMX-style ArkUI startup view with the C mascot and determinate progress, retaining it until bootstrap and the ready home layout finish. OHOS now holds Flutter's first frame and reports initialization progress over `qflistudio/platform`. Existing compiler/platform handlers remain intact. The launcher, native startup and Flutter About icon use the same current artwork.

Signed production HAP: `build/ohos/hap/entry-default-signed.hap`, 151351928 bytes, SHA256 `450dc25834cbd99565f8a874d9d358bb645d92f07b61f0bda3d5cb4997edc689`, bundle `com.azurekiln.qfli.cpp`. Native runner SHA256 remains `cde3ce8fd0a65c884a06ea45829f1c381246d29049a4db2515a274ae64e7763d` (the previously validated compiler/terminal backend).

Root Dart analysis passed; all 8 focused OHOS/Android startup lifecycle tests passed. The signed release HAP built successfully through Hvigor, and the portable HAP verifier passed. Source fingerprint and packaged icon/bundle checks passed. Logs and artifact metadata are under `native/build/forge-startup-*-20261017.*`.

Installed with `hdc install -r` on nova 14 Ultra / MRT-AL10, target `192.168.68.207:46551`. Cold-start layout captured native `Stack` ID `qfli-native-startup-splash` and native `Progress` ID `qfli-native-startup-progress`, visible with value 100. The following home layout contained QFLIForge and the four existing projects, with the splash removed. About visibly showed the new C mascot. Final app PID was 50882, with the new `.cpp` app left on its home page. Evidence: `native/build/forge-startup-device-20261017/`, especially `native-splash-proof.json`, `final-home.json`, `about.jpeg`, and `verified.png`.

Both `.cpp` and the old `.forge` bundle are installed. The old launcher entry opens its older app; it was retained without uninstalling or deleting its data. The `.cpp` update preserved its install time and projects. No signing edits, commits, pushes or device security changes were made in this follow-up.

Implementation and independent review were coordinated through Herdr pi agents `forge-native` (w6:p4), `forge-terminal` (w6:p5), and `forge-core` (w6:p7). Their reports are in this task directory. Runtime source/asset/linkage details and exact hashes are recorded in `delivery.json`.
