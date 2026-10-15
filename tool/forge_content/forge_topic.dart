/// QFLIForge C/C++ tutorial/example content: the authored source of truth.
///
/// This file is data only (no `dart:io`). `tool/generate_forge_content.dart`
/// reads [forgeTopics] and emits the C/C++ rows into the app's staged content
/// assets; `tool/verify_forge_content.dart` cross-checks and executes every
/// sample on a genuine native compiler.
///
/// Contract for both language tracks:
/// - `id` is stable and unique across the whole curriculum (C 1..100,
///   C++ 1..100). Ids render as `c-tutorial-0NN` / `cpp-tutorial-0NN` and the
///   paired `c-example-0NN` / `cpp-example-0NN`.
/// - `code` is a complete, runnable program (multi-line, no placeholder
///   padding). `output` is the exact stdout the program prints, normalized by
///   the verifier (`\r\n -> \n`, trailing-newline rule applied uniformly).
/// - `standard` is the language standard actually used to compile the paired
///   example on the verification toolchain. Runnable samples stay within the
///   packaged app's maximum: C <= `c17` and C++ <= `c++20`. A `c++23`-only
///   feature may be discussed in `explain` but must not be required by the
///   paired runnable sample, because the app cannot compile it end to end.
/// - Multi-file teaching stays inside **one self-contained example**: the
///   `code` must compile and run on its own. The schema has no extra-file field
///   and no hidden/verifier-only files are created, so a modular-decomposition
///   lesson demonstrates structure with a single runnable program plus an
///   explanatory file layout in `explain` (e.g. showing how the functions would
///   be split across `main.c` / `utils.h`), never by `#include`-ing a file the
///   app would have to invent.
library;

/// One authored topic: a tutorial lesson plus its paired runnable example.
class ForgeTopic {
  const ForgeTopic({
    required this.id,
    required this.language,
    required this.level,
    required this.title,
    required this.summary,
    required this.concepts,
    required this.objective,
    required this.explain,
    required this.code,
    required this.output,
    required this.standard,
    this.pitfalls = const <String>[],
    this.prerequisites = const <String>[],
    this.input,
    this.portableOutput,
    this.tasks = const <ForgeTask>[],
  });

  /// Stable numeric id within its language, 1..100.
  final int id;

  /// `c` or `cpp`.
  final String language;

  /// `beginner` | `intermediate` | `advanced`.
  final String level;

  final String title;
  final String summary;
  final List<String> concepts;
  final String objective;

  /// Substantive Chinese prose explaining this topic's specific concepts.
  final String explain;

  /// Complete, runnable, multi-line program.
  final String code;

  /// Exact stdout the program prints (normalized by the verifier).
  final String output;

  /// Target-dependent output for WASI errno values and platform macros.
  final String? portableOutput;

  /// Standard used to compile the paired example (`c17`, `c++20`, ...).
  final String standard;

  /// Common mistakes and correctness notes for this topic.
  final List<String> pitfalls;

  /// Prior topics/concepts this lesson assumes.
  final List<String> prerequisites;

  /// Optional stdin fed as the project's `input.txt`.
  final String? input;

  final List<ForgeTask> tasks;

  bool get isC => language == 'c';

  /// Zero-padded numeric component, e.g. `001`.
  String get paddedId => id.toString().padLeft(3, '0');

  String get tutorialId => '$language-tutorial-$paddedId';

  String get exampleId => '$language-example-$paddedId';
}

/// A practice prompt attached to a lesson.
class ForgeTask {
  const ForgeTask({
    required this.prompt,
    required this.hint,
    required this.answer,
  });

  final String prompt;
  final String hint;
  final String answer;
}
