#include <atomic>
#include <cstdio>
#include <system_error>
#include <thread>
#include <vector>
int main() {
    std::atomic<bool> release{false};
    std::vector<std::thread> threads;
    int rejected = 0;
    for (int i = 0; i < 40; ++i) {
        try { threads.emplace_back([&] { while (!release.load()) std::this_thread::yield(); }); }
        catch (const std::system_error &) { ++rejected; }
    }
    release.store(true);
    for (auto &thread : threads) thread.join();
    std::printf("concurrent=%d rejected=%d\n", static_cast<int>(threads.size()), rejected);
    return threads.size() == 32 && rejected == 8 ? 0 : 7;
}
