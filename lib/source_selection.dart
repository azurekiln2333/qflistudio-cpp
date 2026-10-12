/// Pure-Dart C/C++ translation-unit selection for QFLIForge.
///
/// The runner receives the explicitly requested entry file from the editor
/// (a normal Run tap uses the configured project entry; a long press uses the
/// currently open file). Every backend used to compile *all* project source
/// units, so a project that kept two independent programs (`main.c` and
/// `main2.c`) produced `multiple definition of 'main'` whenever one of them
/// was requested.
///
/// This file owns the one rule shared by every Dart-side backend:
///
///   keep the selected entry, keep every ordinary helper unit, and drop only
///   the *other* units that contain an unambiguous top-level `main`
///   definition.
///
/// It intentionally does not import the in-app C runtime (`qfli_c_runtime`),
/// whose 64-bit integer constants cannot be represented by dart2js, so the
/// browser build graph stays valid. It is a small lexical scan, not a C
/// preprocessor: anything it cannot decide confidently is left in the source
/// set so the real compiler reports the diagnostic instead of a helper file
/// being silently deleted.
library;

/// Path extensions the C/C++ backends compile as translation units.
const Set<String> kCCppSourceExtensions = {
  '.c',
  '.cc',
  '.cpp',
  '.cxx',
};

/// Whether [path]'s extension is a C/C++ translation unit for selection.
///
/// Case is folded, so `MAIN.C` and `helper.CPP` are collected just like their
/// lowercase spellings (the compiler is invoked with an explicit `-x` mode).
bool isCCppSourcePath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return false;
  final slash = path.lastIndexOf('/');
  final backslash = path.lastIndexOf(r'\');
  if (dot < slash || dot < backslash) return false;
  return kCCppSourceExtensions.contains(path.substring(dot).toLowerCase());
}

/// Returns the source units to compile for the requested [entryFile].
///
/// [allSources] is the complete enumeration of project translation units (the
/// caller owns filesystem walking and path normalization). [readSource] reads
/// the text of one unit; when it returns null the unit is kept conservatively.
///
/// The returned list always contains exactly one element equal to [entryFile]
/// and preserves [allSources] order for the rest. A non-entry unit is excluded
/// only when it defines `main` unambiguously at the top level of its
/// translation unit; ambiguous units (conditional compilation, macro-defined
/// `main`, unreadable text) are kept.
List<String> selectRunSources({
  required String entryFile,
  required List<String> allSources,
  required String? Function(String path) readSource,
}) {
  final selected = <String>[];
  var entrySeen = false;

  for (final source in allSources) {
    if (_samePath(source, entryFile)) {
      if (!entrySeen) {
        entrySeen = true;
        selected.add(source);
      }
      continue;
    }
    if (definesUnambiguousMain(readSource(source))) continue;
    selected.add(source);
  }

  if (!entrySeen) {
    // The entry must survive even if enumeration missed it; callers validate
    // that it exists before running.
    selected.insert(0, entryFile);
  }
  return selected;
}

bool _samePath(String a, String b) {
  if (a == b) return true;
  // Normalize separators so Windows/POSIX callers agree without importing
  // package:path into this pure helper.
  return a.replaceAll(r'\', '/') == b.replaceAll(r'\', '/');
}

/// Whether [source] text contains an unambiguous top-level `main` definition.
///
/// Rules (all must hold):
///   * a `main` identifier token that is not part of a longer identifier;
///   * the token sits at global scope (brace depth zero) in the translation
///     unit, so `namespace n { int main(){} }`, a `struct`/`class` member and
///     a nested function are all *not* entries;
///   * immediately followed by `(`;
///   * not preceded by `.`, `->` or `::` (member/namespace/selector use);
///   * not produced inside a preprocessor directive line (`#define main ...`);
///   * not inside a conditional-compilation block (`#if`/`#ifdef`/`#ifndef`);
///   * not declared `static` (internal linkage is never the program entry);
///   * a global function body `{` demonstrably follows the parameter list at a
///     non-conditional position.
///
/// Anything that does not positively prove a global definition (unknown
/// macros, ambiguous preprocessing, a scan that hits EOF before the body) is
/// treated as "not an entry", i.e. the file is kept.
bool definesUnambiguousMain(String? source) {
  if (source == null) return false;
  final scan = _significantTokens(source);
  if (scan == null) return false; // Unterminated comment/string: ambiguous.
  // A `#define main ...` (or `#undef main`) renames the real entry point, so
  // the file's `main` tokens no longer mean what they look like. Keep it.
  if (scan.macroDefinesMain) return false;
  final tokens = scan.tokens;

  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.kind != _TokenKind.identifier || token.text != 'main') continue;
    if (token.inConditional || token.inDirective) continue;
    if (token.braceDepth != 0) continue; // Namespace/class/function scope.
    if (_hasInternalLinkage(tokens, i)) continue;

    final previous = i > 0 ? tokens[i - 1] : null;
    if (previous != null &&
        previous.kind == _TokenKind.punctuator &&
        (previous.text == '.' ||
            previous.text == '->' ||
            previous.text == '::')) {
      continue;
    }

    final next = i + 1 < tokens.length ? tokens[i + 1] : null;
    if (next == null ||
        next.kind != _TokenKind.punctuator ||
        next.text != '(') {
      continue;
    }

    if (_hasGlobalFunctionBody(tokens, i)) return true;
  }
  return false;
}

