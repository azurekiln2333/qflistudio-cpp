#import "NativeCompilerBridge.h"

#include <atomic>
#include <cerrno>
#include <cstring>
#include <exception>
#include <fcntl.h>
#include <initializer_list>
#include <mutex>
#include <sys/stat.h>
#include <unistd.h>
#include <vector>

#ifndef QFLI_PORTABLE_RUNTIME
#define QFLI_PORTABLE_RUNTIME 0
#endif

#if QFLI_PORTABLE_RUNTIME
#include "../../native/compiler/include/qfli_compiler.h"
#include "../../native/portable/include/qfli_wasm.h"
#endif

@interface QFLINativeRun : NSObject {
  std::atomic<bool> _cancelled;
#if QFLI_PORTABLE_RUNTIME
  std::mutex _sessionLock;
  qfli_compiler_session *_compiler;
  qfli_wasm_session *_runtime;
#endif
}
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *projectPath;
@property(nonatomic, copy) NSString *entryPath;
@property(nonatomic, copy) NSArray<NSString *> *requestedSources;
@property(nonatomic, copy) NSString *sdkPath;
@property(nonatomic) NSUInteger listenerGeneration;
- (BOOL)isCancelled;
- (void)cancel;
- (int)executeWithPipeQueue:(dispatch_queue_t)queue
                     emit:(void (^)(NSString *, NSString *))emit;
@end

#if QFLI_PORTABLE_RUNTIME
static NSString *QFLIError(NSString *operation) {
  return [NSString stringWithFormat:@"%@: %s", operation, strerror(errno)];
}

static BOOL QFLIRegularFile(NSString *path) {
  struct stat info;
  return stat(path.fileSystemRepresentation, &info) == 0 && S_ISREG(info.st_mode);
}
#endif

static NSString *QFLISdkPath(void) {
#if QFLI_PORTABLE_RUNTIME
  NSString *sdk = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"forge-wasi-sdk"];
  NSArray<NSString *> *required = @[
    @"toolchain.json", @"share/wasi-sysroot/include/wasm32-wasip1/stdio.h",
    @"share/wasi-sysroot/include/wasm32-wasip1/eh/c++/v1/vector",
    @"share/wasi-sysroot/lib/wasm32-wasip1/libc.a",
    @"share/wasi-sysroot/lib/wasm32-wasip1/eh/libc++.a",
    @"share/wasi-sysroot/lib/wasm32-wasip1/eh/libc++abi.a",
    @"share/wasi-sysroot/lib/wasm32-wasip1/eh/libunwind.a",
    @"lib/clang/22/include/stddef.h",
    @"lib/clang/22/lib/wasm32-unknown-wasip1/libclang_rt.builtins.a",
  ];
  for (NSString *relative in required) {
    if (!QFLIRegularFile([sdk stringByAppendingPathComponent:relative])) return nil;
  }
  NSData *data = [NSData dataWithContentsOfFile:[sdk stringByAppendingPathComponent:@"toolchain.json"]];
  id manifest = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nullptr] : nil;
  if (![manifest isKindOfClass:NSDictionary.class] ||
      ![manifest[@"format"] isEqual:@1] || ![manifest[@"wasiSdkVersion"] isEqual:@"33.0"] ||
      ![manifest[@"execution"] isEqual:@"interpreter"] || ![manifest[@"jit"] isEqual:@NO]) return nil;
  return sdk;
#else
  return nil;
#endif
}

