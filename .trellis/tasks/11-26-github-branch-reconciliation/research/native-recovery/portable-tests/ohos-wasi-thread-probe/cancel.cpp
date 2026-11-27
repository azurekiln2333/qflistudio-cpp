#include <condition_variable>
#include <cstdio>
#include <mutex>
#include <thread>
int main() {
    std::mutex mutex;
    std::condition_variable condition;
    std::thread blocked([&] {
        std::unique_lock<std::mutex> lock(mutex);
        condition.wait(lock, [] { return false; });
    });
    std::puts("atomic wait cancellation ready");
    std::fflush(stdout);
    blocked.join();
}
