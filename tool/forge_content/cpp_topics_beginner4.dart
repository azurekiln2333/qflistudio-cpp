import 'forge_topic.dart';

/// C++ beginner track, part 4 of 5: topics 27..34.
const List<ForgeTopic> cppTopicsBeginner4 = <ForgeTopic>[
  ForgeTopic(
    id: 27,
    language: 'cpp',
    level: 'beginner',
    title: 'ranges 入门',
    summary: '用 C++20 ranges 直接对容器调用算法，省去 begin/end。',
    concepts: <String>['std::ranges', 'ranges::sort', '视图初识', 'C++20'],
    objective: '用 std::ranges:: 算法对容器整体操作。',
    prerequisites: <String>['算法入门：sort/find/count'],
    standard: 'c++20',
    explain:
        'C++20 的 <ranges> 让算法直接接收容器，std::ranges::sort(v) 取代 '
        'std::sort(v.begin(), v.end())。它还提供惰性视图（views）做管道式数据变换。'
        'ranges 算法更安全、更易读，是现代 C++ 的推荐写法。',
    code: '#include <algorithm>\n#include <iostream>\n#include <ranges>\n#include <vector>\n\n'
        'int main() {\n'
        '    std::vector<int> v = {5, 3, 8, 1, 4};\n'
        '    std::ranges::sort(v);\n'
        '    for (int x : v) std::cout << x << " ";\n'
        '    std::cout << "\\n";\n'
        '    auto evens = v | std::views::filter([](int x) { return x % 2 == 0; });\n'
        '    for (int x : evens) std::cout << x << " ";\n'
        '    std::cout << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '1 3 4 5 8 \n4 8 \n',
    pitfalls: <String>[
      'ranges 需要 C++20 及支持它的编译器（WSL clang 18 / g++ 13 及 App 的 C++20 均可用）。',
      '视图是惰性的，绑定到临时容器会悬空。',
      '并非所有算法都有 ranges 版本，混合使用时要看头文件。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 views::transform 把每个元素平方后打印。',
        hint: 'v | std::views::transform([](int x){return x*x;})',
        answer: '对 {1,3,4,5,8} 输出 1 9 16 25 64。',
      ),
    ],
  ),
  ForgeTopic(
    id: 28,
    language: 'cpp',
    level: 'beginner',
    title: '编译期计算入门：constexpr 函数',
    summary: '用 constexpr 在编译期算出结果，理解编译期与运行期的分界。',
    concepts: <String>['constexpr 函数', '编译期求值', 'static_assert', '常量表达式'],
    objective: '编写 constexpr 函数并用 static_assert 验证编译期结果。',
    prerequisites: <String>['const 与 constexpr'],
    standard: 'c++17',
    explain:
        'constexpr 函数在实参是常量表达式时可于编译期求值，否则退化为运行期。'
        'static_assert 在编译期检查条件，不满足直接编译失败。'
        '两者结合能把计算错误提前到编译期，是模板元编程的基础。',
    code: '#include <iostream>\n\n'
        'constexpr int factorial(int n) {\n'
        '    int r = 1;\n'
        '    for (int i = 2; i <= n; ++i) r *= i;\n'
        '    return r;\n'
        '}\n\n'
        'static_assert(factorial(5) == 120, "5! 应为 120");\n\n'
        'int main() {\n'
        '    constexpr int f6 = factorial(6);\n'
        '    std::cout << "6! = " << f6 << "\\n";\n'
        '    int n = 4;\n'
        '    std::cout << "4! = " << factorial(n) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '6! = 720\n4! = 24\n',
    pitfalls: <String>[
      'constexpr 函数体内不能有未定义行为（如越界）。',
      'static_assert 的表达式必须是编译期常量。',
      'C++11 的 constexpr 函数限制为单条 return，C++14 起才宽松。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '加一条 static_assert(factorial(0) == 1) 验证边界。',
        hint: '0! 定义为 1。',
        answer: '编译通过，说明 0! 被正确算成 1。',
      ),
    ],
  ),
  ForgeTopic(
    id: 29,
    language: 'cpp',
    level: 'beginner',
    title: '使用断言与调试',
    summary: '用 assert 表达前置条件，理解发布构建下 NDEBUG 的影响。',
    concepts: <String>['assert', 'NDEBUG', '调试输出', '前置条件'],
    objective: '用 assert 表达前置条件并在调试期捕获违规。',
    prerequisites: <String>['条件与 switch'],
    standard: 'c++17',
    explain:
        'assert(cond) 在条件为假时终止并打印位置，用于表达“绝不该发生”的前提。'
        '定义 NDEBUG 后 assert 会被移除，所以不要在里面写有副作用的表达式。'
        '断言是调试工具，面向用户的错误处理该用异常或返回值。',
    code: '#include <cassert>\n#include <iostream>\n\n'
        'int divide(int a, int b) {\n'
        '    assert(b != 0 && "除数不应为零");\n'
        '    return a / b;\n'
        '}\n\n'
        'int main() {\n'
        '    std::cout << divide(10, 2) << "\\n";\n'
        '    std::cout << "断言通过\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '5\n断言通过\n',
    pitfalls: <String>[
      'assert 里有副作用（如 ++i）会在发布版被消除，导致行为不一致。',
      'assert 不用于校验用户输入。',
      'NDEBUG 定义后 assert 变成空操作。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '在 main 里调用 divide(1, 0) 观察断言触发（预期失败）。',
        hint: '断言失败会 abort，程序非零退出。',
        answer: '断言触发并异常终止；本例保留合法调用以便通过。',
      ),
    ],
  ),
  ForgeTopic(
    id: 30,
    language: 'cpp',
    level: 'beginner',
    title: '位运算基础',
    summary: '用与/或/异或/移位操作整数的二进制位。',
    concepts: <String>['位运算', '移位', '掩码', '十六进制'],
    objective: '用位运算设置、清除、翻转和检查二进制位。',
    prerequisites: <String>['const 与 constexpr'],
    standard: 'c++17',
    explain:
        '& 按位与（掩码），| 按位或（置位），^ 按位异或（翻转/比较），~ 取反，<< >> 移位。'
        '常用十六进制 0x 表示位模式。对无符号数移位是逻辑移位；对有符号负数左移是未定义行为。',
    code: '#include <iostream>\n\n'
        'int main() {\n'
        '    unsigned flags = 0b0000;\n'
        '    flags |= (1u << 2);      // 置第 2 位\n'
        '    flags |= (1u << 0);      // 置第 0 位\n'
        '    std::cout << "flags=" << flags << "\\n";\n'
        '    std::cout << "bit2 set? " << ((flags >> 2) & 1u) << "\\n";\n'
        '    flags &= ~(1u << 0);     // 清第 0 位\n'
        '    std::cout << "flags=" << flags << "\\n";\n'
        '    std::cout << "xor=" << (0xF0 ^ 0x0F) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'flags=5\nbit2 set? 1\nflags=4\nxor=255\n',
    pitfalls: <String>[
      '对负数左移是未定义行为。',
      '移位数超过类型宽度是未定义行为。',
      '位运算优先级低于比较，写掩码时勤加括号。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '统计 flags 中置位的个数。',
        hint: 'while (x) { ++n; x &= x - 1; }',
        answer: '对 flags=4 输出 1。',
      ),
    ],
  ),
  ForgeTopic(
    id: 31,
    language: 'cpp',
    level: 'beginner',
    title: '数值格式化输出',
    summary: '用 <iomanip> 控制宽度、精度、填充和对齐。',
    concepts: <String>['iomanip', 'setw', 'setprecision', 'fixed'],
    objective: '用操纵器控制浮点精度和列宽，生成整齐的表格输出。',
    prerequisites: <String>['std::string 基础'],
    standard: 'c++17',
    explain:
        '<iomanip> 提供 setw（下一个输出的最小宽度）、setfill（填充字符）、'
        'setprecision（有效/小数位数）、fixed（定点表示）、left/right（对齐）。'
        'setprecision 一次设置后持续生效，setw 只影响紧接着的一次输出。',
    code: '#include <iomanip>\n#include <iostream>\n\n'
        'int main() {\n'
        '    double pi = 3.14159265;\n'
        '    std::cout << std::fixed << std::setprecision(2) << pi << "\\n";\n'
        '    std::cout << std::setprecision(4) << pi << "\\n";\n'
        '    std::cout << std::setw(8) << std::setfill(\'0\') << 42 << "\\n";\n'
        '    std::cout << std::left << std::setw(6) << std::setfill(\'.\') << 7 << "|\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '3.14\n3.1416\n00000042\n7.....|\n',
    pitfalls: <String>[
      'setw 只作用于下一次输出，不复用。',
      'fixed 与 setprecision 组合控制小数位；不写 fixed 时是有效数字位。',
      '浮点输出在不同平台可能有细微差异，重要结果建议固定精度。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 42 的宽度改成 10，观察补零数量变化。',
        hint: 'setw(10) 会补到 10 位。',
        answer: '输出 0000000042。',
      ),
    ],
  ),
  ForgeTopic(
    id: 32,
    language: 'cpp',
    level: 'beginner',
    title: 'stringstream：字符串作为流',
    summary: '用 std::stringstream 在字符串与类型之间转换、拼接文本。',
    concepts: <String>['std::stringstream', '格式化到字符串', '解析字符串', 'ostringstream'],
    objective: '用 stringstream 生成格式化字符串并从中解析多个值。',
    prerequisites: <String>['std::string 基础'],
    standard: 'c++17',
    explain:
        '<sstream> 的 std::ostringstream 像 cout 一样 << 但结果进入内存字符串，'
        'std::istringstream 像 cin 一样 >> 从字符串解析。'
        '它们避免手写 C 风格 sprintf，类型安全。std::stringstream 两者兼可。',
    code: '#include <iostream>\n#include <sstream>\n#include <string>\n\n'
        'int main() {\n'
        '    std::ostringstream oss;\n'
        '    oss << "score=" << 95 << " level=" << 3;\n'
        '    std::string text = oss.str();\n'
        '    std::cout << text << "\\n";\n\n'
        '    std::istringstream iss("12 34 56");\n'
        '    int a = 0, b = 0, c = 0;\n'
        '    iss >> a >> b >> c;\n'
        '    std::cout << a + b + c << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'score=95 level=3\n102\n',
    pitfalls: <String>[
      '重复使用同一个 stringstream 前要 clear() 并清空内容，否则残留状态。',
      'oss.str("") 才能清空已写入内容。',
      '解析失败会设置 failbit，注意检查。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 istringstream 解析 "3.5 4.5"，打印它们之和。',
        hint: '用 double 接收。',
        answer: '输出 8。',
      ),
    ],
  ),
  ForgeTopic(
    id: 33,
    language: 'cpp',
    level: 'beginner',
    title: 'const 正确性入门',
    summary: '把不该修改的参数和成员函数标为 const，让编译器守住约定。',
    concepts: <String>['const 参数', 'const 成员函数', 'const 引用', '接口约束'],
    objective: '用 const 引用参数和 const 成员函数表达只读语义。',
    prerequisites: <String>['std::string 基础'],
    standard: 'c++17',
    explain:
        '按 const 引用传参既避免拷贝又承诺不修改。const 成员函数表示不改变对象状态，'
        'const 对象只能调用 const 成员函数。const 正确性是 C++ 接口设计的基本功：'
        '它让“只读”成为类型系统可检查的契约。',
    code: '#include <iostream>\n#include <string>\n\n'
        'struct Rectangle {\n'
        '    double width;\n'
        '    double height;\n'
        '    double area() const { return width * height; }\n'
        '};\n\n'
        'void printArea(const Rectangle& r) {\n'
        '    // r.width = 1;  // 编译错误：const 引用不可修改\n'
        '    std::cout << "area=" << r.area() << "\\n";\n'
        '}\n\n'
        'int main() {\n'
        '    Rectangle r{3.0, 4.0};\n'
        '    printArea(r);\n'
        '    const Rectangle c{2.0, 5.0};\n'
        '    std::cout << c.area() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'area=12\n10\n',
    pitfalls: <String>[
      '漏写成员函数的 const 会导致 const 对象无法调用它。',
      'const 引用可延长临时对象生命周期，但仍不能修改。',
      'const 不传播到指针指向的数据（const T* vs T* const）。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 Rectangle 加一个 const 成员函数 perimeter() 并调用。',
        hint: 'double perimeter() const { return 2 * (width + height); }',
        answer: 'r.perimeter() 输出 14。',
      ),
    ],
  ),
  ForgeTopic(
    id: 34,
    language: 'cpp',
    level: 'beginner',
    title: '综合练习：学生成绩统计',
    summary: '综合运用 vector、string、算法与格式化，完成一个小统计程序。',
    concepts: <String>['综合', 'vector', 'struct', '算法', '格式化'],
    objective: '把结构体、容器、算法与输出组合成一个完整的小程序。',
    prerequisites: <String>['算法入门：sort/find/count', '数值格式化输出'],
    standard: 'c++17',
    explain:
        '这一课把前面学的结构体、vector、范围循环、算法和定点输出组合起来：'
        '定义 Student、放入 vector、统计总分与平均分、找出最高分。'
        '综合练习的目标是体会“数据 + 算法 + 输出”的组织方式，而不是引入新语法。',
    code: '#include <algorithm>\n#include <iomanip>\n#include <iostream>\n'
        '#include <string>\n#include <vector>\n\n'
        'struct Student {\n'
        '    std::string name;\n'
        '    int score;\n'
        '};\n\n'
        'int main() {\n'
        '    std::vector<Student> students = {{"小明", 88}, {"小红", 95}, {"小刚", 72}};\n'
        '    int total = 0;\n'
        '    for (const auto& s : students) total += s.score;\n'
        '    auto best = std::max_element(\n'
        '        students.begin(), students.end(),\n'
        '        [](const Student& a, const Student& b) { return a.score < b.score; });\n'
        '    std::cout << "人数 " << students.size() << "\\n";\n'
        '    std::cout << "平均 " << std::fixed << std::setprecision(1)\n'
        '              << static_cast<double>(total) / students.size() << "\\n";\n'
        '    std::cout << "最高 " << best->name << " " << best->score << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '人数 3\n平均 85.0\n最高 小红 95\n',
    pitfalls: <String>[
      'total / students.size() 是整数除法，要先转 double。',
      'max_element 返回迭代器，需解引用；空容器会返回 end()。',
      '结构体字段顺序与初始化列表必须一致。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '增加一名学生，观察平均分变化。',
        hint: '在初始化列表里加一项即可。',
        answer: '人数与平均分随之变化，最高分可能改变。',
      ),
    ],
  ),
];
