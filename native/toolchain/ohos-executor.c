/*
 * OHOS 原生执行器：把「编译好的程序」放到一个独立进程里跑。
 *
 * 为什么要多这一个进程：用户代码里的 exit()、abort()、段错误都会弄死当前进程。
 * 编译器和被编译的程序必须活在别处，否则一次错误的用户代码就能带走整个 App。
 *
 * 为什么不能直接 exec：OHOS 的 ArkTS `childProcessManager` 只认官方白名单，
 * 不支持手机上启动任意可执行文件。但 NDK（musl）层的 fork/exec 是可用的，
 * 所以由本文件自己 fork，绕过那个 API 限制。
 *
 * 协议与 Android 版一致，便于 Dart 侧复用同一套桥：
 *
 *   libqfli_executor.so --exec <pidfile> <executable> [args...]
 *   libqfli_executor.so --run  <pidfile> <shared-object> <argv0>
 *
 *   --exec 用 clang/ld.lld 编译链接（会把自己的映像替换掉）。
 *   --run  用 dlopen 加载生成的 .so，调它导出的 main(1, argv)。
 *
 * 两种模式都在动手前记下 PID 到 <pidfile>，并加入自己的进程组，
 * 这样上层取消时可以直接 kill(-pid) 把整组（含编译器子进程）一次性收掉。
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/types.h>
#include <unistd.h>

static void fail(const char *message) {
    fprintf(stderr, "Forge executor: %s: %s\n", message, strerror(errno));
    exit(125);
}

/*
 * 记下自己的 PID 并让自己成为一个进程组的组长。
 *
 * 顺序很讲究：先确认父进程还活着（父进程若已死，我们就是孤儿，跑下去没人收尸），
 * 再设 PDEATHSIG 保证父进程一死我们跟着死，然后另立进程组，最后才写 PID 文件。
 * 父进程读这个文件来 kill(-pid)。
 */
static void initialize(const char *pidfile) {
    const pid_t parent = getppid();
    if (parent <= 1) _exit(125);
    if (prctl(PR_SET_PDEATHSIG, SIGKILL) != 0) fail("cannot monitor parent");
    /* PDEATHSIG 和取 getppid 之间父进程可能已经没了，这里补一次检查。 */
    if (getppid() != parent) _exit(125);
    if (setpgid(0, 0) != 0) fail("cannot create process group");
    const int descriptor = open(pidfile, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
    if (descriptor < 0) fail("cannot create PID file");
    char buffer[32];
    const int length = snprintf(buffer, sizeof(buffer), "%ld\n", (long)getpid());
    ssize_t written;
    do { written = write(descriptor, buffer, (size_t)length); } while (written < 0 && errno == EINTR);
    if (written != length) fail("cannot write PID file");
    if (close(descriptor) != 0) fail("cannot close PID file");
}

int main(int argc, char **argv) {
    if (argc >= 4 && strcmp(argv[1], "--exec") == 0) {
        initialize(argv[2]);
        execv(argv[3], &argv[3]);
        fail("cannot start executable");
    }
    if (argc == 5 && strcmp(argv[1], "--run") == 0) {
        initialize(argv[2]);
        /*
         * 生成程序用的是它自己的 libc 运行时。stdio 默认是全缓冲，
         * 程序崩了输出就丢了；这里改成行缓冲/无缓冲，保证输出能实时流回 Dart。
         */
        setvbuf(stdout, NULL, _IOLBF, 0);
        setvbuf(stderr, NULL, _IONBF, 0);
        void *library = dlopen(argv[3], RTLD_NOW | RTLD_LOCAL);
        if (library == NULL) {
            fprintf(stderr, "Forge executor: cannot load program: %s\n", dlerror());
            return 125;
        }
        dlerror();
        int (*entry)(int, char **) = (int (*)(int, char **))dlsym(library, "main");
        const char *error = dlerror();
        if (error != NULL) {
            fprintf(stderr, "Forge executor: cannot find main: %s\n", error);
            return 125;
        }
        char *arguments[] = {argv[4], NULL};
        const int result = entry(1, arguments);
        fflush(NULL);
        /* 用 exit 而不是 return，好让用户代码注册的 atexit / C++ 析构函数跑到。 */
        exit(result);
    }
    fprintf(stderr, "Forge executor: expected --exec <pidfile> <executable> [args...] or --run <pidfile> <shared-object> <argv0>\n");
    return 125;
}
