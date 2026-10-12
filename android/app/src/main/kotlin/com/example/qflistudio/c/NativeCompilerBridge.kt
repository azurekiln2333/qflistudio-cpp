package com.azurekiln.qfli.forge

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.system.Os
import android.system.OsConstants
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.Closeable
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.CancellationException
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicReference

internal class NativeCompilerBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler, Closeable {
    private val methods = MethodChannel(messenger, "qfli_forge/native")
    private val events = EventChannel(messenger, "qfli_forge/native/events")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val pipes = Executors.newCachedThreadPool()
    private val active = AtomicReference<NativeRun?>()
    @Volatile private var sink: EventChannel.EventSink? = null

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) { sink = eventSink }

    override fun onCancel(arguments: Any?) {
        sink = null
        active.get()?.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(call, result)
            "cancel" -> {
                val run = active.get()
                if (run?.id == call.argument<String>("runId")) run?.cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("runId")
        val type = call.argument<String>("type")
        val projectPath = call.argument<String>("projectPath")
        val entryPath = call.argument<String>("entryFile")
        if (id.isNullOrBlank() || type !in listOf("c", "cpp") ||
            projectPath.isNullOrBlank() || entryPath.isNullOrBlank()) {
            result.error("invalid_run", "编译运行参数不完整。", null)
            return
        }
        // An absent `sources` key means a legacy caller (discover sources).
        // A present key is authoritative and must be a valid, non-empty list of
        // absolute paths; anything else is rejected here, so an invalid
        // selection can never fall back to rediscovery or the default main.
        val requestedSources: List<String>? = if (call.hasArgument("sources")) {
            when (val parsed = parseRequestedSources(call.argument<Any?>("sources"))) {
                is RequestedSources -> parsed.paths
                is RequestedSourcesError -> {
                    result.error("invalid_run", parsed.message, null)
                    return
                }
            }
        } else {
            null
        }
        if (sink == null) {
            result.error("missing_listener", "编译运行输出通道未连接。", null)
            return
        }
        val abi = AndroidToolchain.packagedAbi(context)
        if (abi == null) {
            result.success(mapOf("available" to false))
            return
        }
        val run = NativeRun(id, File(projectPath), File(entryPath), abi, requestedSources)
        if (!active.compareAndSet(null, run)) {
            result.error("runner_busy", "已有程序正在编译或运行。", null)
            return
        }
        result.success(mapOf("available" to true))
        worker.execute {
            var code = 127
            try {
                code = run.execute()
            } catch (error: Exception) {
                if (!run.cancelled) emit(id, "stderr", "text", error.message ?: "编译运行失败。")
            } finally {
                run.cancelProcess()
                active.compareAndSet(run, null)
                emit(id, "exit", "exitCode", if (run.cancelled) 130 else code)
            }
        }
    }

    private fun emit(id: String, kind: String, key: String, value: Any) {
        main.post { sink?.success(mapOf("runId" to id, "kind" to kind, key to value)) }
    }

    /** Parsed `sources` payload: either the validated paths or an error. */
    private sealed interface RequestedSourcesResult
    private class RequestedSources(val paths: List<String>) : RequestedSourcesResult
    private class RequestedSourcesError(val message: String) : RequestedSourcesResult

    /**
     * Validates a present `sources` argument.
     *
     * The presence of the key already means the Dart runner chose the compile
     * set, so an empty list, a non-list, a non-string element, a blank entry
     * or a relative path is a hard error. It must never collapse to "no
     * selection" (which would rediscover every file and could run another
     * program's main).
     */
    private fun parseRequestedSources(raw: Any?): RequestedSourcesResult {
        if (raw !is List<*>) {
            return RequestedSourcesError("选择的源文件列表格式无效。")
        }
        if (raw.isEmpty()) {
            return RequestedSourcesError("选择的源文件列表为空。")
        }
        val paths = ArrayList<String>(raw.size)
        for (element in raw) {
            if (element !is String || element.isBlank() || !File(element).isAbsolute) {
                return RequestedSourcesError("选择的源文件路径无效：$element")
            }
            paths.add(element)
        }
        return RequestedSources(paths)
    }

    override fun close() {
        active.get()?.cancel()
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        sink = null
        worker.shutdownNow()
        pipes.shutdownNow()
    }

    private inner class NativeRun(
        val id: String,
        val project: File,
        val entry: File,
        val abi: String,
        val requestedSources: List<String>?,
    ) {
        @Volatile var cancelled = false
            private set
        private val processLock = Any()
        private var process: Process? = null
        private var pidFile: File? = null

        fun cancel() { cancelled = true; cancelProcess() }

        fun cancelProcess() = synchronized(processLock) {
            val running = process ?: return@synchronized
            // A group can outlive its leader while children still hold the pipes.
            fun killGroup() {
                val pid = try { pidFile?.readText()?.trim()?.toIntOrNull() } catch (_: Exception) { null }
                if (pid != null && pid > 1) {
                    try { Os.kill(-pid, OsConstants.SIGKILL) } catch (_: Exception) { }
                }
            }
            killGroup()
            // Android destroy() closes pipes; a completed child still has output to drain.
            try { running.exitValue() }
            catch (_: IllegalThreadStateException) { running.destroy() }
            killGroup()
        }

        fun execute(): Int {
            val root = project.canonicalFile
            check(root.isDirectory && entry.canonicalPath.startsWith(root.path + File.separator) && entry.isFile) {
                "工程或入口文件不可读取。"
            }
            if (cancelled) return 130
            val toolchain = AndroidToolchain.prepare(context, abi)
            if (cancelled) return 130
            val sources = selectSources(root)
            check(sources.isNotEmpty()) { "工程中没有可编译的源文件。" }
            val build = File(context.cacheDir, "forge-runs").apply { mkdirs() }
            val work = File.createTempFile("run-", "", build).apply { delete(); mkdirs() }
            try {
                val objects = mutableListOf<String>()
                val includes = listOf("-I", root.path, "-I", File(root, "include").path)
                for ((index, source) in sources.withIndex()) {
                    if (cancelled) return 130
                    val cxx = source.extension.lowercase() != "c"
                    val output = File(work, "$index.o")
                    val arguments = toolchain.compilerArguments(cxx) + includes + listOf(
                        "-std=${if (cxx) "c++20" else "c17"}", "-fPIC", "-c", source.path, "-o", output.path,
                    )
                    val code = invoke(toolchain, root, work, listOf(toolchain.compiler.path) + arguments)
                    if (code != 0) return code
                    objects.add(output.path)
                }
                if (cancelled) return 130
                val program = File(work, "program.so")
                val linkCpp = sources.any { it.extension.lowercase() != "c" }
                val linkArguments = toolchain.compilerArguments(linkCpp) + listOf(
                    "--ld-path=${toolchain.linker.path}", "-shared", "-Wl,-z,defs",
                    "-Wl,-z,max-page-size=16384,-z,common-page-size=16384",
                ) + objects + listOf("-latomic", "-lm", "-o", program.path)
                val code = invoke(toolchain, root, work, listOf(toolchain.compiler.path) + linkArguments)
                if (code != 0 || cancelled) return if (cancelled) 130 else code
                check(program.setReadOnly()) { "无法设置程序文件权限。" }
                return invoke(
                    toolchain, root, work, listOf(program.path, entry.name),
                    runProgram = true, input = File(root, "input.txt").takeIf { it.isFile },
                )
            } finally { work.deleteRecursively() }
        }

        /**
         * Translation units to compile.
         *
         * An explicit [requestedSources] list from Dart is authoritative: it
         * already selected the requested entry plus ordinary helpers and
         * excluded other unambiguous main programs. Each entry must be a
         * project-local readable source; a bad list is an error, never a
         * silent fall back to re-enumerating every file (which could compile
         * a different program's main). Without a list, legacy discovery is
         * kept for older callers.
         */
        private fun selectSources(root: File): List<File> {
            val requested = requestedSources ?: return collectSources(root)
            check(requested.isNotEmpty()) { "选择的源文件列表为空。" }
            val entryPath = entry.canonicalPath
            val extensions = setOf("c", "cpp", "cc", "cxx")
            val resolved = ArrayList<File>(requested.size)
            for (path in requested) {
                val file = File(path).canonicalFile
                check(file.isFile && file.extension.lowercase() in extensions &&
                    file.path.startsWith(root.path + File.separator)) {
                    "选择的源文件不可读取或不在工程内：$path"
                }
                resolved.add(file)
            }
            check(resolved.any { it.path == entryPath }) { "选择的源文件不包含入口文件。" }
            // Entry first, matching the picoc/desktop convention; helpers keep
            // their given order.
            return resolved.sortedByDescending { it.path == entryPath }
        }

        private fun collectSources(root: File): List<File> {
            val extensions = setOf("c", "cpp", "cc", "cxx")
            val sources = mutableListOf<File>()
            fun visit(directory: File) {
                checkNotCancelled()
                val files = directory.listFiles() ?: error("无法读取工程目录：$directory")
                for (file in files) {
                    if (file.name.startsWith(".") || file.canonicalFile != file.absoluteFile) continue
                    if (file.isDirectory && file.name !in setOf("build", "node_modules")) visit(file)
                    else if (file.isFile && file.extension.lowercase() in extensions) sources.add(file)
                }
            }
            visit(root)
            return sources.sortedBy { it.path }
        }

        private fun checkNotCancelled() {
            if (cancelled) throw InterruptedException("运行已取消。")
        }

        private fun invoke(
            toolchain: AndroidToolchain,
            root: File,
            work: File,
            command: List<String>,
            runProgram: Boolean = false,
            input: File? = null,
        ): Int {
            checkNotCancelled()
            val pid = File(work, "process.pid").apply { delete() }
            val arguments = listOf(
                toolchain.executor.path, if (runProgram) "--run" else "--exec", pid.path,
            ) + command
            val builder = ProcessBuilder(arguments).directory(root)
            builder.environment()["LD_LIBRARY_PATH"] = toolchain.nativeDirectory.path
            builder.environment()["TMPDIR"] = work.path
            val child = synchronized(processLock) {
                checkNotCancelled()
                builder.start().also { process = it; pidFile = pid }
            }
            var output: Future<*>? = null
            var errors: Future<*>? = null
            try {
                output = pipes.submit { readPipe(child.inputStream, "stdout") }
                errors = pipes.submit { readPipe(child.errorStream, "stderr") }
                writeInput(child, input)
                val status = child.waitFor()
                return if (cancelled) 130 else status
            } finally {
                cancelProcess()
                try {
                    awaitTermination(child, output, errors)
                } finally {
                    synchronized(processLock) {
                        if (process === child) { process = null; pidFile = null }
                    }
                }
            }
        }

        private fun writeInput(child: Process, input: File?) {
            val destination = child.outputStream
            try {
                input?.inputStream()?.use { source ->
                    val buffer = ByteArray(8192)
                    while (!cancelled) {
                        val size = source.read(buffer)
                        if (size < 0) break
                        try { destination.write(buffer, 0, size) }
                        catch (_: IOException) { break } // The program may consume only part of input.txt.
                    }
                }
            } finally {
                try { destination.close() } catch (_: IOException) { }
            }
        }

        private fun awaitTermination(child: Process, vararg readers: Future<*>?) {
            var interrupted = false
            var failure: ExecutionException? = null
            try {
                while (true) {
                    try { child.waitFor(); break }
                    catch (_: InterruptedException) { interrupted = true }
                }
                for (reader in readers) {
                    while (true) {
                        try { reader?.get(); break }
                        catch (_: InterruptedException) { interrupted = true }
                        catch (error: ExecutionException) { failure = failure ?: error; break }
                        catch (_: CancellationException) { break }
                    }
                }
                failure?.let { throw it }
            } finally {
                child.inputStream.close()
                child.errorStream.close()
                if (interrupted) Thread.currentThread().interrupt()
            }
        }

        private fun readPipe(stream: InputStream, kind: String) {
            stream.bufferedReader(Charsets.UTF_8).use { reader ->
                while (true) {
                    val line = reader.readLine() ?: return
                    emit(id, kind, "text", line)
                }
            }
        }
    }
}