/// True only when the `main` at [index] is followed, at global scope, by a
/// function body `{` after its parameter list.
///
/// A prototype (`;`), a variable (`=`/`,`), a member/nested brace, or an EOF
/// before any body all return false, which keeps the unit in the build so the
/// real compiler can decide.
bool _hasGlobalFunctionBody(List<_Token> tokens, int index) {
  var depth = 0;
  var sawParameterList = false;
  for (var i = index + 1; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.kind != _TokenKind.punctuator) continue;
    // A body/declarator token chosen by, or spanning, a conditional-compilation
    // region is ambiguous: keep the file for the real compiler.
    if (token.inConditional || token.inDirective) return false;
    if (token.braceDepth > 0 && depth == 0) return false; // Entered a scope.
    switch (token.text) {
      case '(':
      case '[':
        depth++;
        sawParameterList = true;
      case ')':
      case ']':
        depth--;
      case '{':
        if (depth == 0 && sawParameterList) return true; // Global body.
        return false; // Inline member/nested body: not a global entry.
      case '}':
        return false;
      case ';':
        if (depth == 0) return false; // Prototype.
      case '=':
      case ',':
        if (depth == 0) return false; // Variable, `auto main = ...`.
    }
  }
  return false; // EOF before a body: ambiguous, keep.
}

/// Whether the declaration containing the `main` at [index] carries `static`.
///
/// `static int main(void) {...}` is internal linkage and can never be the
/// program entry, so such a unit is kept even though it looks like a global
/// function definition. The specifiers are scanned back to the previous
/// declaration boundary (`;`, `}`, `{`, or the start of the token stream).
bool _hasInternalLinkage(List<_Token> tokens, int index) {
  for (var i = index - 1; i >= 0; i--) {
    final token = tokens[i];
    if (token.kind == _TokenKind.punctuator) {
      if (token.text == ';' || token.text == '}' || token.text == '{') {
        return false;
      }
      continue;
    }
    if (token.text == 'static') return true;
  }
  return false;
}

enum _TokenKind { identifier, punctuator }

class _Token {
  const _Token(
    this.kind,
    this.text, {
    this.inDirective = false,
    this.inConditional = false,
    this.braceDepth = 0,
  });

  final _TokenKind kind;
  final String text;

  /// The token sits on a `#...` preprocessor directive line.
  final bool inDirective;

  /// The token sits inside an (open) `#if`/`#ifdef`/`#ifndef` region.
  final bool inConditional;

  /// Number of unclosed `{` before this token (0 = global scope).
  final int braceDepth;
}

/// Scans [source] into significant identifiers and punctuators.
///
/// Returns null when the scan cannot be trusted: an unterminated block
/// comment, character, normal string or raw string. Callers treat null as
/// "ambiguous: keep the file".
class _Scan {
  const _Scan(this.tokens, {required this.macroDefinesMain});
  final List<_Token> tokens;
  final bool macroDefinesMain;
}

