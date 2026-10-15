#include <atomic>
#include <cstdio>
#include <thread>

static std::atomic<unsigned> seen[4096]{};

int main() {
  constexpr int per_thread = 128;
  constexpr int expected = 2 * per_thread;
  std::atomic<int> ready{0}, unique{0}, failures{0};
  std::atomic<bool> start{false};
  auto grow = [&] {
    ready.fetch_add(1, std::memory_order_release);
    while (!start.load(std::memory_order_acquire)) std::this_thread::yield();
    for (int index = 0; index < per_thread; ++index) {
      const size_t old_pages = __builtin_wasm_memory_grow(0, 1);
      if (old_pages == static_cast<size_t>(-1) || old_pages >= 4096) {
        failures.fetch_add(1);
      } else if (seen[old_pages].fetch_add(1) == 0) {
        unique.fetch_add(1);
      }
    }
  };
  std::thread left(grow), right(grow);
  while (ready.load(std::memory_order_acquire) != 2) std::this_thread::yield();
  // Both guest stacks and their startup allocations exist before this sample.
  const size_t before = __builtin_wasm_memory_size(0);
  start.store(true, std::memory_order_release);
  left.join();
  right.join();
  const size_t added = __builtin_wasm_memory_size(0) - before;
  std::printf("memory.grow pages=%zu unique=%d\n", added, unique.load());
  return added == expected && unique.load() == expected && failures.load() == 0 ? 0 : 8;
}
