# Portable Wasm Runtime

This static adapter runs WASI SDK 33 modules with WasmEdge interpreter mode.
The upstream source is pinned to
`845df599e7b71c98b0c77990c3aa3a10022bbaae`; standard C++ exception handling
remains enabled.

## Interruptible WASI Poll

`patches/wasmedge-interruptible-poll.patch` has SHA256
`751c8581be13c260c83b6a7bc212352ba953b480a2ab18659d302aea93e01c4e`.
It changes five upstream files: the executor header, the WASI inode header,
Linux/macOS poll implementations, and the WASI host call.

The host call reads the invoking executor's stop token without consuming it.
Linux epoll and Apple kqueue waits check it every 10 milliseconds, preserving
the original timer registration and deadline. Interruption resets and releases
the WASI poller before returning the engine's Interrupted result. Windows keeps
its original poll implementation. This patch does not change exception handling.

`patches/wasmedge-static-archive.patch` has SHA256
`2df4a65505f1b1b58a66a3b361bedbeb375434045b59edadfdfa5a9f42a8c294`.
It deletes the previous output before merging. The pinned upstream already
includes fmt/spdlog. Its append operation otherwise duplicates object members
on an incremental rebuild and makes the probe fail with multiple definitions.

`apply-wasmedge-patch.cmake` checks both patch hashes, verifies forward applicability
or an already-applied reverse patch, and rejects mismatched source. The runtime
CMake applies it before dependency configuration, including with
FETCHCONTENT_SOURCE_DIR_WASMEDGE. Packaging that
records source-tree digests must apply it before recording or validating those
digests:

```sh
cmake -DQFLI_WASMEDGE_SOURCE=/absolute/pinned/source \
  -P native/portable/apply-wasmedge-patch.cmake
```

## Validation

`bash native/portable/tests/verify-sleep.sh --expect-timeout` reproduces the
unpatched hang with a bounded three-second timeout. Without that option the
script verifies 100-millisecond sleep deadlines, repeated execution, cancellation
during a 30-second sleep, and cancellation before execution. The fixture asserts
elapsed monotonic time, so returning early from sleep cannot pass.

The native API borrows all three caller-provided descriptors. Input must be a
finite file and output pipes must be drained concurrently. Engine cancellation
interrupts bytecode and poll waits; arbitrary blocking host file operations are
not converted to asynchronous I/O by this adapter.
