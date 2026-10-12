import 'forge_topic.dart';

/// C++ beginner track, part 2 of 5: topics 9..17.
const List<ForgeTopic> cppTopicsBeginner2 = <ForgeTopic>[
  ForgeTopic(
    id: 9,
    language: 'cpp',
    level: 'beginner',
    title: '默认参数',
    summary: '给函数参数提供默认值，使调用者可以省略尾部的实参。',
    concepts: <String>['默认参数', '声明与定义', '调用省略'],
    objective: '为函数定义默认参数并在调用时省略尾参。',
    prerequisites: <String>['函数与重载'],
    standard: 'c++17',
    explain:
        '函数的参数可以在声明处给默认值，调用时省略的实参取默认值。'
        '默认参数必须从右往左连续给出，不能中间空一个。'
        '默认值通常只在声明处写一次，同时写声明和定义要避免重复指定。',
    code: '#include <iostream>\n#include <string>\n\n'
        'std::string greet(const std::string& name,\n'
        '                  const std::string& prefix = "你好",\n'
        '                  const std::string& suffix = "！") {\n'
        '    return prefix + "，" + name + suffix;\n'
        '}\n\n'
        'int main() {\n'
        '    std::cout << greet("小明") << "\\n";\n'
        '    std::cout << greet("小红", "早上好") << "\\n";\n'
        '    std::cout << greet("小刚", "嗨", "~") << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '你好，小明！\n早上好，小红！\n嗨，小刚~\n',
    pitfalls: <String>[
      '默认参数必须靠右连续，不能 greet(string a = "x", string b)。',
      '声明和定义同时写默认值会编译报错。',
      '默认参数与重载混用可能产生歧义调用。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 suffix 的默认值换成 "。" 并只调用一次。',
        hint: '改默认值即可。',
        answer: '把 suffix 默认值改为 "。"，greet("小明") 输出「你好，小明。」。',
      ),
    ],
  ),
  ForgeTopic(
    id: 10,
    language: 'cpp',
    level: 'beginner',
    title: '命名空间',
    summary: '用 namespace 分组名字，避免命名冲突并选择性使用 using。',
    concepts: <String>['namespace', '作用域', 'using 声明', '嵌套命名空间'],
    objective: '定义命名空间并用限定名和 using 访问其中的成员。',
    prerequisites: <String>['函数与重载'],
    standard: 'c++17',
    explain:
        '命名空间把相关的名字包在一起，用 :: 限定访问。标准库都在 std 里，所以写 std::cout。'
        '可以定义自己的命名空间来避免冲突。using ns::name; 只引入一个名字，'
        '比 using namespace ns; 更安全。',
    code: '#include <iostream>\n\n'
        'namespace math {\n'
        '    int square(int x) { return x * x; }\n'
        '    namespace detail {\n'
        '        int twice(int x) { return x * 2; }\n'
        '    }\n'
        '}\n\n'
        'int main() {\n'
        '    std::cout << math::square(5) << "\\n";\n'
        '    std::cout << math::detail::twice(5) << "\\n";\n'
        '    using math::square;\n'
        '    std::cout << square(6) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '25\n10\n36\n',
    pitfalls: <String>[
      '在头文件里写 using namespace std; 会污染所有包含者。',
      '命名空间里只声明不定义时，定义处也要用同样的限定名。',
      '匿名命名空间有内部链接，作用类似 static。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '在 math 里再加一个 cube 函数并调用。',
        hint: 'int cube(int x){return x*x*x;}',
        answer: 'math::cube(3) 输出 27。',
      ),
    ],
  ),
  ForgeTopic(
    id: 11,
    language: 'cpp',
    level: 'beginner',
    title: 'const 与 constexpr',
    summary: '用 const 表达只读，用 constexpr 在编译期求值。',
    concepts: <String>['const', 'constexpr', '编译期常量', '只读'],
    objective: '区分 const 运行时常量与 constexpr 编译期常量。',
    prerequisites: <String>['变量与引用'],
    standard: 'c++17',
    explain:
        'const 表示对象初始化后不可修改，可以来自运行期变量。'
        'constexpr 要求表达式能在编译期求值，适合做数组大小、模板参数。'
        '凡是编译期就能定的常量优先用 constexpr，让编译器帮你算并优化。',
    code: '#include <iostream>\n\n'
        'constexpr int square(int x) { return x * x; }\n\n'
        'int main() {\n'
        '    const int runtimeValue = 6;\n'
        '    constexpr int compileValue = square(5);\n'
        '    int arr[square(3)] = {0};\n'
        '    std::cout << runtimeValue << "\\n";\n'
        '    std::cout << compileValue << "\\n";\n'
        '    std::cout << sizeof(arr) / sizeof(arr[0]) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '6\n25\n9\n',
    pitfalls: <String>[
      'constexpr 函数在 C++11 里限制很多；C++14 起才宽松。',
      'const 对象不能用非 const 成员函数。',
      '把运行期才知道的值赋给 constexpr 会编译失败。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '加一个 constexpr int cube(int) 并用它作为数组长度。',
        hint: 'cube(2)=8，可作为 int arr[cube(2)]。',
        answer: 'int arr[cube(2)] 长度 8。',
      ),
    ],
  ),
  ForgeTopic(
    id: 12,
    language: 'cpp',
    level: 'beginner',
    title: '条件与 switch',
    summary: '用 if/else 链和 switch 做分支，理解 break 与 fallthrough。',
    concepts: <String>['if', 'else if', 'switch', 'break', 'fallthrough'],
    objective: '用 if/else 与 switch 实现多分支选择。',
    prerequisites: <String>['变量与引用'],
    standard: 'c++17',
    explain:
        'if/else if/else 从上到下短路匹配，条件为真的分支执行后其余跳过。'
        'switch 基于整数/枚举值跳转，每个 case 后要 break，否则会“穿透”执行下一个 case'
        '（有时这是有意为之）。',
    code: '#include <iostream>\n\n'
        'int main() {\n'
        '    for (int grade = 0; grade < 5; ++grade) {\n'
        '        switch (grade) {\n'
        '            case 0: std::cout << "zero "; break;\n'
        '            case 1:\n'
        '            case 2: std::cout << "small "; break;\n'
        '            case 3: std::cout << "medium "; break;\n'
        '            default: std::cout << "large ";\n'
        '        }\n'
        '    }\n'
        '    std::cout << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'zero small small medium large \n',
    pitfalls: <String>[
      '漏写 break 导致意外穿透。',
      'switch 的表达式必须是整型或枚举，不能是浮点/字符串。',
      'case 标签必须是编译期常量。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '故意去掉 case 3 的 break，观察输出变化。',
        hint: 'fallthrough 会继续执行 default。',
        answer: 'grade=3 时会输出 "medium large"，因为穿透到了 default。',
      ),
    ],
  ),
  ForgeTopic(
    id: 13,
    language: 'cpp',
    level: 'beginner',
    title: '三种循环与 break/continue',
    summary: '用 for、while、do-while 表达不同循环意图，并控制跳出与跳过。',
    concepts: <String>['for', 'while', 'do-while', 'break', 'continue'],
    objective: '根据是否已知次数、是否至少执行一次选择循环形式。',
    prerequisites: <String>['条件与 switch'],
    standard: 'c++17',
    explain:
        'for 适合次数已知，while 适合条件驱动，do-while 保证循环体至少执行一次。'
        'break 立即跳出整个循环，continue 跳过本次剩余部分进入下一轮。'
        '选择最贴合意图的循环形式，比一律用 for 更易读。',
    code: '#include <iostream>\n\n'
        'int main() {\n'
        '    int sum = 0;\n'
        '    for (int i = 1; i <= 10; ++i) sum += i;\n'
        '    std::cout << "sum=" << sum << "\\n";\n\n'
        '    int n = 3;\n'
        '    while (n > 0) { std::cout << n << " "; --n; }\n'
        '    std::cout << "\\n";\n\n'
        '    int k = 0;\n'
        '    do { std::cout << k << " "; ++k; } while (k < 3);\n'
        '    std::cout << "\\n";\n\n'
        '    for (int i = 0; i < 10; ++i) {\n'
        '        if (i == 5) break;\n'
        '        if (i % 2 == 0) continue;\n'
        '        std::cout << i << " ";\n'
        '    }\n'
        '    std::cout << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'sum=55\n3 2 1 \n0 1 2 \n1 3 \n',
    pitfalls: <String>[
      'do-while 结尾要有分号。',
      'while 条件里改动循环变量时容易写成死循环。',
      'break 只跳出最内层循环，多层要用标志或 goto。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 for 打印 1..20 中所有 3 的倍数。',
        hint: 'for (int i=3;i<=20;i+=3)',
        answer: '输出 3 6 9 12 15 18。',
      ),
    ],
  ),
  ForgeTopic(
    id: 14,
    language: 'cpp',
    level: 'beginner',
    title: '结构化绑定',
    summary: '用 auto [a, b] = pair/tuple 一次解包多个值。',
    concepts: <String>['结构化绑定', 'std::pair', 'std::tuple', 'auto'],
    objective: '用结构化绑定解包 pair 和 tuple，提升可读性。',
    prerequisites: <String>['auto 与类型推导'],
    standard: 'c++17',
    explain:
        'C++17 的结构化绑定让 auto [x, y] = 一个 pair/tuple 解包各元素到具名变量。'
        '它常用于遍历 map（auto& [key, value]）和返回多个值的函数。'
        '加 & 或 const& 可避免拷贝。',
    code: '#include <iostream>\n#include <string>\n#include <tuple>\n\n'
        'std::pair<std::string, int> makeRecord() {\n'
        '    return {"apples", 3};\n'
        '}\n\n'
        'int main() {\n'
        '    auto [name, count] = makeRecord();\n'
        '    std::cout << name << "=" << count << "\\n";\n\n'
        '    std::tuple<int, double, char> t = {1, 2.5, \'z\'};\n'
        '    auto [a, b, c] = t;\n'
        '    std::cout << a << " " << b << " " << c << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'apples=3\n1 2.5 z\n',
    pitfalls: <String>[
      '不加引用会拷贝，pair<string,string> 时开销明显。',
      '结构化绑定不能单独指定某个变量的类型。',
      '绑定后变量名是新的，不引用原对象的字段名。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个返回 pair<int,int> 的函数，用结构化绑定打印两者之和。',
        hint: 'auto [x, y] = f(); std::cout << x + y;',
        answer: '返回 {3,4} 时输出 7。',
      ),
    ],
  ),
  ForgeTopic(
    id: 15,
    language: 'cpp',
    level: 'beginner',
    title: 'std::array：固定大小数组',
    summary: '用 std::array 获得带 size() 与边界安全的定长数组。',
    concepts: <String>['std::array', 'size()', 'at()', '定长容器'],
    objective: '用 std::array 替代 C 风格数组，获取大小和边界检查。',
    prerequisites: <String>['std::vector：动态数组'],
    standard: 'c++17',
    explain:
        'std::array<T, N> 是零开销封装的定长数组，大小是类型的一部分。'
        '它有 size()、at()（带边界检查）、front()/back()，也能用于范围循环。'
        '相比裸数组不会退化成指针，传参时保留大小信息。',
    code: '#include <array>\n#include <iostream>\n\n'
        'int main() {\n'
        '    std::array<int, 5> a = {1, 2, 3, 4, 5};\n'
        '    std::cout << "size=" << a.size() << "\\n";\n'
        '    int sum = 0;\n'
        '    for (int x : a) sum += x;\n'
        '    std::cout << "sum=" << sum << "\\n";\n'
        '    a[0] = 100;\n'
        '    std::cout << "front=" << a.front() << " back=" << a.back() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'size=5\nsum=15\nfront=100 back=5\n',
    pitfalls: <String>[
      'std::array 不能像 vector 那样 push_back，大小固定。',
      'at() 越界会抛 std::out_of_range；[] 越界未定义。',
      '传参按引用传，避免拷贝整个数组。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 a 排序后打印。',
        hint: '#include <algorithm>，std::sort(a.begin(), a.end())。',
        answer: '排序后 front=2，输出升序 2 3 4 5 100。',
      ),
    ],
  ),
  ForgeTopic(
    id: 16,
    language: 'cpp',
    level: 'beginner',
    title: 'std::pair 与 std::tuple',
    summary: '用 pair/tuple 组合异构数据，用 get<> 访问元素。',
    concepts: <String>['std::pair', 'std::tuple', 'std::get', '组合类型'],
    objective: '用 pair 和 tuple 保存并访问多个不同类型的值。',
    prerequisites: <String>['结构化绑定'],
    standard: 'c++17',
    explain:
        'std::pair<A,B> 保存两个值，用 .first/.second 访问；std::tuple<...> 保存任意多个值，'
        '用 std::get<i>(t) 访问。它们是轻量组合类型，常用于返回多个结果。'
        '结构化绑定让访问更可读。',
    code: '#include <iostream>\n#include <string>\n#include <tuple>\n\n'
        'int main() {\n'
        '    std::pair<std::string, int> p = {"age", 18};\n'
        '    std::cout << p.first << "=" << p.second << "\\n";\n\n'
        '    std::tuple<int, std::string, double> t{1, "pi", 3.14};\n'
        '    std::cout << std::get<0>(t) << " " << std::get<1>(t) << " "\n'
        '              << std::get<2>(t) << "\\n";\n'
        '    std::cout << "tuple size=" << std::tuple_size<decltype(t)>::value << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'age=18\n1 pi 3.14\ntuple size=3\n',
    pitfalls: <String>[
      'tuple 的 get 下标必须是编译期常量。',
      'pair 字段名固定为 first/second，语义靠约定。',
      '比较 pair/tuple 是逐元素字典序，注意顺序影响结果。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 std::get<1> 修改 tuple 中的字符串，再打印。',
        hint: 'get<1>(t) = "e";',
        answer: '修改后 get<1>(t) 为 "e"。',
      ),
    ],
  ),
  ForgeTopic(
    id: 17,
    language: 'cpp',
    level: 'beginner',
    title: 'enum class：强类型枚举',
    summary: '用 enum class 定义自带作用域、不隐式转换的枚举。',
    concepts: <String>['enum class', '作用域', '底层类型', '类型安全'],
    objective: '定义 enum class 并通过限定名使用，理解其类型安全优势。',
    prerequisites: <String>['命名空间'],
    standard: 'c++17',
    explain:
        'enum class 的枚举值属于该枚举的作用域，必须写 Color::Red，不会隐式转换成 int，'
        '也不会与别的枚举冲突。这是相对 C 风格 enum 的主要优势。'
        '可以指定底层类型 enum class E : unsigned char，用于节省空间或对齐。',
    code: '#include <iostream>\n\n'
        'enum class Color { Red, Green = 5, Blue };\n\n'
        'const char* name(Color c) {\n'
        '    switch (c) {\n'
        '        case Color::Red: return "red";\n'
        '        case Color::Green: return "green";\n'
        '        case Color::Blue: return "blue";\n'
        '    }\n'
        '    return "unknown";\n'
        '}\n\n'
        'int main() {\n'
        '    Color c = Color::Blue;\n'
        '    std::cout << name(c) << "\\n";\n'
        '    std::cout << static_cast<int>(Color::Green) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'blue\n5\n',
    pitfalls: <String>[
      'enum class 不能隐式转 int，要显式 static_cast。',
      'switch 覆盖所有枚举值时仍建议加 default 以防新增值。',
      '枚举值默认从 0 递增，显式赋值后可跳号。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给枚举加一个 Yellow 并让 name 支持它。',
        hint: '在 switch 里添加 case Color::Yellow。',
        answer: '添加 case 后 name(Color::Yellow) 返回 "yellow"。',
      ),
    ],
  ),
];
