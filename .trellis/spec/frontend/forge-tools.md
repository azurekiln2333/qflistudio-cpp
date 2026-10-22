# Forge Tools Contract

## Scope

`lib/forge_integer_tools.dart` owns integer and ASCII semantics.
`lib/forge_development_tools.dart` owns strict C byte-literal conversion and
explicit target type/struct layouts. These functions have no Flutter, compiler,
network, filesystem or external dependency requirements.

`lib/forge_tools_page.dart` exposes `ForgeToolsBody({VoidCallback?
onOpenTerminal})` through `StudioProfile.toolsTabBuilder`. This is embeddable
scroll content; the host supplies the Scaffold and navigation. Do not use
`toolsPageBuilder` for Forge: that introduces a feature card and a secondary
route instead of the required direct tools. `ForgeToolsPage` is a legacy
standalone Scaffold/AppBar wrapper around the same body.

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

## Direct UI And ASCII

- Show all five usable sections directly: integer conversion, bit operations,
  UTF-8/C literals, target type/struct layout, and ASCII. No tool tabs, collapsed
  feature cards or secondary tool pages.
- Use a single outer scroll area. A responsive Wrap changes from one to two
  columns only when width and text scale permit it; keep each tool in the same
  element position so its controllers and selections survive resizing/rebuilds.
- Keep the ASCII results at a bounded 280 logical pixels with an independent
  non-primary list/controller. All 128 codes remain searchable and scrollable.
  Changing search/filter resets the list offset before showing the new result.
- Empty integer/type/layout input produces empty results and disabled copy
  actions. Encoding empty text is valid and returns `""`; literal decoding must
  explicitly receive a quoted string, including `""` for zero bytes.
- Copy returns the complete value, including binary prefixes and leading zeroes.
- ASCII covers codes 0 through 127; copied C constants escape controls,
  apostrophes, and backslashes.
- Render the actual terminal callback as a direct button only when provided by
  the host. Do not substitute a decorative terminal or fake backend.
- Reuse Material controls and existing navigation. No sample project data.

## C Byte Literals And UTF-8

- Validate UTF-16 input before UTF-8 encoding; reject unpaired surrogates rather
  than silently replacing them. Count/copy bytes without an implicit C NUL.
- Readable encoding preserves printable ASCII and standard simple escapes,
  using exactly three octal digits for other bytes. Escape question marks to
  avoid C17 trigraph preprocessing. Hexadecimal encoding escapes every byte;
  it must never append an unescaped hexadecimal digit to an existing `\\x` escape.
- Decode only ordinary narrow double-quoted literals, with optional whitespace
  and adjacent-literal concatenation. Reject malformed quotes, raw controls,
  macros/comments, prefixes, Unicode escapes, line splicing and source
  trigraphs. This is an explicit subset, not a general C preprocessor/parser.
- Octal consumes one through three digits. Hexadecimal consumes every following
  hexadecimal digit, even when more than two digits were supplied. Reject
  numeric values above 255 instead of truncating; explain adjacent literals as
  the way to terminate a hexadecimal escape before a hexadecimal character.
- Keep valid decoded bytes even if they are invalid UTF-8; disable decoded-text
  copy and show the UTF-8 error while allowing raw-byte copying. Never decode
  with replacement characters.

## Explicit Target Layouts

- Default to **wasm32-WASI ILP32**, which is the packaged OHOS interpreter target,
  not the phone's native ARM64 ABI. `int`, `long`, pointers, `size_t` and
  `ptrdiff_t` are 4 bytes; `long long`/`double` are 8 with alignment 8;
  `long double` has size/alignment 16.
- The other selection is explicitly **x86_64 System V LP64**. `long` and
  pointer-sized types are 8 bytes; `int` remains 4; `long double` has
  size/alignment 16. This does not describe Windows LLP64, another architecture,
  packed/custom layouts or every platform called LP64.
- Support listed scalar/fixed-width types, scalar pointers (including
  const/volatile qualifiers), and one member declaration per line with optional
  fixed multidimensional arrays. Array counts follow C decimal, leading-zero
  octal or `0x` hexadecimal spelling; reject malformed counts, zero/flexible
  arrays, expressions, unsupported declarations, keywords and duplicate names.
- Use BigInt for counts, sizes, offsets and padding. Arrays multiply element
  size and retain element alignment. Align each member upward, use maximum
  member alignment for the struct, and align total size to include tail padding.
- Bound arrays, cumulative members and final tail padding by target
  `PTRDIFF_MAX` as an explicit conservative calculator limit. Check after every
  multiplication/addition/alignment; do not silently overflow or allocate
  storage proportional to a declared array's element count.
- Reject unsupported packing, bitfields, unions, nested records, empty structs,
  function pointers and C++ object-layout features rather than guessing.

## Verification

`test/forge_tools_test.dart` checks 64-bit precision, range endpoints, invalid
prefixes, shifts/masking, ASCII C constants, disabled invalid-result copies,
real clipboard contents, direct host embedding/terminal callback, bounded ASCII
scrolling/filtering and state retention when resizing. Run workflows at 320 and
1024 pixels with normal and 2x text scale.

`test/forge_development_tools_test.dart` checks all 256 byte values in all three
encodings, UTF-8/NUL/emoji, greedy hex and bounded octal escapes, adjacent
literals, malformed inputs/trigraphs/surrogates, invalid UTF-8 preservation,
both target layouts, member/tail padding, multidimensional/C-spelled arrays,
precision beyond JavaScript's integer range, unsupported grammar and overflow.

Use scoped analysis and focused tests (`--concurrency=1` on constrained hosts).
ABI/text research sources and review evidence live in the active task's
`research/forge-tools-20261022.md`. These checks prove calculator/UI semantics;
they do not substitute for packaged compiler or actual OHOS-device execution.
