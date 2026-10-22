# Direct offline C/C++ tools — 2026-10-22

## Ownership and integration

Implementation ownership is limited to `lib/forge_tools_page.dart`,
`lib/forge_development_tools.dart`, `test/forge_tools_test.dart`,
`test/forge_development_tools_test.dart`, this research file, and the subsequently
authorized `.trellis/spec/frontend/forge-tools.md` update. Root owns
`main.dart`, runtime/compiler work, generated content, shared core, commits and
pushes. No other product files were edited by this worker.

`ForgeToolsBody({VoidCallback? onOpenTerminal})` supplies the direct scroll body
to the root's `forgeProfile.toolsTabBuilder`. Using `toolsPageBuilder` would
continue showing the shared core's secondary feature card, so the root changed
that integration. The legacy `ForgeToolsPage` only wraps the same body in a
Scaffold/AppBar. The real terminal callback is an optional direct action.

All five sections are usable without navigation: integer conversion, bit
operations, UTF-8/C strings, target type/struct layout, and ASCII. Wrap preserves
element order while changing width; there are no collapsed sections or tool
tabs. The ASCII list alone has a bounded 280-pixel scroll viewport.

## Official primary research

Retrieved and inspected online on 2026-10-22. Browser search/open was attempted;
official source contents were additionally fetched directly over HTTPS with
Python's standard library (and PyMuPDF only to extract WG14 PDF text). These
requests are development research, not app functionality; no networking code
or dependency was added to the app.

