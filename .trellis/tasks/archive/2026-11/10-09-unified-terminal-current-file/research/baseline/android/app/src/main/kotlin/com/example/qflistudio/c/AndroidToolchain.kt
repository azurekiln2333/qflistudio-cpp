package com.azurekiln.qfli.forge

import android.content.Context
import android.os.Build
import org.json.JSONObject
import java.io.DataInputStream
import java.io.File
import java.io.IOException
import java.util.zip.ZipInputStream

internal data class AndroidToolchain(
    val root: File,
    val nativeDirectory: File,
    val target: String,
    val resourceDirectory: File,
) {
    val compiler get() = File(nativeDirectory, "libqfli_clang.so")
    val linker get() = File(nativeDirectory, "libqfli-ld.lld-.so")
    val executor get() = File(nativeDirectory, "libqfli_executor.so")

    fun compilerArguments(cpp: Boolean): List<String> = listOf(
        "--driver-mode=${if (cpp) "g++" else "gcc"}",
        "--target=$target",
        "--sysroot=${File(root, "sysroot").path}",
        "-resource-dir=${resourceDirectory.path}",
        "-fno-color-diagnostics",
    ) + if (cpp) listOf(
        "-stdlib=libc++", "-isystem", File(root, "sysroot/usr/include/c++/v1").path,
    ) else emptyList()

    companion object {
        fun packagedAbi(context: Context): String? {
            val native = File(context.applicationInfo.nativeLibraryDir)
            if (listOf("libqfli_clang.so", "libqfli-ld.lld-.so", "libqfli_executor.so")
                    .any { !File(native, it).canExecute() }) return null
            return try {
                val header = ByteArray(20)
                DataInputStream(File(native, "libqfli_clang.so").inputStream()).use { it.readFully(header) }
                if (!header.copyOfRange(0, 6).contentEquals(byteArrayOf(127, 69, 76, 70, 2, 1))) return null
                val abi = when ((header[18].toInt() and 255) or ((header[19].toInt() and 255) shl 8)) {
                    62 -> "x86_64"
                    183 -> "arm64-v8a"
                    else -> return null
                }
                val archives = context.assets.list("qfli_toolchain")?.toSet() ?: return null
                abi.takeIf { it in Build.SUPPORTED_ABIS && "$it.zip" in archives }
            } catch (_: IOException) { null }
        }

        @Synchronized
        fun prepare(context: Context, abi: String): AndroidToolchain {
            @Suppress("DEPRECATION")
            val installedAt = context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime
            val root = File(context.filesDir, "forge-toolchain/$abi/$installedAt")
            val ready = File(root, ".ready")
            val prefix = root.canonicalPath + File.separator
            try {
                if (!ready.isFile) {
                    root.deleteRecursively()
                    check(root.mkdirs()) { "Cannot create toolchain directory: $root" }
                    context.assets.open("qfli_toolchain/$abi.zip").use { archive ->
                        ZipInputStream(archive).use { zip ->
                            while (true) {
                                val entry = zip.nextEntry ?: break
                                val output = File(root, entry.name)
                                check(output.canonicalPath.startsWith(prefix)) { "Invalid toolchain archive path" }
                                if (entry.isDirectory) output.mkdirs()
                                else {
                                    output.parentFile?.mkdirs()
                                    output.outputStream().use { zip.copyTo(it) }
                                }
                                zip.closeEntry()
                            }
                        }
                    }
                }
                check(File(root, "sysroot/usr/include/stdio.h").isFile) { "Incomplete Android sysroot" }
                check(File(root, "sysroot/usr/include/c++/v1/vector").isFile) { "Missing C++ headers" }
                check(File(root, "toolchain.json").isFile) { "Missing toolchain manifest" }
                val manifest = JSONObject(File(root, "toolchain.json").readText())
                val triple = manifest.getString("targetTriple")
                check(triple == when (abi) {
                    "arm64-v8a" -> "aarch64-linux-android"
                    "x86_64" -> "x86_64-linux-android"
                    else -> error("Unsupported Android toolchain ABI: $abi")
                }) { "Toolchain target does not match $abi" }
                val api = manifest.getInt("apiLevel")
                check(api in 21..Build.VERSION.SDK_INT) { "Unsupported Android toolchain API: $api" }
                val resources = File(root, manifest.getString("resourceDirectory")).canonicalFile
                check(resources.path.startsWith(prefix) && resources.isDirectory) {
                    "Missing or invalid Clang resources: $resources"
                }
                check(File(resources, "include/stddef.h").isFile) { "Missing Clang headers" }
                if (!ready.isFile) ready.writeText("ready\n")
                return AndroidToolchain(
                    root, File(context.applicationInfo.nativeLibraryDir), "$triple$api", resources,
                )
            } catch (error: Exception) {
                root.deleteRecursively()
                throw error
            }
        }
    }
}
