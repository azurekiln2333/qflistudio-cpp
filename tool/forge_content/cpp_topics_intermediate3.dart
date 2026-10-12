import 'forge_topic.dart';

/// C++ intermediate track, part 3 of 6: topics 49..55.
const List<ForgeTopic> cppTopicsIntermediate3 = <ForgeTopic>[
  ForgeTopic(
    id: 49,
    language: 'cpp',
    level: 'intermediate',
    title: 'shared_ptr 与 weak_ptr',
    summary: '用 shared_ptr 共享所有权，用 weak_ptr 打破循环引用。',
    concepts: <String>['shared_ptr', 'weak_ptr', '引用计数', '循环引用'],
    objective: '用 shared_ptr 共享对象并观察引用计数，用 weak_ptr 观测不持有。',
    prerequisites: <String>['unique_ptr：独占所有权'],
    standard: 'c++17',
    explain:
        'std::shared_ptr<T> 用引用计数共享所有权，最后一个 shared_ptr 销毁时释放对象。'
        'std::weak_ptr 指向 shared_ptr 管理的对象但不增加计数，用于打破循环引用或做缓存。'
        'shared_ptr 有计数开销，能用 unique_ptr 就别用 shared_ptr。',
    code: '#include <iostream>\n#include <memory>\n\n'
        'int main() {\n'
        '    auto a = std::make_shared<int>(42);\n'
        '    std::cout << "count=" << a.use_count() << "\\n";\n'
        '    {\n'
        '        auto b = a;\n'
        '        std::cout << "count=" << a.use_count() << "\\n";\n'
        '    }\n'
        '    std::cout << "count=" << a.use_count() << "\\n";\n'
        '    std::weak_ptr<int> w = a;\n'
        '    if (auto locked = w.lock()) {\n'
        '        std::cout << "locked=" << *locked << "\\n";\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: 'count=1\ncount=2\ncount=1\nlocked=42\n',
    pitfalls: <String>[
      '两个对象互相用 shared_ptr 会导致循环引用、永不释放，改用 weak_ptr。',
      'weak_ptr 使用前要 lock() 检查对象是否还活着。',
      '不要用同一个裸指针构造两个独立的 shared_ptr（会双重释放）。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '复制一个 shared_ptr 到新变量，观察 use_count 变化。',
        hint: 'auto c = a; 会让计数加一。',
        answer: '计数从 1 变为 2，c 销毁后回到 1。',
      ),
    ],
  ),
  ForgeTopic(
    id: 50,
    language: 'cpp',
    level: 'intermediate',
    title: '算法：transform 与 accumulate',
    summary: '用 std::transform 映射元素、std::accumulate 归约序列。',
    concepts: <String>['std::transform', 'std::accumulate', 'map/reduce', '初始值'],
    objective: '用 transform 做映射、accumulate 做归约。',
    prerequisites: <String>['lambda 入门'],
    standard: 'c++17',
    explain:
        'std::transform 把输入区间每个元素经函数映射到输出区间；'
        'std::accumulate（在 <numeric>）用一个初值和二元操作把区间归约成单值。'
        '两者是 map/reduce 的原型，配合 lambda 表达力很强。',
    code: '#include <algorithm>\n#include <iostream>\n#include <numeric>\n#include <vector>\n\n'
        'int main() {\n'
        '    std::vector<int> v = {1, 2, 3, 4};\n'
        '    std::vector<int> squared(v.size());\n'
        '    std::transform(v.begin(), v.end(), squared.begin(),\n'
        '                   [](int x) { return x * x; });\n'
        '    for (int x : squared) std::cout << x << " ";\n'
        '    std::cout << "\\n";\n'
        '    int sum = std::accumulate(v.begin(), v.end(), 0);\n'
        '    std::cout << "sum=" << sum << "\\n";\n'
        '    int product = std::accumulate(v.begin(), v.end(), 1,\n'
        '                                  [](int a, int b) { return a * b; });\n'
        '    std::cout << "product=" << product << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '1 4 9 16 \nsum=10\nproduct=24\n',
    pitfalls: <String>[
      'accumulate 的初值类型决定返回类型，用 0 累加 double 会被截断。',
      'transform 的输出区间必须足够大，或配合 back_inserter。',
      'accumulate 是顺序的；并行归约要用 reduce。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 accumulate 从空字符串起拼接所有数字的字符串表示。',
        hint: '初值为 std::string{}，二元操作用 + 转字符串。',
        answer: '得到 "1234"。',
      ),
    ],
  ),
  ForgeTopic(
    id: 51,
    language: 'cpp',
    level: 'intermediate',
    title: '谓词与函数对象',
    summary: '用仿函数（重载 operator()）作为可配置的谓词传给算法。',
    concepts: <String>['仿函数', 'operator()', '谓词', '状态'],
    objective: '实现带状态的函数对象并作为谓词使用。',
    prerequisites: <String>['算法：transform 与 accumulate'],
    standard: 'c++17',
    explain:
        '仿函数是重载了 operator() 的类，像函数一样调用，但可以携带状态。'
        '相比普通函数指针，它能保存配置（如阈值）。lambda 本质上是编译器生成的仿函数。'
        '标准库中 std::greater<>、std::less<> 就是仿函数。',
    code: '#include <algorithm>\n#include <iostream>\n#include <vector>\n\n'
        'struct Above {\n'
        '    int threshold;\n'
        '    bool operator()(int x) const { return x > threshold; }\n'
        '};\n\n'
        'int main() {\n'
        '    std::vector<int> v = {3, 7, 1, 9, 4};\n'
        '    int n = std::count_if(v.begin(), v.end(), Above{5});\n'
        '    std::cout << "above 5: " << n << "\\n";\n'
        '    std::sort(v.begin(), v.end(), std::greater<int>{});\n'
        '    for (int x : v) std::cout << x << " ";\n'
        '    std::cout << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'above 5: 2\n9 7 4 3 1 \n',
    pitfalls: <String>[
      '谓词应无副作用，标准库可能按任意次数、任意顺序调用它。',
      'operator() 通常标 const，否则某些算法无法使用。',
      'lambda 更简洁时优先用 lambda。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用仿函数把 v 按与 5 的距离升序排序。',
        hint: '仿函数返回 |a-5| < |b-5|。',
        answer: '结果为 4 3 7 9 1（按距离 1,2,2,4,4 的稳定顺序）。',
      ),
    ],
  ),
  ForgeTopic(
    id: 52,
    language: 'cpp',
    level: 'intermediate',
    title: 'lambda 捕获详解',
    summary: '区分按值与按引用捕获、mutable、以及初始化捕获。',
    concepts: <String>['捕获列表', 'mutable', '初始化捕获', '生命周期'],
    objective: '按需要选择捕获方式并解释各自效果。',
    prerequisites: <String>['谓词与函数对象'],
    standard: 'c++17',
    explain:
        '按值捕获 [x] 拷贝一份快照，按引用捕获 [&x] 共享变量。'
        'mutable 允许修改按值捕获的副本（默认 lambda 调用运算符是 const）。'
        '初始化捕获 [y = x + 1] 可在捕获时计算新值，用于移动捕获或改名。',
    code: '#include <algorithm>\n#include <iostream>\n#include <vector>\n\n'
        'int main() {\n'
        '    int total = 0;\n'
        '    std::vector<int> v = {1, 2, 3};\n'
        '    std::for_each(v.begin(), v.end(), [&total](int x) { total += x; });\n'
        '    std::cout << "total=" << total << "\\n";\n\n'
        '    int counter = 0;\n'
        '    auto bump = [counter]() mutable { return ++counter; };\n'
        '    std::cout << bump() << " " << bump() << "\\n";\n'
        '    std::cout << "outer=" << counter << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'total=6\n1 2\nouter=0\n',
    pitfalls: <String>[
      '按值捕获默认不可改，要改副本需 mutable。',
      '按引用捕获的变量必须在 lambda 调用时仍然存活。',
      '[=] / [&] 省事但容易捕获过多或误捕获 this，显式更安全。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用初始化捕获 [sum = 0] 写一个累加器 lambda。',
        hint: 'mutable 才能改 sum。',
        answer: '多次调用后返回累计结果，不污染外部变量。',
      ),
    ],
  ),
  ForgeTopic(
    id: 53,
    language: 'cpp',
    level: 'intermediate',
    title: 'std::function：类型擦除的可调用对象',
    summary: '用 std::function 统一保存函数指针、lambda 和仿函数。',
    concepts: <String>['std::function', '类型擦除', '回调', '可调用'],
    objective: '用 std::function 存储并调用不同类型的可调用对象。',
    prerequisites: <String>['lambda 捕获详解'],
    standard: 'c++17',
    explain:
        'std::function<R(Args...)> 是能保存任意可调用对象（函数指针、lambda、仿函数）的'
        '统一包装，代价是可能的间接调用与分配开销。它适合回调表、事件分发等需要存储'
        '不同类型可调用对象的场景。',
    code: '#include <functional>\n#include <iostream>\n#include <vector>\n\n'
        'int square(int x) { return x * x; }\n\n'
        'int main() {\n'
        '    std::vector<std::function<int(int)>> ops;\n'
        '    ops.push_back(square);\n'
        '    ops.push_back([](int x) { return x + 1; });\n'
        '    ops.push_back([](int x) { return x * 2; });\n'
        '    for (const auto& op : ops) std::cout << op(5) << " ";\n'
        '    std::cout << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '25 6 10 \n',
    pitfalls: <String>[
      'std::function 可能分配内存，性能敏感路径优先用模板或函数指针。',
      '空的 std::function 调用会抛 std::bad_function_call。',
      '捕获大对象时注意拷贝开销，必要时捕获 shared_ptr。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 ops 里所有函数依次作用在 5 上并求和。',
        hint: '遍历累加 op(5)。',
        answer: '25 + 6 + 10 = 41。',
      ),
    ],
  ),
  ForgeTopic(
    id: 54,
    language: 'cpp',
    level: 'intermediate',
    title: '函数模板',
    summary: '用模板让一个函数适配多种类型，理解实例化与类型推导。',
    concepts: <String>['template', '类型参数', '实例化', '类型推导'],
    objective: '编写函数模板并在不同类型上实例化。',
    prerequisites: <String>['函数与重载'],
    standard: 'c++17',
    explain:
        'template <typename T> 声明类型参数，编译器在调用处按实参推导 T 并生成'
        '具体版本（实例化）。模板是编译期多态，零运行开销，但会导致代码膨胀。'
        '它能替代成堆的重复重载。',
    code: '#include <iostream>\n#include <string>\n\n'
        'template <typename T>\n'
        'T maxOf(T a, T b) { return a > b ? a : b; }\n\n'
        'int main() {\n'
        '    std::cout << maxOf(3, 7) << "\\n";\n'
        '    std::cout << maxOf(2.5, 1.5) << "\\n";\n'
        '    std::cout << maxOf(std::string("apple"), std::string("pear")) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '7\n2.5\npear\n',
    pitfalls: <String>[
      '两个实参类型不同会推导失败（maxOf(3, 2.5)），需显式指定或统一类型。',
      '模板定义通常要放在头文件里，否则链接不到。',
      '模板错误信息较长，尽力写清约束（C++20 的 concepts）。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个模板 clamp(x, lo, hi) 返回夹在区间内的值。',
        hint: '用两次比较。',
        answer: 'clamp(10, 0, 5) 返回 5。',
      ),
    ],
  ),
  ForgeTopic(
    id: 55,
    language: 'cpp',
    level: 'intermediate',
    title: '类模板',
    summary: '用类模板实现类型通用的容器，理解实例化与模板参数。',
    concepts: <String>['类模板', 'template 参数', '实例化', '通用容器'],
    objective: '定义一个类模板并实例化为不同类型。',
    prerequisites: <String>['函数模板'],
    standard: 'c++17',
    explain:
        '类模板把类型作为参数，实例化成具体类。std::vector<int> 与 std::vector<double>'
        '是两个不同的类型。模板成员函数在使用时才实例化，这允许同一模板在不同类型上'
        '具备不同的可用接口。',
    code: '#include <iostream>\n\n'
        'template <typename T>\n'
        'class Pair {\n'
        'public:\n'
        '    Pair(T first, T second) : first_(first), second_(second) {}\n'
        '    T maxValue() const { return first_ > second_ ? first_ : second_; }\n'
        '    void print() const {\n'
        '        std::cout << first_ << " & " << second_ << "\\n";\n'
        '    }\n'
        'private:\n'
        '    T first_;\n'
        '    T second_;\n'
        '};\n\n'
        'int main() {\n'
        '    Pair<int> p(3, 9);\n'
        '    p.print();\n'
        '    std::cout << p.maxValue() << "\\n";\n'
        '    Pair<double> q(2.5, 1.5);\n'
        '    q.print();\n'
        '    std::cout << q.maxValue() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '3 & 9\n9\n2.5 & 1.5\n2.5\n',
    pitfalls: <String>[
      '类模板定义要放在头文件，否则实例化时找不到。',
      '模板参数多时可给默认值，如 template <typename T = int>。',
      '模板实例化错误往往在实例化点而非定义点报出。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 Pair 加一个 sum() 成员返回两值之和。',
        hint: '返回 first_ + second_。',
        answer: 'Pair<int>(3,9).sum() 返回 12。',
      ),
    ],
  ),
];