1. Microsoft, [C/C++ for Visual Studio Code](https://code.visualstudio.com/docs/languages/cpp).
   The C/C++ extension contributes highlighting, completions and error checking,
   but relies on actual compiler/debugger tools. This supports maintaining real
   compiler-backed IDE capabilities separately from deterministic offline
   calculators; it does not justify fake debug controls.
2. JetBrains, [CLion Memory View](https://www.jetbrains.com/help/clion/memory-view.html).
   Memory View displays actual running-process bytes, addresses and ASCII, and
   relies on a debug session. Inspired useful byte/ASCII representations here;
   these tools are explicitly conversions/layout calculations, not a simulated
   memory inspector.
3. WG14 [N1570 C11 committee draft](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf),
   sections 5.1.1.2, 6.4.4.1, 6.4.4.4 and 6.4.5. The inspected text confirms
   numeric escape maximal consumption and unsigned-char representability,
   three-digit octal termination versus hexadecimal continuation, and adjacent
   string concatenation. These stable C escape rules also apply to the C17
   toolchain targeted by the app. Array integer spelling must distinguish
   leading-zero octal from decimal; `010` cannot be interpreted as ten.
4. WebAssembly tool conventions,
   [Basic C ABI](https://github.com/WebAssembly/tool-conventions/blob/main/BasicCABI.md)
   ([raw source](https://raw.githubusercontent.com/WebAssembly/tool-conventions/main/BasicCABI.md)).
   wasm32 uses ILP32. The scalar table specifies 4-byte long/pointers,
   8-byte double/long-long alignment, and 16-byte long-double size/alignment
   (distinct from Emscripten's long-double alignment). Struct member offsets
   round upward to member alignment; aggregate alignment is the strictest
   member's; total size rounds to aggregate alignment. An array member retains
   element alignment. The separate rule raising alignment of large local/global
   array variables does not raise a char-array member's alignment.
5. LLVM 22.1.0 Clang target definitions,
   [WebAssembly.h](https://github.com/llvm/llvm-project/blob/llvmorg-22.1.0/clang/lib/Basic/Targets/WebAssembly.h)
   and [X86.h](https://github.com/llvm/llvm-project/blob/llvmorg-22.1.0/clang/lib/Basic/Targets/X86.h).
   The WebAssembly target sets long-double width/alignment to 128 bits. The
   non-x32 X86_64 target sets long/pointer width/alignment to 64 bits,
   long-double storage/alignment to 128 bits, and size/ptrdiff/intptr types to
   unsigned/signed long. Windows overrides and wasm64/WALI are not the selected
   calculator models.

## Semantic decisions and concrete review findings

- Text is validated for paired UTF-16 surrogates before UTF-8 encoding.
  Readable C encoding uses simple escapes plus fixed three-digit octal bytes;
  all-hex and all-octal modes encode every byte. All 256 byte values round-trip
  in each mode. Question marks are escaped to avoid C17 preprocessing trigraphs.
- Literal decoding deliberately accepts a strict subset: ordinary narrow quoted
  strings, whitespace concatenation, simple escapes, up to three octal digits,
  and maximal hexadecimal digits. Prefixes, comments/macros, Unicode escapes,
  preprocessing, line splicing, malformed source and >255 numeric values are
  rejected. This subset is explained directly beside the input.
- Review found that checking trigraphs only while consuming ordinary characters
  misses a raw `??/` sequence whose first question mark has just been consumed
  as an apparent escape. Validation now scans the original source before
  parsing, matching C17's preprocessing order. A regression case covers it.
- Invalid UTF-8 never becomes replacement text. Users can copy the actual
  decoded byte list; decoded-text copy remains disabled. Explicit NUL bytes
  remain present, and the implicit C terminator is excluded from counts.
- Layout uses explicit WASI32 ILP32 and x86_64 System V LP64 targets. It never
  infers the guest ABI from the physical phone or host OS. Standard scalar and
  pointer types, const/volatile qualifiers, and fixed multidimensional array
  members are supported. Packing/bitfields/unions/nesting/C++ inheritance are
  rejected, not guessed.
- Review found pointer spelling could previously be accepted after indiscriminate
  asterisk removal (`unsigned*int`). Pointer suffixes now have a constrained
  grammar; C/C++ keyword member names are rejected as well.
- Review found decimal-only array parsing would incorrectly accept `010` as ten.
  Array counts now honor decimal, octal and hexadecimal C spelling; invalid
  octal (`08`), zero arrays, expressions and oversized products are rejected.
- Counts, sizes and offsets use BigInt. Each multiplication, member addition and
  final alignment is checked against an explicitly documented conservative
  `PTRDIFF_MAX` calculator limit. This is a chosen bound, not a claim that every
  C implementation has that exact universal object-size maximum.
- UI tests use actual IconButton predicates because this Flutter SDK's
  `find.byTooltip` returns RawTooltip rather than the IconButton itself.

## Verification

- Initial new pure semantic tests: 11 passed; the first widget pass exposed only
  a test-finder type assumption, corrected without changing product behavior.
- First complete focused run: 22 tests passed, covering both widths and both
  text scales. Root then verified 23 tests after direct body/terminal embedding.
- Final review adds C-spelled array dimensions, pointer/keyword grammar and
  source-level trigraph regression coverage. Final focused run exited 0:
  **24 tests passed** (`00:08 +24: All tests passed!`). All four real UI
  workflows passed at 320/1024 widths and 1x/2x text scale, including clipboard,
  errors, bounded ASCII scrolling, resizing and control state retention.
- Scoped analysis command:
  `dart analyze lib/forge_tools_page.dart lib/forge_development_tools.dart test/forge_tools_test.dart test/forge_development_tools_test.dart`
  returned **No issues found** after the review fixes.
- Focused check command:
  `flutter test --no-pub --concurrency=1 test/forge_development_tools_test.dart test/forge_tools_test.dart --reporter expanded`.
  No full Flutter suite was started by this worker.
- Scoped `git diff --check` passed. Git emitted only the repository's normal
  LF-to-CRLF conversion notices; no whitespace errors were reported.
- These are offline calculator/UI tests. They do not establish packaged
  toolchain execution or phone execution; the root's R1/R2/R8 audits retain
  those independent gates.
