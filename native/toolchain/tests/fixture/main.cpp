#include <answer.h>
#include <algorithm>
#include <iostream>
#include <numeric>
#include <stdexcept>
#include <string>
#include <vector>

int main() {
    std::vector<int> values{22, 20};
    std::sort(values.begin(), values.end());
    const int sum = std::accumulate(values.begin(), values.end(), 0);
    try {
        if (sum != answer()) throw std::runtime_error("mixed link failed");
        std::cout << std::to_string(sum) << std::endl;
    } catch (const std::exception &error) {
        std::cerr << error.what() << std::endl;
        return 1;
    }
    return 0;
}
