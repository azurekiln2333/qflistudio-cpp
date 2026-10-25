# QFLIForge · C/C++ IDE

[简体中文](README.md) · [繁體中文](README.zh-TW.md) · [English](README.en.md)

QFLIForge is a Flutter IDE for C/C++.
The project contains an editor, tutorials, examples, and a runtime adaptation layer.
A shared core provides the editor and workspace UI.
This repository maintains the C/C++ content and runtime integration.

## Repository structure

This app uses an independent Git repository.
The app depends on the shared core through a relative path.

Put both repositories under the same parent directory.

```text
checkout-parent/
  qfli_studio_core/
  qfli_c/
```

| Path | Purpose |
| --- | --- |
| `lib/` | App entry and C/C++ adaptation layer |
| `packages/qfli_c_runtime/` | C source interpreter package |
| `native/` | Compiler and WASI runtime integration |
| `tool/forge_content/` | Tutorial and example content tools |
| `ohos/` | OHOS project and native bridge |
| `test/` | Flutter and Dart tests |
| `.trellis/` | Development workflow, specs, and task records |

This runtime package interprets C source in the app process using Dart.
The native WASI toolchain is under `native/`.

The editor dependency points to a patched editor in the shared core.
Its path is `../qfli_studio_core/vendor/re_editor`.

## Development

The Dart SDK constraint is `^3.11.5`.
Use a Flutter SDK that bundles a compatible Dart SDK.
Target platforms also need their own build tools.
The first dependency download needs network access.
The app's offline capability does not make the build offline.

Enter this repository directory.
Fetch dependencies.

```sh
flutter pub get
```

Select a target device.
Start the app.

```sh
flutter devices
flutter run -d <device-id>
```

## OHOS build (in development)

This section describes a build script awaiting integration.
The published repository version does not yet include this script.

The Windows build script uses the OHOS Flutter SDK.
The script reads `flutter.sdk` from `ohos/local.properties`.
The `-FlutterSdk` parameter can specify the SDK path.

Configure the OHOS SDK and signing first.
After the script is integrated, run it from the repository root.

```powershell
./tool/build_ohos_release.ps1 -FlutterSdk "D:/path/to/flutter-ohos"
```

The script refreshes dependencies.
The script checks the actual paths of the shared core and the editor.
The script builds a release HAP for `ohos-arm64`.
The script checks that the signed package exists.
The default output path is `build/ohos/hap/entry-default-signed.hap`.
The build result depends on the local SDK, signing, and native resources.

## OHOS terminal (in development)

This section describes a terminal compile-command adaptation layer awaiting integration.
The published repository version does not yet include this layer.
This layer connects to the bundled Clang 22/WASI toolchain.
The compiler emits a WASI module.
A WASI interpreter runs the module.
The terminal does not run a program automatically after compiling.

After this layer is integrated, follow these steps.
Prepare a source file in the terminal's current directory.
Compile the source file.
Run the program through a relative path.

```sh
clang --version
clang hello.c -o hello
./hello
clang++ -std=c++20 main.cpp -o program
./program "argument with spaces"
```

The terminal resolves source, header, and output paths from the current directory.
Paths must stay inside the terminal sandbox.
Commands support object linking, for example `clang hello.o -o hello`.
Commands support `-c`, `-S`, `-E`, `-I`, `-D`, `-O`, and warning options.
Unsupported options return an error.
The program reads finite input from `input.txt` in the current directory.
The program does not use interactive standard input.
The WASI interface is not equivalent to the OHOS native interface.
A program cannot call OHOS SDK APIs through it directly.

## Checks

Run static analysis.

```sh
flutter analyze
```

Run the Flutter tests.

```sh
flutter test
```

Check the Chinese documents.

```sh
python scripts/ste-lint-zh.py README.md README.zh-TW.md
```

Static analysis and tests do not mean device acceptance passed.
The current source description does not mean every feature has shipped.
Device acceptance must correspond to an actual installed package and test records.
The native runtime spec is in `.trellis/spec/backend/`.
The development workflow is in `.trellis/workflow.md`.