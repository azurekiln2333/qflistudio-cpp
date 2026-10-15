// Browser implementation: bind `package:path` to the virtual POSIX root used by
// the browser filesystem (`/qfli`), not the page's URL context.
import 'package:path/path.dart' as path;

export 'package:path/path.dart'
    show Context, Style, PathException, posix, windows, url;

// Virtual project paths share the browser filesystem's POSIX root, not page URLs.
final context = path.Context(style: path.Style.posix, current: '/qfli');
path.Style get style => context.style;
String get current => context.current;
String get separator => context.separator;
final absolute = context.absolute;
final basename = context.basename;
final basenameWithoutExtension = context.basenameWithoutExtension;
final dirname = context.dirname;
final extension = context.extension;
final rootPrefix = context.rootPrefix;
final isAbsolute = context.isAbsolute;
final isRelative = context.isRelative;
final isRootRelative = context.isRootRelative;
final join = context.join;
final joinAll = context.joinAll;
final split = context.split;
final canonicalize = context.canonicalize;
final normalize = context.normalize;
final relative = context.relative;
final isWithin = context.isWithin;
final equals = context.equals;
final hash = context.hash;
final withoutExtension = context.withoutExtension;
final setExtension = context.setExtension;
String fromUri(Object? uri) => context.fromUri(uri!);
final toUri = context.toUri;
String prettyUri(Object? uri) => context.prettyUri(uri!);
