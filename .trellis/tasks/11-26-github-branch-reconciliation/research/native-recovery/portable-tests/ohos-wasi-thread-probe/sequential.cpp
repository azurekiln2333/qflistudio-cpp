#include <atomic>
#include <cstdio>
#include <thread>
int main() {
    std::atomic<int> count{0};
    for (int i = 0; i < 100; ++i) { std::thread task([&] { ++count; }); task.join(); }
    std::printf("sequential=%d\n", count.load());
    return count.load() == 100 ? 0 : 7;
}
