#include <helper.h>
#include <numeric>
#include <vector>

int answer(void) {
    const std::vector<int> values{20, 22};
    return std::accumulate(values.begin(), values.end(), 0);
}