_Scan? _significantTokens(String rawSource) {
  // C translation phase 2: backslash-newline splices happen before comment
  // recognition (phase 3). Applying this first is what keeps a `main` example
  // that straddles a `\` continuation of a `//` comment or a `#define`
  // directive on the directive/comment side instead of being read as code.
  final source = _spliceLineContinuations(rawSource);
  final tokens = <_Token>[];
  final length = source.length;
  var i = source.startsWith('\u{FEFF}') ? 1 : 0;
  var atLineStart = true;
  var inDirective = false;
  var conditionalDepth = 0;
  var braceDepth = 0;
  var macroDefinesMain = false;

  void push(_TokenKind kind, String text) {
    tokens.add(
      _Token(
        kind,
        text,
        inDirective: inDirective,
        inConditional: conditionalDepth > 0,
        braceDepth: braceDepth,
      ),
    );
  }

  while (i < length) {
    final c = source[i];

    if (c == '\n') {
      atLineStart = true;
      inDirective = false;
      i++;
      continue;
    }
    if (c == ' ' || c == '\t' || c == '\r') {
      i++;
      continue;
    }

    // Preprocessor directive line: consume the logical line (including
    // backslash continuations), tracking conditional depth so a `main` inside
    // `#if` is never treated as unambiguous. We do not expand macros; a
    // directive that could rename `main` keeps the whole file.
    if (c == '#' && atLineStart) {
      final end = _directiveEnd(source, i);
      final directive = source.substring(i, end);
      final name = _directiveName(directive);
      switch (name) {
        case 'if':
        case 'ifdef':
        case 'ifndef':
          conditionalDepth++;
        case 'endif':
          if (conditionalDepth > 0) conditionalDepth--;
        case 'define':
        case 'undef':
          if (_directiveTargetsMain(directive)) macroDefinesMain = true;
      }
      i = end;
      atLineStart = true;
      inDirective = false;
      continue;
    }
    if (c == '/' && i + 1 < length && source[i + 1] == '/') {
      final lineEnd = source.indexOf('\n', i);
      i = lineEnd < 0 ? length : lineEnd;
      continue;
    }
    if (c == '/' && i + 1 < length && source[i + 1] == '*') {
      final close = source.indexOf('*/', i + 2);
      if (close < 0) return null; // Unterminated block comment.
      i = close + 2;
      // A block comment does not end the logical line: a `#` that follows it
      // (still before any code) begins a directive line.
      continue;
    }

    // Past comments and whitespace: this is real code, so the line is no
    // longer at its start.
    atLineStart = false;

    if (c == '"' || c == '\'') {
      final end = _skipQuoted(source, i, c);
      if (end < 0) return null; // Unterminated string/char literal.
      i = end;
      continue;
    }

    // C++ raw string: optional encoding prefix + R"delim( ... )delim"
    if (_isRawStringStart(source, i)) {
      final end = _skipRawString(source, i);
      if (end < 0) return null; // Unterminated raw string.
      i = end;
      continue;
    }

    if (_isIdentStart(c)) {
      final start = i;
      i++;
      while (i < length && _isIdentPart(source[i])) {
        i++;
      }
      push(_TokenKind.identifier, source.substring(start, i));
      continue;
    }

    // Multi-character C++ selectors we care about.
    if (c == '-' && i + 1 < length && source[i + 1] == '>') {
      push(_TokenKind.punctuator, '->');
      i += 2;
      continue;
    }
    if (c == ':' && i + 1 < length && source[i + 1] == ':') {
      push(_TokenKind.punctuator, '::');
      i += 2;
      continue;
    }

    // Braces change the translation-unit scope used to reject member and
    // nested `main` definitions. The opening brace is recorded at the outer
    // depth, the closing brace at the inner depth, so a token between the
    // braces that opens a scope sits at the outer depth.
    if (c == '{') {
      push(_TokenKind.punctuator, c);
      braceDepth++;
      i++;
      continue;
    }
    if (c == '}') {
      if (braceDepth > 0) braceDepth--;
      push(_TokenKind.punctuator, c);
      i++;
      continue;
    }

    push(_TokenKind.punctuator, c);
    i++;
  }

  return _Scan(tokens, macroDefinesMain: macroDefinesMain);
}

