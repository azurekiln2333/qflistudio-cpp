# Minimal signed native-child capability probe

Diagnostic source only; it does not change the production compiler bridge.

Add the source to the OHOS native CMake project as a separate signed library:

```cmake
add_library(qfli_native_probe SHARED
  "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../native/toolchain/tests/ohos-native-child-probe.cpp")
target_link_libraries(qfli_native_probe PUBLIC libace_napi.z.so libhilog_ndk.z.so)
```

Register an entry `oh-package.json5` local type dependency for
`libqfli_native_probe.so`, whose `index.d.ts` contains:

```typescript
export const start: (reportPath: string) => string;
```

Then import and call once from the existing diagnostic/audit entry:

```typescript
import childProbe from 'libqfli_native_probe.so';
console.info(childProbe.start(`${context.cacheDir}/native-child-probe.txt`));
```

The return string and hilog `QFLI_NATIVE_CHILD_START` contain the immediate
native API error. `errorCode=801` means this device does not support native
child processes. `apiAvailable=0` means the library/API was unavailable, with
the dynamic-loader error retained. `errorCode=0` only means startup succeeded;
read the report file or hilog for `QFLI_NATIVE_CHILD_ENTERED` to prove the signed
shared-library callback actually ran. No `execve` is used. The API is resolved
dynamically, so no hard dependency on API 13 or the API 26 capability function
is introduced. The report FD is transferred through the documented named FD
list with normal isolation; it is closed in both processes after use.

The SDK ArkTS `childProcessManager` documentation restricts native child
processes to PCs, 2-in-1s and tablets; other devices return 801. The C header
also defines the same unsupported-device error. The actual phone result is
required before extending this probe to compiler or generated-library loading.
