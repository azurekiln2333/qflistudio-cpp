#include <thread>
int main() { std::thread task([] { __builtin_trap(); }); task.join(); return 0; }
