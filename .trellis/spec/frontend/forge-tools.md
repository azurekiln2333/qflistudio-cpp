# Forge Tools Contract

## Scope

`lib/forge_integer_tools.dart` owns integer and ASCII semantics;
`lib/forge_tools_page.dart` presents them through the existing
`StudioProfile.toolsPageBuilder` navigation entry.

## Integer Semantics

- Parse signed decimal or `0x`, `0b`, `0o` prefixes with `BigInt`.
- `IntegerWord(value, width: 8|16|32|64)` accepts the signed minimum through
  the unsigned maximum, then stores a fixed-width unsigned bit pattern.
- Signed display uses two's complement. Arithmetic right shift extends the
  sign; logical right shift inserts zero. Results are masked to the word width.
- Invalid input, overflow, and shifts outside `0..width-1` throw
  `FormatException`, displayed on the corresponding input field.
- Avoid conversion through `double` or machine `int`: `18446744073709551615`
  must remain exact on every Flutter platform.

## UI And ASCII

- Each tab retains its input, width, operation, and filter state.
- Empty input produces empty results and disabled copy actions.
- Copy returns the complete value, including binary prefixes and leading zeroes.
- ASCII covers codes 0 through 127; copied C constants escape controls,
  apostrophes, and backslashes.
- Reuse Material controls and existing navigation. No sample project data.

## Verification

`test/forge_tools_test.dart` checks 64-bit precision, range endpoints, invalid
prefixes, distinct right shifts, masking, C escapes, clipboard contents, tab
state retention, and workflows without overflow at 320 and 1024 pixels.
