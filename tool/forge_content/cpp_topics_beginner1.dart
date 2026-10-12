import 'forge_topic.dart';

/// C++ beginner track, part 1 of 5: topics 1..8.
///
/// Distinct from the C beginner track: teaches the C++ language surface
/// (iostream, references, auto, std::string/vector, range-for, overloads)
/// rather than repeating the C subset with a swapped snippet. Every sample is
/// self-contained, targets C++ <= c++20, and prints deterministic output.
const List<ForgeTopic> cppTopicsBeginner1 = <ForgeTopic>[
  ForgeTopic(
    id: 1,
    language: 'cpp',
    level: 'beginner',
    title: '第一个 C++ 程序：iostream 与流式输出',
    summary: '用 std::cout 和 << 运算符打印文本，理解 C++ 的流式 I/O 模型。',
    concepts: <String>['iostream', 'std::cout', 'operator<<', 'main 返回值'],
    objective: '写出并运行一个使用 std::cout 输出文本的 C++ 程序，理解 << 是流插入运算符。',
    standard: 'c++17',
    explain:
        'C++ 用 <iostream> 提供标准输入输出流，std::cout 是标准输出流对象。'
        '<< 是被重载的流插入运算符，把右侧的值插入左侧的流，可以链式串联。'
        '\\n 表示换行，std::endl 也能换行并额外刷新缓冲区。main 返回 0 表示正常结束。',
    code: '#include <iostream>\n\n'
        'int main() {\n'
        '    std::cout << "Hello, C++!" << std::endl;\n'
        '    std::cout << "一加一等于 " << 1 + 1 << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'Hello, C++!\n一加一等于 2\n',
    pitfalls: <String>[
      '忘记包含 <iostream>，或误用已废弃的 <iostream.h>。',
      '把 << 和 >> 弄反：输出用 <<，输入用 >>。',
      'std::endl 会刷新缓冲区，大量输出时比 "\\n" 慢。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '修改程序，让它先打印你的名字，再打印结果。',
        hint: '再加一条 std::cout 语句即可。',
        answer: '在第一条输出前插入 std::cout << "你的名字\\n";。',
      ),
    ],
  ),
  ForgeTopic(
    id: 2,
    language: 'cpp',
    level: 'beginner',
    title: '变量与引用：值和别名',
    summary: '声明基本类型变量，并理解引用是已存在对象的别名而非拷贝。',
    concepts: <String>['变量', '引用', '& 声明符', '初始化'],
    objective: '声明基本类型变量，并通过引用修改原对象。',
    prerequisites: <String>['第一个 C++ 程序'],
    standard: 'c++17',
    explain:
        '声明变量时给出类型和名字：int age = 18;。引用用 & 声明，'
        '必须在定义时绑定到一个已存在的对象，之后就是那个对象的别名——'
        '通过引用赋值等于修改原对象，不产生拷贝。引用不能为空，也不能重新绑定。',
    code: '#include <iostream>\n\n'
        'int main() {\n'
        '    int count = 3;\n'
        '    int& ref = count;   // ref 是 count 的别名\n'
        '    ref = 10;           // 等价于 count = 10\n'
        '    std::cout << "count = " << count << "\\n";\n'
        '    ref += 5;\n'
        '    std::cout << "count = " << count << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'count = 10\ncount = 15\n',
    pitfalls: <String>[
      '引用必须初始化，int& r; 是编译错误。',
      '把 & 写到类型后（int &r）或变量前（int& r）都合法，风格要统一。',
      '不要返回局部变量的引用，会悬空。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '再声明一个引用 ref2 也绑定到 count，通过 ref2 把它加 1。',
        hint: 'int& ref2 = count; ref2++;',
        answer: 'int& ref2 = count; ref2++; 之后 count 变为 16。',
      ),
    ],
  ),
  ForgeTopic(
    id: 3,
    language: 'cpp',
    level: 'beginner',
    title: 'auto 与类型推导',
    summary: '用 auto 让编译器从初始化式推导类型，避免冗长且易错的类型书写。',
    concepts: <String>['auto', '类型推导', '字面量后缀', 'sizeof'],
    objective: '使用 auto 声明变量并解释编译器推导出的真实类型。',
    prerequisites: <String>['变量与引用'],
    standard: 'c++17',
    explain:
        'auto 让编译器根据初始化表达式推导变量类型，必须有初始化式。'
        'auto x = 1; 推导为 int，auto y = 1.5; 推导为 double，auto z = 1.5f; 推导为 float。'
        '它减少重复、避免把 long 写成 int 这类错误，但不会做隐式转换——结果完全取决于表达式。',
    code: '#include <iostream>\n\n'
        'int main() {\n'
        '    auto i = 42;\n'
        '    auto d = 3.5;\n'
        '    auto l = 42L;\n'
        '    auto c = \'x\';\n'
        '    std::cout << "i=" << i << " " << (sizeof(i) == sizeof(int)) << "\\n";\n'
        '    std::cout << "d=" << d << " " << (sizeof(d) == sizeof(double)) << "\\n";\n'
        '    std::cout << "l=" << l << "\\n";\n'
        '    std::cout << "c=" << c << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'i=42 1\nd=3.5 1\nl=42\nc=x\n',
    pitfalls: <String>[
      'auto 必须有初始化式，auto x; 无法推导。',
      'auto 默认按值（拷贝），auto& 才是引用。',
      '整数除法：auto r = 7 / 2; 推导为 int，结果是 3 而非 3.5。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 auto 声明一个变量保存 7 / 2.0 的结果并打印。',
        hint: '7 / 2.0 中有一个 double，结果为 double。',
        answer: 'auto r = 7 / 2.0; 打印 3.5。',
      ),
    ],
  ),
  ForgeTopic(
    id: 4,
    language: 'cpp',
    level: 'beginner',
    title: '标准输入：std::cin 读取数据',
    summary: '用 >> 从标准输入读取整数，理解空白分隔与输入失败。',
    concepts: <String>['std::cin', 'operator>>', '空白分隔', '输入失败'],
    objective: '从标准输入读取多个值并计算，理解 >> 会自动跳过空白。',
    prerequisites: <String>['第一个 C++ 程序'],
    standard: 'c++17',
    input: '7 35\n',
    explain:
        'std::cin 是标准输入流，>> 是流提取运算符，按目标类型解析输入并自动跳过前导空白。'
        'cin >> a >> b; 可以连续读取。读取失败（格式不符或到末尾）会使流进入失败状态，'
        '可用 if (cin >> x) 判断。本课程用项目根目录的 input.txt 作为标准输入。',
    code: '#include <iostream>\n\n'
        'int main() {\n'
        '    int a = 0, b = 0;\n'
        '    if (std::cin >> a >> b) {\n'
        '        std::cout << a << " + " << b << " = " << a + b << "\\n";\n'
        '    } else {\n'
        '        std::cout << "读取失败\\n";\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: '7 + 35 = 42\n',
    pitfalls: <String>[
      '忘记判断读取是否成功，失败时会用旧值继续算。',
      'cin >> string 遇到空白就停，读整行要用 getline。',
      '方向易混：输入流用 >>。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把输入改成两个数，让程序输出它们的乘积。',
        hint: '把 a + b 改成 a * b。',
        answer: '改表达式为 a * b，输入 7 35 时输出 245。',
      ),
    ],
  ),
  ForgeTopic(
    id: 5,
    language: 'cpp',
    level: 'beginner',
    title: 'std::string 基础',
    summary: '用 std::string 保存文本，进行拼接、取长度和下标访问。',
    concepts: <String>['std::string', 'size()', 'operator+', 'operator[]'],
    objective: '创建并操作 std::string，完成拼接、长度与字符访问。',
    prerequisites: <String>['变量与引用'],
    standard: 'c++17',
    explain:
        'std::string 是标准库的字符串类型，自动管理内存，不必像 C 的 char[] 那样关心长度。'
        'size() 返回字符个数，+ 拼接，+= 追加，[] 按下标访问（不检查越界），at() 会检查并抛异常。'
        '它是本课程推荐的文本类型，替代裸 char 数组。',
    code: '#include <iostream>\n#include <string>\n\n'
        'int main() {\n'
        '    std::string first = "Hello";\n'
        '    std::string second = "World";\n'
        '    std::string greeting = first + ", " + second + "!";\n'
        '    std::cout << greeting << "\\n";\n'
        '    std::cout << "长度 " << greeting.size() << "\\n";\n'
        '    std::cout << "首字符 " << greeting[0] << "\\n";\n'
        '    greeting += " 再见";\n'
        '    std::cout << greeting << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'Hello, World!\n长度 13\n首字符 H\nHello, World! 再见\n',
    pitfalls: <String>[
      'size() 返回无符号类型，与 int 比较时可能触发符号警告。',
      '[] 越界是未定义行为，需要检查时用 at()。',
      '"a" + "b" 是两个 const char*，不能相加；至少一边是 std::string。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 greeting.front() 和 greeting.back() 打印首尾字符。',
        hint: 'front()/back() 是 C++11 起的便捷成员。',
        answer: 'std::cout << greeting.front() << greeting.back();',
      ),
    ],
  ),
  ForgeTopic(
    id: 6,
    language: 'cpp',
    level: 'beginner',
    title: 'std::vector：动态数组',
    summary: '用 std::vector 保存数量可变的元素，完成增删与遍历。',
    concepts: <String>['std::vector', 'push_back', 'size()', '下标'],
    objective: '创建 vector、追加元素、按下标与遍历读取。',
    prerequisites: <String>['auto 与类型推导'],
    standard: 'c++17',
    explain:
        'std::vector 是会自动扩容的动态数组，是最常用的容器。push_back 在末尾追加，'
        'size() 返回元素个数，[] 随机访问，pop_back 删除末尾。它连续存储元素，'
        '因此也能与 C 风格接口对接。大括号初始化 {1, 2, 3} 直接给出初始元素。',
    code: '#include <iostream>\n#include <vector>\n\n'
        'int main() {\n'
        '    std::vector<int> nums = {10, 20, 30};\n'
        '    nums.push_back(40);\n'
        '    std::cout << "size=" << nums.size() << "\\n";\n'
        '    int sum = 0;\n'
        '    for (std::size_t i = 0; i < nums.size(); ++i) sum += nums[i];\n'
        '    std::cout << "sum=" << sum << "\\n";\n'
        '    nums.pop_back();\n'
        '    std::cout << "last=" << nums.back() << " size=" << nums.size() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'size=4\nsum=100\nlast=30 size=3\n',
    pitfalls: <String>[
      '扩容后原有元素的迭代器/引用可能失效。',
      'vector 下标不检查越界；需要检查用 at()。',
      'vector<bool> 是位压缩的特化，取地址行为与普通 vector 不同。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '在末尾再追加一个 50，打印新的 sum。',
        hint: 'push_back(50) 后重新求和。',
        answer: '追加 50 后 sum=150。',
      ),
    ],
  ),
  ForgeTopic(
    id: 7,
    language: 'cpp',
    level: 'beginner',
    title: 'range-for：范围循环',
    summary: '用 for (auto x : container) 遍历容器，避免手写下标。',
    concepts: <String>['range-for', 'auto&', 'const auto&', '遍历'],
    objective: '用范围循环遍历 vector，并区分按值、按引用遍历。',
    prerequisites: <String>['std::vector：动态数组'],
    standard: 'c++17',
    explain:
        'for (auto x : v) 把每个元素拷贝到 x；for (auto& x : v) 直接引用元素，'
        '修改 x 会改到容器；for (const auto& x : v) 只读且不拷贝，是遍历大对象的最佳实践。'
        '范围循环可读性远高于手写下标，且不会越界。',
    code: '#include <iostream>\n#include <vector>\n\n'
        'int main() {\n'
        '    std::vector<int> v = {1, 2, 3, 4};\n'
        '    for (int x : v) std::cout << x << " ";\n'
        '    std::cout << "\\n";\n'
        '    for (int& x : v) x *= 10;\n'
        '    for (const auto& x : v) std::cout << x << " ";\n'
        '    std::cout << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '1 2 3 4 \n10 20 30 40 \n',
    pitfalls: <String>[
      'for (auto x : v) 想修改元素却写成了拷贝，改动不生效。',
      '遍历时修改容器大小（push_back/erase）会使迭代器失效。',
      '遍历字符串得到的是 char，不是 string。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用范围循环统计 v 中偶数的个数。',
        hint: 'for (const auto& x : v) if (x % 2 == 0) ++count;',
        answer: '遍历累加偶数计数，10/20/30/40 中全是偶数，结果为 4。',
      ),
    ],
  ),
  ForgeTopic(
    id: 8,
    language: 'cpp',
    level: 'beginner',
    title: '函数与重载',
    summary: '定义函数并利用重载让同名函数按参数类型/个数提供服务。',
    concepts: <String>['函数', '重载', '参数', '返回值'],
    objective: '编写同名不同参数列表的函数并在调用时正确解析。',
    prerequisites: <String>['变量与引用'],
    standard: 'c++17',
    explain:
        'C++ 允许同名函数因为参数列表不同而共存，这叫重载。编译器按实参的类型和个数'
        '选择最匹配的那个。重载只能靠参数列表区分，不能只靠返回值类型。'
        '函数在使用前必须有声明或定义。',
    code: '#include <iostream>\n\n'
        'int add(int a, int b) { return a + b; }\n'
        'double add(double a, double b) { return a + b; }\n'
        'int add(int a, int b, int c) { return a + b + c; }\n\n'
        'int main() {\n'
        '    std::cout << add(2, 3) << "\\n";\n'
        '    std::cout << add(2.5, 3.5) << "\\n";\n'
        '    std::cout << add(1, 2, 3) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '5\n6\n6\n',
    pitfalls: <String>[
      '只改返回值类型不能构成重载。',
      'add(2, 3.5) 会触发歧义或意外转换，注意实参类型。',
      '重载解析在存在隐式转换时可能出乎意料。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '再加一个重载 add(std::string, std::string) 拼接字符串。',
        hint: '包含 <string>，返回 a + b。',
        answer: 'std::string add(std::string a, std::string b){return a+b;}',
      ),
    ],
  ),
];
