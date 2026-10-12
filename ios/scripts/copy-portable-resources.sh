#!/bin/bash
set -euo pipefail

: "${TARGET_BUILD_DIR:?Xcode TARGET_BUILD_DIR is required}"
: "${UNLOCALIZED_RESOURCES_FOLDER_PATH:?Xcode resource folder is required}"

destination="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/forge-wasi-sdk"
case "$UNLOCALIZED_RESOURCES_FOLDER_PATH" in
  /*|*..*) echo "Invalid Xcode resource folder" >&2; exit 1 ;;
esac
case "$destination" in
  "$TARGET_BUILD_DIR"/*/forge-wasi-sdk) ;;
  *) echo "Invalid portable resource destination" >&2; exit 1 ;;
esac

if [[ "${QFLI_PORTABLE_ENABLED:-0}" != 1 ]]; then
  # Remove an earlier enabled build's resources when changing configurations.
  rm -rf -- "$destination"
  exit 0
fi

: "${QFLI_RUNTIME_PACKAGE:?Run native/toolchain/build-ios-portable.sh first}"
: "${PLATFORM_NAME:?Xcode PLATFORM_NAME is required}"
sdk="$QFLI_RUNTIME_PACKAGE/resources/sdk"
library="$QFLI_RUNTIME_PACKAGE/$PLATFORM_NAME/libqfli_portable.a"
[[ -f "$library" ]] || { echo "Missing native static library: $library" >&2; exit 1; }
[[ -f "$sdk/toolchain.json" && -f "$sdk/share/wasi-sysroot/lib/wasm32-wasip1/eh/libunwind.a" ]] || {
  echo "Missing WASI SDK resources: $sdk" >&2; exit 1;
}

rm -rf -- "$destination"
mkdir -p -- "$(dirname "$destination")"
/usr/bin/ditto "$sdk" "$destination"
