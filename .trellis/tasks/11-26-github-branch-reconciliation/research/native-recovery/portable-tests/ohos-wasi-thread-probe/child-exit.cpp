#include <cstdlib>
#include <thread>
int main() { std::thread task([] { std::exit(7); }); task.join(); return 0; }