// Keep UTF-8 sequences together until a complete line (including empty lines).
#if QFLI_PORTABLE_RUNTIME
static void QFLIReadPipe(int fd, QFLINativeRun *run, NSString *kind,
                         void (^emit)(NSString *, NSString *)) {
  NSMutableData *pending = [NSMutableData data];
  unsigned char buffer[8192];
  while (true) {
    ssize_t size = read(fd, buffer, sizeof(buffer));
    if (size < 0 && errno == EINTR) continue;
    if (size < 0) {
      emit(@"stderr", QFLIError(@"Cannot read program output"));
      [run cancel];
      break;
    }
    if (!size) break;
    @autoreleasepool {
      NSUInteger scanStart = pending.length;
      [pending appendBytes:buffer length:(NSUInteger)size];
      NSUInteger consumed = 0;
      const unsigned char *bytes = (const unsigned char *)pending.bytes;
      for (NSUInteger index = scanStart; index < pending.length; ++index) {
        if (bytes[index] != '\n') continue;
        NSUInteger length = index - consumed;
        if (length && bytes[index - 1] == '\r') --length;
        NSData *line = [NSData dataWithBytes:bytes + consumed length:length];
        NSString *text = [[NSString alloc] initWithData:line encoding:NSUTF8StringEncoding];
        emit(kind, text ?: [[NSString alloc] initWithData:line encoding:NSISOLatin1StringEncoding]);
        consumed = index + 1;
      }
      if (consumed) [pending replaceBytesInRange:NSMakeRange(0, consumed) withBytes:NULL length:0];
    }
  }
  if (pending.length) {
    NSString *text = [[NSString alloc] initWithData:pending encoding:NSUTF8StringEncoding];
    emit(kind, text ?: [[NSString alloc] initWithData:pending encoding:NSISOLatin1StringEncoding]);
  }
  close(fd);
}
#endif

@implementation QFLINativeRun
- (instancetype)init {
  self = [super init];
  if (self) {
    _cancelled.store(false);
#if QFLI_PORTABLE_RUNTIME
    _compiler = nullptr;
    _runtime = nullptr;
#endif
  }
  return self;
}

- (BOOL)isCancelled { return _cancelled.load(); }

- (void)cancel {
  _cancelled.store(true);
#if QFLI_PORTABLE_RUNTIME
  std::lock_guard<std::mutex> lock(_sessionLock);
  qfli_compiler_cancel(_compiler);
  qfli_wasm_cancel(_runtime);
#endif
}

/// Translation units to compile.
///
/// An explicit `requestedSources` list from Dart is authoritative: it already
/// selected the requested entry plus ordinary helpers and excluded other
/// unambiguous main programs. Each entry must be a project-local readable
/// C/C++ source; a bad list is an error, never a silent fall back to
/// re-enumerating every file (which could compile a different program's
/// main). Without a list, legacy discovery is kept for older callers.
- (NSArray<NSString *> *)selectSources:(NSURL *)root error:(NSError **)error {
  if (!self.requestedSources) return [self collectSources:root error:error];
  if (!self.requestedSources.count) {
    if (error) {
      *error = [NSError errorWithDomain:@"qfli" code:1 userInfo:@{
        NSLocalizedDescriptionKey: @"The selected source list is empty."
      }];
    }
    return nil;
  }
  NSFileManager *files = NSFileManager.defaultManager;
  NSSet *extensions = [NSSet setWithArray:@[@"c", @"cpp", @"cc", @"cxx"]];
  NSMutableArray<NSString *> *resolved = [NSMutableArray array];
  for (NSString *path in self.requestedSources) {
    if (![path isKindOfClass:NSString.class]) return nil;
    NSString *standard = [[NSURL fileURLWithPath:path] URLByResolvingSymlinksInPath].URLByStandardizingPath.path;
    BOOL local = [standard hasPrefix:[root.path stringByAppendingString:@"/"]];
    BOOL source = [extensions containsObject:standard.pathExtension.lowercaseString];
    // Foundation check so this method compiles with or without the portable
    // runtime (QFLIRegularFile only exists under QFLI_PORTABLE_RUNTIME).
    BOOL directory = YES;
    BOOL readable = [files fileExistsAtPath:standard isDirectory:&directory] && !directory;
    if (!local || !source || !readable) {
      if (error) {
        *error = [NSError errorWithDomain:@"qfli" code:1 userInfo:@{
          NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Selected source is not a project translation unit: %@", path]
        }];
      }
      return nil;
    }
    [resolved addObject:standard];
  }
  NSString *entryStandard = [[NSURL fileURLWithPath:self.entryPath] URLByResolvingSymlinksInPath].URLByStandardizingPath.path;
  if (![resolved containsObject:entryStandard]) {
    if (error) {
      *error = [NSError errorWithDomain:@"qfli" code:1 userInfo:@{
        NSLocalizedDescriptionKey: @"The selected sources do not include the entry file."
      }];
    }
    return nil;
  }
  // Entry first, then helpers in their given order.
  NSMutableArray<NSString *> *ordered = [NSMutableArray arrayWithObject:entryStandard];
  for (NSString *path in resolved) {
    if (![path isEqualToString:entryStandard]) [ordered addObject:path];
  }
  return ordered;
}

