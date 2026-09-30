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

static void initialize(const char *pidfile) {
    const pid_t parent = getppid();
    if (parent <= 1) _exit(125);
    if (prctl(PR_SET_PDEATHSIG, SIGKILL) != 0) fail("cannot monitor parent");
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
        /* exit also runs atexit and C++ destructors registered by the program. */
        exit(result);
    }
    fprintf(stderr, "Forge executor: expected --exec <pidfile> <executable> [args...] or --run <pidfile> <shared-object> <argv0>\n");
    return 125;
}
