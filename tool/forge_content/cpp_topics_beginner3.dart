import 'forge_topic.dart';

/// C++ beginner track, part 3 of 5: topics 18..26.
const List<ForgeTopic> cppTopicsBeginner3 = <ForgeTopic>[
  ForgeTopic(
    id: 18,
    language: 'cpp',
    level: 'beginner',
    title: '异常入门：throw/try/catch',
    summary: '用异常把错误从发生点传播到处理点，替代返回码。',
    concepts: <String>['throw', 'try', 'catch', '异常传播'],
    objective: '抛出并捕获标准异常，理解异常相较返回码的传播方式。',
    prerequisites: <String>['函数与重载'],
    standard: 'c++17',
    explain:
        '异常把错误与正常流程分离：throw 抛出，沿调用栈向上传播，最近的匹配 catch 处理。'
        '标准库有 std::invalid_argument、std::out_of_range、std::runtime_error 等。'
        'catch (const std::exception& e) 可捕获任何标准异常。',
    code: '#include <iostream>\n#include <stdexcept>\n\n'
        'double safeDiv(double a, double b) {\n'
        '    if (b == 0) throw std::invalid_argument("除数不能为零");\n'
        '    return a / b;\n'
        '}\n\n'
        'int main() {\n'
        '    try {\n'
        '        std::cout << safeDiv(10, 2) << "\\n";\n'
        '        std::cout << safeDiv(1, 0) << "\\n";\n'
        '    } catch (const std::exception& e) {\n'
        '        std::cout << "捕获异常: " << e.what() << "\\n";\n'
        '    }\n'
        '    std::cout << "程序继续\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '5\n捕获异常: 除数不能为零\n程序继续\n',
    pitfalls: <String>[
      'catch 顺序：派生类异常要写在基类前面。',
      '按引用捕获（catch const&），按值会切片。',
      '异常不是控制流，别用它做常规分支。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '在 catch 里再调用一次 safeDiv(4, 2) 打印结果。',
        hint: '异常处理后可以继续正常调用。',
        answer: '输出 2。',
      ),
    ],
  ),
  ForgeTopic(
    id: 19,
    language: 'cpp',
    level: 'beginner',
    title: '多种异常与自定义异常',
    summary: '用多个 catch 分支区分异常类型，并从 std::exception 派生自定义异常。',
    concepts: <String>['多 catch', 'what()', '自定义异常', '继承 std::exception'],
    objective: '捕获不同类型异常并实现自己的异常类。',
    prerequisites: <String>['异常入门：throw/try/catch'],
    standard: 'c++17',
    explain:
        '一个 try 可跟多个 catch，按声明顺序匹配，规则是类型兼容（含基类）。'
        '自定义异常通常继承 std::runtime_error 并传消息，就能被 catch (const std::exception&) 捕获。'
        '捕获基类引用可以统一处理所有标准异常。',
    code: '#include <iostream>\n#include <stdexcept>\n#include <string>\n\n'
        'class BalanceError : public std::runtime_error {\n'
        'public:\n'
        '    explicit BalanceError(const std::string& msg) : std::runtime_error(msg) {}\n'
        '};\n\n'
        'void withdraw(int balance, int amount) {\n'
        '    if (amount > balance) throw BalanceError("余额不足");\n'
        '    std::cout << "取款成功 " << amount << "\\n";\n'
        '}\n\n'
        'int main() {\n'
        '    try {\n'
        '        withdraw(100, 30);\n'
        '        withdraw(100, 200);\n'
        '    } catch (const std::invalid_argument& e) {\n'
        '        std::cout << "参数错误: " << e.what() << "\\n";\n'
        '    } catch (const std::exception& e) {\n'
        '        std::cout << "业务错误: " << e.what() << "\\n";\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: '取款成功 30\n业务错误: 余额不足\n',
    pitfalls: <String>[
      '自定义异常构造函数要传消息给基类。',
      'catch 顺序：更具体的类型写前面。',
      '不要 throw 裸指针，抛出对象或标准异常。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '再加一个 catch (const BalanceError&) 放在最前面，验证匹配。',
        hint: '更具体的类型会被优先匹配。',
        answer: 'BalanceError 分支会先命中，输出自定义消息。',
      ),
    ],
  ),
  ForgeTopic(
    id: 20,
    language: 'cpp',
    level: 'beginner',
    title: '头文件、inline 与编译链接',
    summary: '把声明放进头文件、定义放进源文件，理解 inline 与 ODR。',
    concepts: <String>['头文件', 'inline', 'ODR', '编译与链接'],
    objective: '组织多文件 C++ 程序的思路，理解声明/定义分离。',
    prerequisites: <String>['命名空间'],
    standard: 'c++17',
    explain:
        '头文件放声明（函数原型、类定义、inline 函数、模板），源文件放定义。'
        '同一函数在多个翻译单元里定义会违反 ODR（单一定义规则）。'
        'inline 允许在头文件里定义函数而不违反 ODR。'
        '真实工程会拆成 utils.h + utils.cpp + main.cpp；内容模式要求示例单文件自包含，'
        '因此这里把三部分放在一个文件里说明结构。',
    code: '#include <iostream>\n\n'
        '// 相当于头文件里定义的 inline 函数\n'
        'inline int twice(int x) { return x * 2; }\n'
        'inline int thrice(int x) { return x * 3; }\n\n'
        '// 只声明，定义在后面（对应 .h 声明 + .cpp 定义）\n'
        'int combine(int a, int b);\n\n'
        'int main() {\n'
        '    std::cout << combine(twice(5), thrice(5)) << "\\n";\n'
        '    return 0;\n'
        '}\n\n'
        'int combine(int a, int b) { return a + b; }\n',
    output: '25\n',
    pitfalls: <String>[
      '在头文件里定义非 inline 的普通函数，被多个 .cpp 包含会重复定义。',
      '头文件缺少 include guard 或 #pragma once 会重复展开。',
      '模板和 constexpr 函数默认可以放在头文件里。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 combine 也改成 inline 并思考是否需要。',
        hint: '单文件里 inline 影响不大，多翻译单元才关键。',
        answer: '改成 inline 仍编译通过并输出 25；多文件时能避免重复定义。',
      ),
    ],
  ),
  ForgeTopic(
    id: 21,
    language: 'cpp',
    level: 'beginner',
    title: 'cin 读字符串与 getline',
    summary: '区分 >> 遇空白停止与 getline 读整行的行为。',
    concepts: <String>['std::getline', 'operator>>', '整行输入', '混合读取'],
    objective: '用 getline 读取含空格的整行，并处理与 >> 混用的残留换行。',
    prerequisites: <String>['标准输入：std::cin 读取数据'],
    standard: 'c++17',
    input: 'Alice 25\nHello World\n',
    explain:
        'cin >> 以空白为分隔符，读不到空格；getline(cin, line) 读到换行为止，保留空格。'
        '两者混用时要小心：>> 读完后输入流里可能残留换行，导致随后的 getline 立刻返回空串，'
        '常用 cin.ignore() 清掉。',
    code: '#include <iostream>\n#include <string>\n\n'
        'int main() {\n'
        '    std::string name;\n'
        '    int age = 0;\n'
        '    std::cin >> name >> age;\n'
        '    std::cin.ignore();  // 清掉行尾换行\n'
        '    std::string line;\n'
        '    std::getline(std::cin, line);\n'
        '    std::cout << name << " (" << age << ")\\n";\n'
        '    std::cout << "line: " << line << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'Alice (25)\nline: Hello World\n',
    pitfalls: <String>[
      '>> 后直接 getline 会读到空行，需要先 ignore()。',
      'getline 读到文件末尾时返回的流为假，循环读取要判断。',
      '输入文件末尾没有换行时，最后一行也能被 getline 读出。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '去掉 cin.ignore() 运行，观察 line 输出变化。',
        hint: '残留的换行会被 getline 立刻消费。',
        answer: 'line 变为空串，输出 "line: "。',
      ),
    ],
  ),
  ForgeTopic(
    id: 22,
    language: 'cpp',
    level: 'beginner',
    title: '文件流入门',
    summary: '用 std::ifstream/ofstream 读写文本文件。',
    concepts: <String>['ifstream', 'ofstream', '文件读写', 'RAII 关闭'],
    objective: '打开文件读取内容并写入另一个文件。',
    prerequisites: <String>['cin 读字符串与 getline'],
    standard: 'c++17',
    explain:
        '<fstream> 提供 ifstream（读）、ofstream（写）、fstream（读写）。'
        '文件流是 RAII 对象：离开作用域自动关闭。打开后要检查 is_open() 或直接用 if (file)。'
        'getline(file, line) 逐行读取。',
    code: '#include <fstream>\n#include <iostream>\n#include <string>\n\n'
        'int main() {\n'
        '    const char* path = "sample.txt";\n'
        '    {\n'
        '        std::ofstream out(path);\n'
        '        out << "第一行\\n第二行\\n";\n'
        '    }\n'
        '    std::ifstream in(path);\n'
        '    std::string line;\n'
        '    int count = 0;\n'
        '    while (std::getline(in, line)) {\n'
        '        ++count;\n'
        '        std::cout << count << ": " << line << "\\n";\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: '1: 第一行\n2: 第二行\n',
    pitfalls: <String>[
      '忘记检查文件是否成功打开就读取，会静默失败。',
      '文件流的析构会关闭文件；手动 close 后仍可再次 open。',
      '不同平台换行表示不同，跨平台读文本用文本模式。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把写入的内容改成三行，观察 count 变为 3。',
        hint: '多加一条 out << "...\\n"。',
        answer: 'count 变为 3，逐行打印三行。',
      ),
    ],
  ),
  ForgeTopic(
    id: 23,
    language: 'cpp',
    level: 'beginner',
    title: 'std::optional 入门',
    summary: '用 std::optional 表达“可能有值”，避免哨兵值和空指针。',
    concepts: <String>['std::optional', 'has_value', 'value_or', '空值表示'],
    objective: '用 optional 返回可能缺失的结果并安全取值。',
    prerequisites: <String>['异常入门：throw/try/catch'],
    standard: 'c++17',
    explain:
        'std::optional<T> 要么持有 T，要么为空。它比用 -1 或 nullptr 表达“无值”更清晰、类型安全。'
        'has_value() 判断，value() 取值（空时抛 bad_optional_access），value_or(default) 给默认值，'
        '*opt 解引用。适合解析、查找这类可能失败的函数。',
    code: '#include <iostream>\n#include <optional>\n#include <string>\n\n'
        'std::optional<int> parseInt(const std::string& s) {\n'
        '    try {\n'
        '        return std::stoi(s);\n'
        '    } catch (...) {\n'
        '        return std::nullopt;\n'
        '    }\n'
        '}\n\n'
        'int main() {\n'
        '    auto a = parseInt("42");\n'
        '    auto b = parseInt("abc");\n'
        '    std::cout << (a.has_value() ? std::to_string(*a) : "none") << "\\n";\n'
        '    std::cout << (b.has_value() ? std::to_string(*b) : "none") << "\\n";\n'
        '    std::cout << b.value_or(-1) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '42\nnone\n-1\n',
    pitfalls: <String>[
      '对空的 optional 调 value() 会抛异常，用 value_or 或先判断。',
      'optional<optional<T>> 嵌套一般没必要。',
      'optional 有额外一个 bool 的开销，别在热路径滥用。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 optional 写一个函数返回字符串长度，空串返回 nullopt。',
        hint: 'if (s.empty()) return std::nullopt;',
        answer: '空串返回 nullopt，非空返回长度。',
      ),
    ],
  ),
  ForgeTopic(
    id: 24,
    language: 'cpp',
    level: 'beginner',
    title: 'std::string_view 入门',
    summary: '用 string_view 以零拷贝方式引用字符串片段。',
    concepts: <String>['std::string_view', '零拷贝', '只读视图', '生命周期'],
    objective: '用 string_view 做只读字符串参数，避免拷贝与临时 string。',
    prerequisites: <String>['std::string 基础'],
    standard: 'c++17',
    explain:
        'std::string_view 是对已有字符序列的只读视图，持有指针和长度，不拥有数据、不拷贝。'
        '它适合函数参数（可同时接受 string 和字面量）。关键约束：它不延长底层数据的生命周期，'
        '不能返回指向局部 string 的 view。',
    code: '#include <iostream>\n#include <string>\n#include <string_view>\n\n'
        'std::size_t countVowels(std::string_view s) {\n'
        '    std::size_t n = 0;\n'
        '    for (char c : s) {\n'
        '        if (c == \'a\' || c == \'e\' || c == \'i\' || c == \'o\' || c == \'u\')\n'
        '            ++n;\n'
        '    }\n'
        '    return n;\n'
        '}\n\n'
        'int main() {\n'
        '    std::string word = "hello";\n'
        '    std::cout << countVowels(word) << "\\n";\n'
        '    std::cout << countVowels("beautiful") << "\\n";\n'
        '    std::string_view sv = word;\n'
        '    sv.remove_prefix(1);\n'
        '    std::cout << sv << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '2\n5\nello\n',
    pitfalls: <String>[
      'view 不拥有数据，底层 string 销毁后 view 悬空。',
      'string_view 不含结尾 \\0，传给 C 接口要小心。',
      '不要返回指向局部 std::string 的 string_view。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 sv.substr(0, 3) 打印前三个字符。',
        hint: 'substr 返回子 view。',
        answer: '对 "hello" 输出 "hel"。',
      ),
    ],
  ),
  ForgeTopic(
    id: 25,
    language: 'cpp',
    level: 'beginner',
    title: '算法入门：sort/find/count',
    summary: '用 <algorithm> 的 std::sort、std::find、std::count 处理序列。',
    concepts: <String>['std::sort', 'std::find', 'std::count', '迭代器范围'],
    objective: '对容器调用标准算法，理解 [begin, end) 范围约定。',
    prerequisites: <String>['std::vector：动态数组'],
    standard: 'c++17',
    explain:
        '<algorithm> 提供大量作用于迭代器区间的算法，约定是左闭右开 [first, last)。'
        'std::sort 排序，std::find 查找返回迭代器，std::count 统计出现次数。'
        '它们与容器解耦，vector、array、甚至裸数组都能用。',
    code: '#include <algorithm>\n#include <iostream>\n#include <vector>\n\n'
        'int main() {\n'
        '    std::vector<int> v = {5, 2, 9, 1, 9, 3};\n'
        '    std::sort(v.begin(), v.end());\n'
        '    for (int x : v) std::cout << x << " ";\n'
        '    std::cout << "\\n";\n'
        '    auto it = std::find(v.begin(), v.end(), 9);\n'
        '    std::cout << "found " << *it << "\\n";\n'
        '    std::cout << "count 9 = " << std::count(v.begin(), v.end(), 9) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '1 2 3 5 9 9 \nfound 9\ncount 9 = 2\n',
    pitfalls: <String>[
      'find 未找到返回 end()，解引用 end() 是未定义行为。',
      'sort 默认升序，降序用 std::greater<>{}。',
      '算法作用在迭代器范围，不检查容器大小是否匹配。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 std::sort 加 std::greater<int>{} 把 v 降序排列。',
        hint: 'std::sort(v.begin(), v.end(), std::greater<int>{});',
        answer: '输出 9 9 5 3 2 1。',
      ),
    ],
  ),
  ForgeTopic(
    id: 26,
    language: 'cpp',
    level: 'beginner',
    title: 'lambda 入门',
    summary: '用匿名函数对象捕获上下文，传给算法做比较或变换。',
    concepts: <String>['lambda', '捕获列表', '按值/按引用捕获', '可调用对象'],
    objective: '编写 lambda 并作为算法谓词使用，理解捕获方式。',
    prerequisites: <String>['算法入门：sort/find/count'],
    standard: 'c++17',
    explain:
        'lambda 是就地定义的可调用对象：[](参数){ 体 }。方括号是捕获列表：[x] 按值捕获，'
        '[&x] 按引用，[=] 全部按值，[&] 全部按引用。它常作为算法的谓词（比较、过滤）。'
        '捕获时要小心悬空引用（尤其异步/延迟调用）。',
    code: '#include <algorithm>\n#include <iostream>\n#include <vector>\n\n'
        'int main() {\n'
        '    std::vector<int> v = {3, 1, 4, 1, 5, 9, 2, 6};\n'
        '    std::sort(v.begin(), v.end(), [](int a, int b) { return a > b; });\n'
        '    for (int x : v) std::cout << x << " ";\n'
        '    std::cout << "\\n";\n\n'
        '    int threshold = 4;\n'
        '    int above = std::count_if(v.begin(), v.end(),\n'
        '                              [threshold](int x) { return x > threshold; });\n'
        '    std::cout << "above " << threshold << " = " << above << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '9 6 5 4 3 2 1 1 \nabove 4 = 3\n',
    pitfalls: <String>[
      '按引用捕获的变量若在 lambda 调用前销毁会悬空。',
      'mutable 才允许修改按值捕获的副本。',
      '捕获 this 时注意对象生命周期。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把阈值改成 5，观察 above 变化。',
        hint: '只有 9 6 大于 5。',
        answer: 'above 5 = 2。',
      ),
    ],
  ),
];
