import 'forge_topic.dart';

/// C++ intermediate track, part 6 of 6: topics 70..75.
const List<ForgeTopic> cppTopicsIntermediate6 = <ForgeTopic>[
  ForgeTopic(
    id: 70,
    language: 'cpp',
    level: 'intermediate',
    title: 'friend 与封装边界',
    summary: '用 friend 有选择地授权访问，理解它不破坏封装而是显式化耦合。',
    concepts: <String>['friend', '访问控制', '运算符友元', '耦合'],
    objective: '用 friend 让非成员函数或类访问私有成员。',
    prerequisites: <String>['类与封装'],
    standard: 'c++17',
    explain:
        'friend 声明授予某个函数或类访问私有成员的权限。它常用于让非成员的'
        'operator<< 访问私有字段。friend 是白名单式授权，比把所有成员设为 public '
        '更精确；但过度使用会暴露实现，慎用。',
    code: '#include <iostream>\n\n'
        'class Account {\n'
        'public:\n'
        '    explicit Account(int balance) : balance_(balance) {}\n'
        '    friend bool richer(const Account& a, const Account& b);\n'
        'private:\n'
        '    int balance_;\n'
        '};\n\n'
        'bool richer(const Account& a, const Account& b) {\n'
        '    return a.balance_ > b.balance_;\n'
        '}\n\n'
        'int main() {\n'
        '    Account a(100);\n'
        '    Account b(200);\n'
        '    std::cout << richer(a, b) << " " << richer(b, a) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '0 1\n',
    pitfalls: <String>[
      'friend 不是双向的，也不是传递的。',
      '能通过公有接口表达就别用 friend。',
      'friend 声明要写在使用前。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '让 richer 返回两者余额之和，观察需要哪些访问权限。',
        hint: '同一 friend 声明即可访问双方私有字段。',
        answer: '需要访问两个对象的 balance_，friend 已授权。',
      ),
    ],
  ),
  ForgeTopic(
    id: 71,
    language: 'cpp',
    level: 'intermediate',
    title: 'RAII 与作用域守卫',
    summary: '用 RAII 对象管理任意资源，实现自动清理与作用域守卫。',
    concepts: <String>['RAII', '作用域守卫', '资源管理', '异常安全'],
    objective: '用一个 RAII 守卫对象在作用域结束时执行清理。',
    prerequisites: <String>['析构函数与 RAII'],
    standard: 'c++17',
    explain:
        'RAII 不止用于内存：文件句柄、锁、临时状态都可以交给析构函数管理。'
        '作用域守卫（scope guard）在构造时记录一个收尾动作、析构时执行它，'
        '即使中途 return 或抛异常也能保证清理，是异常安全的基石。',
    code: '#include <functional>\n#include <iostream>\n\n'
        'class ScopeGuard {\n'
        'public:\n'
        '    explicit ScopeGuard(std::function<void()> action) : action_(std::move(action)) {}\n'
        '    ~ScopeGuard() { if (action_) action_(); }\n'
        '    ScopeGuard(const ScopeGuard&) = delete;\n'
        '    ScopeGuard& operator=(const ScopeGuard&) = delete;\n'
        'private:\n'
        '    std::function<void()> action_;\n'
        '};\n\n'
        'int main() {\n'
        '    std::cout << "enter\\n";\n'
        '    ScopeGuard guard([] { std::cout << "cleanup\\n"; });\n'
        '    std::cout << "working\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'enter\nworking\ncleanup\n',
    pitfalls: <String>[
      '守卫不可拷贝（否则清理会执行多次），用引用/移动传递。',
      '析构里不要抛异常。',
      '需要“取消”语义时提供 release()。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '在 guard 之后提前 return，观察 cleanup 是否仍执行。',
        hint: '析构在作用域退出时总会运行。',
        answer: '仍会输出 cleanup。',
      ),
    ],
  ),
  ForgeTopic(
    id: 72,
    language: 'cpp',
    level: 'intermediate',
    title: '自定义迭代器',
    summary: '为自定义容器实现迭代器，使其能配合范围循环与标准算法。',
    concepts: <String>['迭代器', 'begin/end', '范围循环', '算法兼容'],
    objective: '为一个简单容器实现最小迭代器并用于范围循环。',
    prerequisites: <String>['迭代器基础'],
    standard: 'c++17',
    explain:
        '一个最小迭代器需要支持 *（解引用）、++（前进）、== / !=（比较）。'
        '有了 begin()/end() 返回迭代器，自定义容器就能用于范围循环和标准算法。'
        '完整实现还要提供迭代器类别别名以兼容更多算法。',
    code: '#include <iostream>\n\n'
        'class Range {\n'
        'public:\n'
        '    class iterator {\n'
        '    public:\n'
        '        explicit iterator(int v) : value_(v) {}\n'
        '        int operator*() const { return value_; }\n'
        '        iterator& operator++() { ++value_; return *this; }\n'
        '        bool operator!=(const iterator& o) const { return value_ != o.value_; }\n'
        '    private:\n'
        '        int value_;\n'
        '    };\n'
        '    explicit Range(int n) : n_(n) {}\n'
        '    iterator begin() const { return iterator(0); }\n'
        '    iterator end() const { return iterator(n_); }\n'
        'private:\n'
        '    int n_;\n'
        '};\n\n'
        'int main() {\n'
        '    int sum = 0;\n'
        '    for (int x : Range(5)) sum += x;\n'
        '    std::cout << "sum=" << sum << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'sum=10\n',
    pitfalls: <String>[
      '迭代器要能被标准库识别需要提供迭代器类别（iterator_category）。',
      'end() 迭代器不能解引用。',
      '范围循环需要 begin()/end() 返回的迭代器类型一致。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '让 Range 支持步长参数 Range(start, end, step)。',
        hint: '迭代器 ++ 时加 step。',
        answer: 'Range(0,10,2) 遍历 0 2 4 6 8。',
      ),
    ],
  ),
  ForgeTopic(
    id: 73,
    language: 'cpp',
    level: 'intermediate',
    title: '用断言做单元测试',
    summary: '用简单断言组织可运行的单元测试，建立回归保护。',
    concepts: <String>['单元测试', '断言', '回归', '测试驱动'],
    objective: '为函数编写一组断言式测试并在主程序里运行。',
    prerequisites: <String>['使用断言与调试'],
    standard: 'c++17',
    explain:
        '在缺少测试框架时，可以用断言组织最小单元测试：为每个被测函数写若干'
        '边界用例，用 assert 校验，全部通过则程序正常结束、返回 0。'
        '这能在重构时快速发现问题。真实项目会引入 Catch2/GoogleTest。',
    code: '#include <cassert>\n#include <iostream>\n#include <vector>\n\n'
        'int fibonacci(int n) {\n'
        '    if (n < 2) return n;\n'
        '    int a = 0, b = 1;\n'
        '    for (int i = 2; i <= n; ++i) { int c = a + b; a = b; b = c; }\n'
        '    return b;\n'
        '}\n\n'
        'void runTests() {\n'
        '    assert(fibonacci(0) == 0);\n'
        '    assert(fibonacci(1) == 1);\n'
        '    assert(fibonacci(10) == 55);\n'
        '}\n\n'
        'int main() {\n'
        '    runTests();\n'
        '    std::cout << "all tests passed\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'all tests passed\n',
    pitfalls: <String>[
      'assert 在 NDEBUG 下被移除，正式测试要用专门的框架。',
      '断言里不要写有副作用的表达式。',
      '测试要覆盖边界值（0、1、负数）而非只有典型值。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '为 fibonacci 增加一个边界测试 fibonacci(2) == 1。',
        hint: '加一条 assert。',
        answer: '断言通过，程序仍输出 all tests passed。',
      ),
    ],
  ),
  ForgeTopic(
    id: 74,
    language: 'cpp',
    level: 'intermediate',
    title: '编译与构建入门',
    summary: '理解编译、汇编、链接的流程与常见构建错误。',
    concepts: <String>['编译流程', '链接', '符号', '头文件依赖'],
    objective: '解释一次编译链接的各个阶段与典型错误来源。',
    prerequisites: <String>['头文件、inline 与编译链接'],
    standard: 'c++17',
    explain:
        'C++ 构建分预处理、编译、汇编、链接四步。常见错误：预处理阶段找不到头文件；'
        '编译阶段语法/类型错误；链接阶段“undefined reference”（缺定义）或'
        '“multiple definition”（重复定义）。理解阶段能快速定位错误性质。',
    code: '#include <iostream>\n\n'
        '// 声明（通常来自头文件）\n'
        'int compute(int x);\n\n'
        '// 定义（通常来自另一个 .cpp）\n'
        'int compute(int x) { return x * 2; }\n\n'
        'int main() {\n'
        '    std::cout << compute(21) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '42\n',
    pitfalls: <String>[
      '只声明未定义会在链接期报 undefined reference。',
      '在头文件里定义非 inline 函数会导致 multiple definition。',
      '编译通过但链接失败通常意味着符号缺失或重复。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '删除 compute 的定义，观察链接错误。',
        hint: '只留声明会报 undefined reference to compute(int)。',
        answer: '链接失败，提示 undefined reference。',
      ),
    ],
  ),
  ForgeTopic(
    id: 75,
    language: 'cpp',
    level: 'intermediate',
    title: '综合练习：库存管理',
    summary: '综合运用类、容器、算法与错误处理完成一个小型库存系统。',
    concepts: <String>['综合', '类设计', 'map', '算法'],
    objective: '把类、容器、算法与错误处理组合成一个小型系统。',
    prerequisites: <String>['std::map：有序键值表', 'std::optional 入门'],
    standard: 'c++17',
    explain:
        '这一课把类封装、unordered_map 统计、optional 表达缺失、'
        '算法与格式化输出组合起来：实现一个库存，支持入库、出库（余额不足返回失败）、'
        '查询与汇总。它体现“数据 + 操作 + 明确失败”的中等规模设计思路。',
    code: '#include <iostream>\n#include <optional>\n#include <string>\n'
        '#include <unordered_map>\n\n'
        'class Inventory {\n'
        'public:\n'
        '    void add(const std::string& item, int count) { items_[item] += count; }\n'
        '    std::optional<int> remove(const std::string& item, int count) {\n'
        '        auto it = items_.find(item);\n'
        '        if (it == items_.end() || it->second < count) return std::nullopt;\n'
        '        it->second -= count;\n'
        '        return it->second;\n'
        '    }\n'
        '    int total() const {\n'
        '        int sum = 0;\n'
        '        for (const auto& [item, count] : items_) sum += count;\n'
        '        return sum;\n'
        '    }\n'
        'private:\n'
        '    std::unordered_map<std::string, int> items_;\n'
        '};\n\n'
        'int main() {\n'
        '    Inventory inv;\n'
        '    inv.add("apple", 10);\n'
        '    inv.add("pear", 5);\n'
        '    if (auto left = inv.remove("apple", 3)) {\n'
        '        std::cout << "apple left " << *left << "\\n";\n'
        '    }\n'
        '    if (!inv.remove("pear", 100)) {\n'
        '        std::cout << "pear insufficient\\n";\n'
        '    }\n'
        '    std::cout << "total=" << inv.total() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'apple left 7\npear insufficient\ntotal=12\n',
    pitfalls: <String>[
      'remove 返回 optional 让“不足”与“数量”都用同一通道表达。',
      'unordered_map 遍历无序，需要稳定顺序时用 map。',
      '整数计数溢出在真实系统中要额外处理。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '增加一种商品并实现按名称查询剩余数量。',
        hint: '加一个 count(item) 返回 optional<int>。',
        answer: '查询存在的商品返回数量，不存在返回 nullopt。',
      ),
    ],
  ),
];
