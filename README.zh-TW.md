# QFLIForge · C/C++ IDE

[簡體中文](README.md) · [繁體中文](README.zh-TW.md) · [English](README.en.md)

QFLIForge 是面向 C/C++ 的 Flutter IDE。
專案包含編輯器、教學、範例和執行環境介接層。
共享核心提供編輯器和工作區介面。
本倉庫維護 C/C++ 內容與執行環境介接。

## 倉庫結構

本應用程式使用獨立的 Git 倉庫。
本應用程式透過相對路徑依賴共享核心。

請將兩個倉庫放在同一父目錄。

```text
checkout-parent/
  qfli_studio_core/
  qfli_c/
```

| 路徑 | 用途 |
| --- | --- |
| `lib/` | 應用程式入口與 C/C++ 介接層 |
| `packages/qfli_c_runtime/` | C 原始碼解譯器套件 |
| `native/` | 編譯器與 WASI 執行環境介接 |
| `tool/forge_content/` | 教學與範例內容工具 |
| `ohos/` | OHOS 工程與原生橋接 |
| `test/` | Flutter 與 Dart 測試 |
| `.trellis/` | 開發流程、規範與任務記錄 |

此執行環境套件以 Dart 在應用程式內解譯 C 原始碼。
原生 WASI 工具鏈位於 `native/`。

編輯器依賴指向共享核心中的修補版本。
其路徑為 `../qfli_studio_core/vendor/re_editor`。

## 開發

Dart SDK 約束為 `^3.11.5`。
請使用內含相容 Dart SDK 的 Flutter SDK。
目標平台還依賴對應的建置工具。
首次下載依賴需要網路。
應用程式的離線能力不代表建置流程免連網。

請進入本倉庫目錄。
請取得依賴。

```sh
flutter pub get
```

請選擇目標裝置。
請啟動應用程式。

```sh
flutter devices
flutter run -d <device-id>
```

## OHOS 建置（開發中）

本節記錄待整合的建置腳本。
目前倉庫版本尚未包含此腳本。

Windows 建置腳本使用 OHOS Flutter SDK。
腳本讀取 `ohos/local.properties` 的 `flutter.sdk`。
參數 `-FlutterSdk` 可指定 SDK 路徑。

請先設定 OHOS SDK 與簽章。
腳本整合後，請在倉庫根目錄執行。

```powershell
./tool/build_ohos_release.ps1 -FlutterSdk "D:/path/to/flutter-ohos"
```

腳本更新依賴。
腳本檢查共享核心與編輯器的實際路徑。
腳本建置面向 `ohos-arm64` 的 release HAP。
腳本檢查簽章套件是否存在。
預設輸出路徑為 `build/ohos/hap/entry-default-signed.hap`。
建置結果取決於本機 SDK、簽章與原生資源。

## OHOS 終端機（開發中）

本節記錄待整合的終端機編譯命令介接層。
目前倉庫版本尚未包含此介接層。
此介接層接入內建 Clang 22/WASI 工具鏈。
編譯器輸出 WASI 模組。
WASI 解譯器執行模組。
終端機不會在編譯後自動執行程式。

介接層整合後，請參考以下步驟。
請先在終端機目前目錄準備原始檔。
請編譯原始檔。
請透過相對路徑執行程式。

```sh
clang --version
clang hello.c -o hello
./hello
clang++ -std=c++20 main.cpp -o program
./program "argument with spaces"
```

終端機從目前目錄解析原始檔、標頭檔和輸出路徑。
路徑必須位於終端機沙箱內。
命令支援目的檔連結，例如 `clang hello.o -o hello`。
命令支援 `-c`、`-S`、`-E`、`-I`、`-D`、`-O` 與警告選項。
不支援的選項會回傳錯誤。
程式透過目前目錄的 `input.txt` 讀取有限輸入。
程式不使用互動式標準輸入。
WASI 介面不等同於 OHOS 原生介面。
程式不能依此直接呼叫 OHOS SDK 介面。

## 檢查

請執行靜態分析。

```sh
flutter analyze
```

請執行 Flutter 測試。

```sh
flutter test
```

請檢查中文文件。

```sh
python scripts/ste-lint-zh.py README.md README.zh-TW.md
```

靜態分析和測試不代表裝置驗收通過。
目前原始碼說明不代表每個功能均已發行。
裝置驗收必須對應實際安裝套件與測試記錄。
原生執行環境規範見 `.trellis/spec/backend/`。
開發流程見 `.trellis/workflow.md`。