- (NSArray<NSString *> *)collectSources:(NSURL *)root error:(NSError **)error {
  NSFileManager *files = NSFileManager.defaultManager;
  __block NSError *failure = nil;
  NSArray *keys = @[NSURLIsDirectoryKey, NSURLIsRegularFileKey, NSURLIsSymbolicLinkKey];
  NSDirectoryEnumerator<NSURL *> *walker = [files enumeratorAtURL:root
      includingPropertiesForKeys:keys options:NSDirectoryEnumerationSkipsHiddenFiles
      errorHandler:^BOOL(NSURL *url, NSError *problem) { failure = problem; return NO; }];
  NSMutableArray<NSString *> *sources = [NSMutableArray array];
  NSSet *extensions = [NSSet setWithArray:@[@"c", @"cpp", @"cc", @"cxx"]];
  for (NSURL *url in walker) {
    if (self.isCancelled) break;
    NSDictionary *values = [url resourceValuesForKeys:keys error:&failure];
    if (!values) break;
    if ([values[NSURLIsSymbolicLinkKey] boolValue]) { [walker skipDescendants]; continue; }
    if ([values[NSURLIsDirectoryKey] boolValue]) {
      if ([@[@"build", @"node_modules"] containsObject:url.lastPathComponent]) [walker skipDescendants];
    } else if ([values[NSURLIsRegularFileKey] boolValue] &&
               [extensions containsObject:url.pathExtension.lowercaseString]) {
      [sources addObject:url.path];
    }
  }
  if (error) *error = failure;
  return failure ? nil : [sources sortedArrayUsingSelector:@selector(compare:)];
}