/// C translation phase 2: delete every backslash immediately followed by a
/// newline (`\n`, `\r\n` or `\r`).
///
/// This must run before comment/directive scanning, because a splice can join a
/// following line into a `//` comment or into a `#define` body.
String _spliceLineContinuations(String source) {
  if (!source.contains(r'\')) return source;
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (source[i] == r'\' && i + 1 < source.length) {
      final next = source[i + 1];
      if (next == '\n') {
        i += 2;
        continue;
      }
      if (next == '\r') {
        if (i + 2 < source.length && source[i + 2] == '\n') {
          i += 3;
        } else {
          i += 2;
        }
        continue;
      }
    }
    out.write(source[i]);
    i++;
  }
  return out.toString();
}

/// Index just past a preprocessor directive, spanning backslash-newline
/// continuations. A directive ends at the first newline not preceded by `\`.
/// (Run after splicing; this stays as defense for callers that pass raw text.)
int _directiveEnd(String source, int start) {
  var i = start;
  while (i < source.length) {
    final newline = source.indexOf('\n', i);
    if (newline < 0) return source.length;
    var backslashes = 0;
    var j = newline - 1;
    while (j >= start && source[j] == r'\') {
      backslashes++;
      j--;
    }
    if (backslashes.isEven) return newline;
    i = newline + 1;
  }
  return source.length;
}

/// Whether a `#define`/`#undef` directive names `main`.
///
/// Continuations are already spliced away by [_spliceLineContinuations], and
/// comments are stripped here because C allows them between the directive name
/// and the macro name (`#define /* name */ main qfli_main`). This does not
/// expand macros; it only checks the directive's own name.
bool _directiveTargetsMain(String directive) {
  final withoutComments = _stripComments(directive);
  return RegExp(r'^\s*#\s*(?:define|undef)\s+main\b').hasMatch(withoutComments);
}

/// Removes `/* ... */` and `// ...` comment text from one logical line.
String _stripComments(String text) {
  final out = StringBuffer();
  var i = 0;
  while (i < text.length) {
    if (text[i] == '/' && i + 1 < text.length && text[i + 1] == '*') {
      final close = text.indexOf('*/', i + 2);
      if (close < 0) {
        out.write(' ');
        break;
      }
      out.write(' ');
      i = close + 2;
      continue;
    }
    if (text[i] == '/' && i + 1 < text.length && text[i + 1] == '/') {
      break;
    }
    out.write(text[i]);
    i++;
  }
  return out.toString();
}

String _directiveName(String directive) {
  var i = 1;
  while (i < directive.length && directive[i].trim().isEmpty) {
    i++;
  }
  final rest = directive.substring(i).trimLeft();
  final match = RegExp(r'^[A-Za-z]+').firstMatch(rest);
  return match?.group(0) ?? '';
}

bool _isRawStringStart(String source, int index) {
  // Bare R", or an encoding prefix directly before it: u8R", uR", UR", LR".
  if (source[index] == 'R') {
    return index + 1 < source.length && source[index + 1] == '"';
  }
  if (source[index] == 'u' &&
      index + 2 < source.length &&
      source[index + 1] == '8' &&
      source[index + 2] == 'R') {
    return index + 3 < source.length && source[index + 3] == '"';
  }
  if ((source[index] == 'u' ||
          source[index] == 'U' ||
          source[index] == 'L') &&
      index + 1 < source.length &&
      source[index + 1] == 'R') {
    return index + 2 < source.length && source[index + 2] == '"';
  }
  return false;
}

/// Returns the index just past a C++ raw string starting at [index] (which
/// points at the `R` or its encoding prefix), or -1 when unterminated.
int _skipRawString(String source, int index) {
  var i = index;
  while (i < source.length && source[i] != 'R') {
    i++;
  }
  i++; // Past `R`.
  if (i >= source.length || source[i] != '"') return -1;
  i++;
  final delimiterStart = i;
  final openParen = source.indexOf('(', i);
  if (openParen < 0 || openParen - delimiterStart > 16) return -1;
  final delimiter = source.substring(delimiterStart, openParen);
  final terminator = ')$delimiter"';
  final close = source.indexOf(terminator, openParen + 1);
  if (close < 0) return -1;
  return close + terminator.length;
}

/// Returns the index just past a quoted literal starting at [index], or -1.
int _skipQuoted(String source, int index, String quote) {
  var i = index + 1;
  while (i < source.length) {
    final c = source[i];
    if (c == r'\') {
      i += 2;
      continue;
    }
    if (c == quote) return i + 1;
    if (c == '\n') return -1; // Newline inside a normal literal is invalid.
    i++;
  }
  return -1;
}

bool _isIdentStart(String c) =>
    c.isNotEmpty && (RegExp(r'[A-Za-z_$]').hasMatch(c));

bool _isIdentPart(String c) =>
    c.isNotEmpty && (RegExp(r'[A-Za-z0-9_$]').hasMatch(c));
