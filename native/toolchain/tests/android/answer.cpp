#include <answer.h>
#include <numeric>
#include <vector>

extern "C" int answer(void) {
    const std::vector<int> values{20, 22};
    return std::accumulate(values.begin(), values.end(), 0);
}