- (int)executeWithPipeQueue:(dispatch_queue_t)queue
                     emit:(void (^)(NSString *, NSString *))emit {
#if QFLI_PORTABLE_RUNTIME
  if (self.isCancelled) return 130;
  NSFileManager *files = NSFileManager.defaultManager;
  NSURL *root = [[NSURL fileURLWithPath:self.projectPath] URLByResolvingSymlinksInPath].URLByStandardizingPath;
  NSURL *entry = [[NSURL fileURLWithPath:self.entryPath] URLByResolvingSymlinksInPath].URLByStandardizingPath;
  BOOL directory = NO;
  if (![files fileExistsAtPath:root.path isDirectory:&directory] || !directory ||
      ![entry.path hasPrefix:[root.path stringByAppendingString:@"/"]] || !QFLIRegularFile(entry.path)) {
    emit(@"stderr", @"The project or entry file is not readable.");
    return 127;
  }
  NSError *error = nil;
  NSArray<NSString *> *sources = [self selectSources:root error:&error];
  if (self.isCancelled) return 130;
  if (!sources.count || ![sources containsObject:entry.path]) {
    emit(@"stderr", error.localizedDescription ?: @"The project has no readable C/C++ entry source.");
    return 127;
  }
  NSString *work = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"forge-runs"]
                    stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
  if (![files createDirectoryAtPath:work withIntermediateDirectories:YES attributes:nil error:&error]) {
    emit(@"stderr", error.localizedDescription);
    return 127;
  }
  int output[2] = {-1, -1}, errors[2] = {-1, -1};
  if (pipe(output) || pipe(errors) ||
      fcntl(output[1], F_SETNOSIGPIPE, 1) || fcntl(errors[1], F_SETNOSIGPIPE, 1)) {
    emit(@"stderr", QFLIError(@"Cannot open program output pipes"));
    for (int fd : {output[0], output[1], errors[0], errors[1]}) if (fd >= 0) close(fd);
    [files removeItemAtPath:work error:nullptr];
    return 127;
  }
  dispatch_group_t readers = dispatch_group_create();
  int outputRead = output[0], errorRead = errors[0];
  dispatch_group_async(readers, queue, ^{ QFLIReadPipe(outputRead, self, @"stdout", emit); });
  dispatch_group_async(readers, queue, ^{ QFLIReadPipe(errorRead, self, @"stderr", emit); });
  int input = -1;
  int code = 127;
  try {
    {
      std::lock_guard<std::mutex> lock(_sessionLock);
      _compiler = qfli_compiler_create();
      if (_cancelled.load()) qfli_compiler_cancel(_compiler);
    }
    if (_compiler) {
      std::vector<const char *> paths;
      for (NSString *source in sources) paths.push_back(source.fileSystemRepresentation);
      code = qfli_compiler_compile(_compiler, self.sdkPath.fileSystemRepresentation,
          root.path.fileSystemRepresentation, work.fileSystemRepresentation,
          paths.data(), paths.size(), errors[1]);
    } else emit(@"stderr", @"Cannot create a native compiler session.");
    {
      std::lock_guard<std::mutex> lock(_sessionLock);
      qfli_compiler_destroy(_compiler);
      _compiler = nullptr;
    }
    if (code == 0 && !self.isCancelled) {
      NSString *inputPath = [root.path stringByAppendingPathComponent:@"input.txt"];
      input = open(inputPath.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
      BOOL missingInput = input < 0 && errno == ENOENT;
      if (missingInput) input = open("/dev/null", O_RDONLY);
      struct stat inputInfo;
      BOOL validInput = input >= 0 && fstat(input, &inputInfo) == 0 &&
                       (S_ISREG(inputInfo.st_mode) || (missingInput && S_ISCHR(inputInfo.st_mode)));
      if (!validInput) {
        emit(@"stderr", @"input.txt must be a readable regular file.");
        code = 127;
      } else {
        {
          std::lock_guard<std::mutex> lock(_sessionLock);
          _runtime = qfli_wasm_create();
          if (_cancelled.load()) qfli_wasm_cancel(_runtime);
        }
        if (_runtime) {
          code = qfli_wasm_run(_runtime,
              [work stringByAppendingPathComponent:@"program.wasm"].fileSystemRepresentation,
              root.path.fileSystemRepresentation, input, output[1], errors[1], 0);
          const char *message = qfli_wasm_error(_runtime);
          if (*message && !self.isCancelled) emit(@"stderr", [NSString stringWithUTF8String:message]);
        } else {
          emit(@"stderr", @"Cannot create a native Wasm interpreter session.");
          code = 127;
        }
      }
    }
  } catch (const std::exception &problem) {
    emit(@"stderr", [NSString stringWithUTF8String:problem.what()]);
    code = 127;
  } catch (...) {
    emit(@"stderr", @"Unknown native compiler/runtime error.");
    code = 127;
  }
  {
    std::lock_guard<std::mutex> lock(_sessionLock);
    qfli_compiler_destroy(_compiler);
    _compiler = nullptr;
    qfli_wasm_destroy(_runtime);
    _runtime = nullptr;
  }
  if (input >= 0) close(input);
  close(output[1]);
  close(errors[1]);
  dispatch_group_wait(readers, DISPATCH_TIME_FOREVER);
  [files removeItemAtPath:work error:nullptr];
  return self.isCancelled ? 130 : code;
#else
  return 127;
#endif
}
@end

@interface NativeCompilerBridge ()
@property(nonatomic, strong) FlutterEventChannel *events;
@property(nonatomic, copy) FlutterEventSink sink;
@property(nonatomic, strong) QFLINativeRun *active;
@property(nonatomic) NSUInteger listenerGeneration;
@property(nonatomic, strong) dispatch_queue_t worker;
@property(nonatomic, strong) dispatch_queue_t pipes;
- (void)emitForRun:(QFLINativeRun *)run kind:(NSString *)kind key:(NSString *)key value:(id)value;
@end

@implementation NativeCompilerBridge
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  NativeCompilerBridge *bridge = [[self alloc] init];
  bridge.worker = dispatch_queue_create("com.azurekiln.forge.compiler", DISPATCH_QUEUE_SERIAL);
  bridge.pipes = dispatch_queue_create("com.azurekiln.forge.output", DISPATCH_QUEUE_CONCURRENT);
  FlutterMethodChannel *methods = [FlutterMethodChannel methodChannelWithName:@"qfli_forge/native"
      binaryMessenger:registrar.messenger];
  bridge.events = [FlutterEventChannel eventChannelWithName:@"qfli_forge/native/events"
      binaryMessenger:registrar.messenger];
  [bridge.events setStreamHandler:bridge];
  [registrar addMethodCallDelegate:bridge channel:methods];
  [registrar publish:bridge];
}

- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)sink {
  ++self.listenerGeneration;
  self.sink = sink;
  return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
  ++self.listenerGeneration;
  self.sink = nil;
  [self.active cancel];
  return nil;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSDictionary *args = [call.arguments isKindOfClass:NSDictionary.class] ? call.arguments : nil;
  if ([call.method isEqual:@"cancel"]) {
    if ([args[@"runId"] isKindOfClass:NSString.class] &&
        [self.active.identifier isEqual:args[@"runId"]]) [self.active cancel];
    result(nil);
    return;
  }
  if (![call.method isEqual:@"start"]) { result(FlutterMethodNotImplemented); return; }
  NSArray *strings = @[args[@"runId"] ?: NSNull.null, args[@"type"] ?: NSNull.null,
                       args[@"projectPath"] ?: NSNull.null, args[@"entryFile"] ?: NSNull.null];
  for (id value in strings) {
    if (![value isKindOfClass:NSString.class] ||
        ![[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] length] ||
        [value rangeOfString:@"\0"].location != NSNotFound) {
      result([FlutterError errorWithCode:@"invalid_run" message:@"Incomplete compilation arguments." details:nil]);
      return;
    }
  }
  if (![@[@"c", @"cpp"] containsObject:args[@"type"]] ||
      ![args[@"projectPath"] isAbsolutePath] || ![args[@"entryFile"] isAbsolutePath]) {
    result([FlutterError errorWithCode:@"invalid_run" message:@"Expected C/C++ and absolute project paths." details:nil]);
    return;
  }
  if (!self.sink) {
    result([FlutterError errorWithCode:@"missing_listener" message:@"Program output channel is not connected." details:nil]);
    return;
  }
  NSString *sdk = QFLISdkPath();
  if (!sdk) { result(@{@"available": @NO}); return; }
  if (self.active) {
    result([FlutterError errorWithCode:@"runner_busy" message:@"A program is already compiling or running." details:nil]);
    return;
  }
  QFLINativeRun *run = [[QFLINativeRun alloc] init];
  run.identifier = args[@"runId"];
  run.projectPath = args[@"projectPath"];
  run.entryPath = args[@"entryFile"];
  id requestedSources = args[@"sources"];
  if (requestedSources != nil) {
    if (![requestedSources isKindOfClass:NSArray.class]) {
      result([FlutterError errorWithCode:@"invalid_run" message:@"Selected sources must be an array." details:nil]);
      return;
    }
    for (id value in (NSArray *)requestedSources) {
      if (![value isKindOfClass:NSString.class] || ![value isAbsolutePath]) {
        result([FlutterError errorWithCode:@"invalid_run" message:@"Selected source paths must be absolute." details:nil]);
        return;
      }
    }
    run.requestedSources = requestedSources;
  }
  run.sdkPath = sdk;
  run.listenerGeneration = self.listenerGeneration;
  self.active = run;
  result(@{@"available": @YES});
  dispatch_async(self.worker, ^{
    @autoreleasepool {
      int code = [run executeWithPipeQueue:self.pipes emit:^(NSString *kind, NSString *text) {
        [self emitForRun:run kind:kind key:@"text" value:text ?: @""];
      }];
      dispatch_async(dispatch_get_main_queue(), ^{
        if (self.active == run) self.active = nil;
        if (self.sink && self.listenerGeneration == run.listenerGeneration) {
          self.sink(@{@"runId": run.identifier, @"kind": @"exit",
                      @"exitCode": @(run.isCancelled ? 130 : code)});
        }
      });
    }
  });
}

- (void)emitForRun:(QFLINativeRun *)run kind:(NSString *)kind key:(NSString *)key value:(id)value {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self.sink && self.listenerGeneration == run.listenerGeneration) {
      self.sink(@{@"runId": run.identifier, @"kind": kind, key: value});
    }
  });
}

- (void)detachFromEngineForRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  [self.active cancel];
  self.sink = nil;
  [self.events setStreamHandler:nil];
}
@end
