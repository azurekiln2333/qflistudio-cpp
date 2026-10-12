#include <cstdio>
#include <stdexcept>
#include <string>
#include <vector>

static int destroyed = 0;
struct Guard {
  ~Guard() { ++destroyed; }
};

static void throw_and_rethrow() {
  Guard outer;
  try {
    Guard inner;
    throw std::runtime_error("exception preserved");
  } catch (const std::exception &) {
    throw;
  }
}

int main() {
  try {
    throw_and_rethrow();
    return 1;
  } catch (const std::runtime_error &error) {
    std::printf("%s; destructors=%d\n", error.what(), destroyed);
  }
  try {
    std::vector<std::string> values{"one"};
    (void)values.at(5);
    return 2;
  } catch (const std::out_of_range &) {
    std::puts("stdlib exception caught");
  }
  return destroyed == 2 ? 0 : 3;
}
