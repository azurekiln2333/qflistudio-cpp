import 'forge_topic.dart';

/// C++ advanced track, part 1 of 4: topics 76..82.
const List<ForgeTopic> cppTopicsAdvanced1 = <ForgeTopic>[
  ForgeTopic(
    id: 76,
    language: 'cpp',
    level: 'advanced',
    title: '类型特征 type_traits',
    summary: '用 <type_traits> 在编译期查询和变换类型。',
    concepts: <String>['type_traits', 'is_integral', 'enable_if', '编译期分支'],
    objective: '用类型特征在编译期做类型判断与条件实例化。',
    prerequisites: <String>['模板特化'],
    standard: 'c++17',
    explain:
        '<type_traits> 提供 is_integral、is_floating_point、is_same、remove_reference 等'
        '编译期类型查询与变换。它们配合 if constexpr 或 SFINAE 实现按类型选择实现。'
        '类型特征是模板元编程与泛型库的基础设施。',
    code: '#include <iostream>\n#include <type_traits>\n\n'
        'template <typename T>\n'
        'void describe() {\n'
        '    if constexpr (std::is_integral_v<T>) {\n'
        '        std::cout << "integral\\n";\n'
        '    } else if constexpr (std::is_floating_point_v<T>) {\n'
        '        std::cout << "floating point\\n";\n'
        '    } else {\n'
        '        std::cout << "other\\n";\n'
        '    }\n'
        '}\n\n'
        'int main() {\n'
        '    describe<int>();\n'
        '    describe<double>();\n'
        '    describe<char*>();\n'
        '    std::cout << std::is_same_v<int, int> << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'integral\nfloating point\nother\n1\n',
    pitfalls: <String>[
      'if constexpr 是编译期分支，未选中分支也会被解析但不会实例化。',
      '用 _v 后缀变体（is_integral_v）更简洁。',
      '类型特征是编译期常量，不要用运行期 if。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 std::remove_reference_t<int&> 打印类型是否与 int 相同。',
        hint: '配合 std::is_same_v。',
        answer: 'is_same_v<remove_reference_t<int&>, int> 为 1。',
      ),
    ],
  ),
  ForgeTopic(
    id: 77,
    language: 'cpp',
    level: 'advanced',
    title: '可变参数模板与折叠表达式',
    summary: '用可变参数模板接受任意数量参数，用折叠表达式统一处理。',
    concepts: <String>['可变参数模板', 'parameter pack', '折叠表达式', 'C++17'],
    objective: '编写可变参数函数并用折叠表达式求和。',
    prerequisites: <String>['类型特征 type_traits'],
    standard: 'c++17',
    explain:
        '模板参数包（typename... Ts）和函数参数包（Ts... args）让函数接受任意数量参数。'
        'C++17 的折叠表达式 (args + ...) 把包展开为连续的运算符序列，'
        '简洁地实现求和、打印等聚合。',
    code: '#include <iostream>\n\n'
        'template <typename... Ts>\n'
        'auto sum(Ts... args) { return (args + ...); }\n\n'
        'template <typename... Ts>\n'
        'void printAll(const Ts&... args) {\n'
        '    ((std::cout << args << " "), ...);\n'
        '    std::cout << "\\n";\n'
        '}\n\n'
        'int main() {\n'
        '    std::cout << sum(1, 2, 3, 4) << "\\n";\n'
        '    std::cout << sum(1.5, 2.5) << "\\n";\n'
        '    printAll("a", 1, 2.5);\n'
        '    return 0;\n'
        '}\n',
    output: '10\n4\na 1 2.5 \n',
    pitfalls: <String>[
      '空参数包时折叠表达式需要初值（0 + ... + args）。',
      '折叠的运算符优先级与结合性要看清左折/右折。',
      '混用不同类型时推导出的返回类型可能出乎意料。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个 countArgs() 返回参数个数。',
        hint: 'return sizeof...(Ts);',
        answer: 'countArgs(1,2,3) 返回 3。',
      ),
    ],
  ),
  ForgeTopic(
    id: 78,
    language: 'cpp',
    level: 'advanced',
    title: 'concepts：C++20 约束',
    summary: '用 concept 为模板参数声明语义约束，得到清晰的编译错误。',
    concepts: <String>['concept', 'requires', 'C++20', '约束'],
    objective: '定义 concept 并约束模板参数。',
    prerequisites: <String>['可变参数模板与折叠表达式'],
    standard: 'c++20',
    explain:
        'C++20 的 concept 为一组类型要求命名，既能约束模板参数、又能在错误信息里'
        '给出人类可读的约束名。std::integral、std::floating_point 等标准 concept '
        '可直接使用。它是取代笨重 SFINAE 的现代方式。',
    code: '#include <concepts>\n#include <iostream>\n#include <string>\n\n'
        'template <std::integral T>\n'
        'T twice(T x) { return x * 2; }\n\n'
        'template <typename T>\n'
        'concept Printable = requires(T x) { std::cout << x; };\n\n'
        'template <Printable T>\n'
        'void show(const T& x) { std::cout << x << "\\n"; }\n\n'
        'int main() {\n'
        '    std::cout << twice(21) << "\\n";\n'
        '    show(42);\n'
        '    show(std::string("hi"));\n'
        '    return 0;\n'
        '}\n',
    output: '42\n42\nhi\n',
    pitfalls: <String>[
      'concept 需要 C++20 及支持它的编译器（WSL clang 18 / g++ 13 可用）。',
      'requires 表达式只检查表达式是否合法，不检查语义。',
      '约束越精确，错误信息越友好，但可复用性可能下降。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '定义 concept Addable，约束两种类型可相加。',
        hint: 'requires(T a, U b) { a + b; }',
        answer: 'Addable<int,double> 满足，Addable<int,void*> 不满足。',
      ),
    ],
  ),
  ForgeTopic(
    id: 79,
    language: 'cpp',
    level: 'advanced',
    title: 'requires 子句与重载选择',
    summary: '用 requires 子句让重载按类型能力自动选择。',
    concepts: <String>['requires 子句', '重载解析', '约束偏序', '能力选择'],
    objective: '用 requires 子句实现按能力分派的重载。',
    prerequisites: <String>['concepts：C++20 约束'],
    standard: 'c++20',
    explain:
        'requires 子句跟在模板后约束该重载何时可用。多个重载都可行时，'
        '编译器选择约束更强（更特化）的那个，这叫约束偏序。'
        '它让“能加就用加法、否则用拼接”这类分派变得声明式。',
    code: '#include <concepts>\n#include <iostream>\n#include <string>\n\n'
        'template <typename T>\n'
        'requires std::integral<T>\n'
        'T combine(T a, T b) { return a + b; }\n\n'
        'template <typename T>\n'
        'requires (!std::integral<T>)\n'
        'T combine(const T& a, const T& b) { return a + b; }\n\n'
        'int main() {\n'
        '    std::cout << combine(3, 4) << "\\n";\n'
        '    std::cout << combine(std::string("foo"), std::string("bar")) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '7\nfoobar\n',
    pitfalls: <String>[
      'requires 子句里的表达式必须只依赖模板参数。',
      '多个重载都不满足或都同样特化会产生歧义。',
      '约束应表达语义意图，而不只是语法可用。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '再加一个针对浮点的 combine 实现并观察选择。',
        hint: 'requires std::floating_point<T>。',
        answer: '浮点调用会命中浮点重载。',
      ),
    ],
  ),
  ForgeTopic(
    id: 80,
    language: 'cpp',
    level: 'advanced',
    title: '完美转发',
    summary: '用转发引用与 std::forward 保持实参的值类别与常量性。',
    concepts: <String>['转发引用', 'std::forward', '值类别', '包装函数'],
    objective: '编写把实参原样转发给下层函数的包装函数。',
    prerequisites: <String>['requires 子句与重载选择'],
    standard: 'c++20',
    explain:
        'T&& 在模板推导中成为转发引用：传左值时 T 推导为左值引用，传右值时推导为非引用。'
        'std::forward<T>(arg) 按原值类别转发，左值仍为左值、右值仍为右值，'
        '从而让被包装函数正确选择拷贝或移动。',
    code: '#include <iostream>\n#include <string>\n#include <utility>\n\n'
        'void sink(const std::string& s) { std::cout << "copy: " << s << "\\n"; }\n'
        'void sink(std::string&& s) { std::cout << "move: " << s << "\\n"; }\n\n'
        'template <typename T>\n'
        'void wrapper(T&& arg) { sink(std::forward<T>(arg)); }\n\n'
        'int main() {\n'
        '    std::string a = "hello";\n'
        '    wrapper(a);\n'
        '    wrapper(std::string("world"));\n'
        '    return 0;\n'
        '}\n',
    output: 'copy: hello\nmove: world\n',
    pitfalls: <String>[
      '转发引用要求形如 T&& 且 T 是推导出来的模板参数。',
      '转发后不要再用被移动的对象。',
      'std::forward 与 std::move 不同：前者保留值类别，后者强制右值。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 wrapper 包装一个只接 const& 的函数，观察是否仍能编译。',
        hint: '转发会保持左值性。',
        answer: '能编译，const& 版本被选中。',
      ),
    ],
  ),
  ForgeTopic(
    id: 81,
    language: 'cpp',
    level: 'advanced',
    title: '值类别：左值与右值',
    summary: '区分 lvalue/xvalue/prvalue，理解移动与绑定的前提。',
    concepts: <String>['值类别', 'lvalue', 'rvalue', 'decltype'],
    objective: '判断表达式的值类别并解释移动发生的条件。',
    prerequisites: <String>['完美转发'],
    standard: 'c++20',
    explain:
        '值类别刻画表达式的“身份”和“可移动性”：左值有名字、可取地址；'
        '右值（纯右值/将亡值）通常是临时或即将销毁的对象。'
        '移动只在绑定到右值时发生。理解值类别是看懂移动/转发/重载选择的关键。',
    code: '#include <iostream>\n#include <type_traits>\n#include <utility>\n\n'
        'int main() {\n'
        '    int a = 1;\n'
        '    std::cout << std::is_lvalue_reference_v<decltype((a))> << "\\n";\n'
        '    std::cout << std::is_rvalue_reference_v<decltype((std::move(a)))> << "\\n";\n'
        '    std::cout << std::is_lvalue_reference_v<decltype((1 + 2))> << "\\n";\n'
        '    int&& r = 5;\n'
        '    std::cout << r << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '1\n1\n0\n5\n',
    pitfalls: <String>[
      '具名的右值引用变量本身是左值（r 可被取地址）。',
      'decltype((x)) 与 decltype(x) 不同：前者是引用类型。',
      '返回局部变量的 std::move 会阻止拷贝省略，反而更慢。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '打印 decltype((std::move(a))) 是否与 int&& 相同。',
        hint: '用 is_same_v。',
        answer: 'is_same_v<decltype((std::move(a))), int&&> 为 1。',
      ),
    ],
  ),
  ForgeTopic(
    id: 82,
    language: 'cpp',
    level: 'advanced',
    title: 'SFINAE 到 concepts 的演进',
    summary: '理解 SFINAE 的历史做法，以及 concepts 如何取代它。',
    concepts: <String>['SFINAE', 'enable_if', '替换失败', '演化'],
    objective: '解释 SFINAE 原理并对比 concepts 的可读性优势。',
    prerequisites: <String>['值类别：左值与右值'],
    standard: 'c++20',
    explain:
        'SFINAE（替换失败并非错误）允许通过让某些模板在参数不满足时“无声失败”'
        '来筛选重载，典型是 std::enable_if。它强大但难以阅读与调试。'
        'concepts 用声明式约束表达同样意图，错误信息清晰得多，是 C++20 的推荐做法。',
    code: '#include <iostream>\n#include <type_traits>\n\n'
        '// 老式 SFINAE：只有整型才启用\n'
        'template <typename T>\n'
        'std::enable_if_t<std::is_integral_v<T>, T> oldDouble(T x) { return x * 2; }\n\n'
        '// 现代 concepts 等价写法（见前几课）\n'
        'template <typename T>\n'
        'requires std::is_integral_v<T>\n'
        'T newDouble(T x) { return x * 2; }\n\n'
        'int main() {\n'
        '    std::cout << oldDouble(5) << "\\n";\n'
        '    std::cout << newDouble(5) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '10\n10\n',
    pitfalls: <String>[
      'SFINAE 只在“直接上下文”的替换失败中生效，函数体内的错误仍是硬错误。',
      'enable_if 的写法难读，新代码优先用 concepts。',
      '不要把 SFINAE 用在只想做运行期判断的地方。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 oldDouble 传一个 double，观察编译错误信息。',
        hint: 'SFINAE 会让重载被移除，报“没有匹配的重载”。',
        answer: '编译器报找不到匹配函数，错误信息不如 concept 清晰。',
      ),
    ],
  ),
];
