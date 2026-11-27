#include <cstdio>
#include <thread>
int main() {
    std::thread task([] { for (;;) std::this_thread::yield(); });
    task.detach();
    std::puts("detached worker stopped at main exit");
}
