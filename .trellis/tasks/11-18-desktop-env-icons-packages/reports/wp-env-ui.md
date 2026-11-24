# WP-ENV-UI report

Status: `DONE`

The tools page now exposes `环境配置` on supported desktop platforms. The page
shows detected C and C++ compilers, preference, toolchain directory, setup
progress, cancellation and removal. Unsupported platforms do not render the
entry. The five existing tool sections stay in place.

Validation: `flutter analyze` passed. The integrated environment and tools tests
passed, including narrow layouts and large text. No real application window was
used.
