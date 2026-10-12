import 'forge_topic.dart';

/// C++ advanced track, part 2 of 4: topics 83..89.
const List<ForgeTopic> cppTopicsAdvanced2 = <ForgeTopic>[
  ForgeTopic(
    id: 83,
    language: 'cpp',
    level: 'advanced',
    title: 'CRTP：奇异递归模板模式',
    summary: '用派生类把自己作为模板参数传给基类，实现静态多态。',
    concepts: <String>['CRTP', '静态多态', '混入', '编译期分派'],
    objective: '用 CRTP 让基类调用派生类的实现而无需虚函数。',
    prerequisites: <String>['SFINAE 到 concepts 的演进'],
    standard: 'c++17',
    explain:
        'CRTP 让 Derived 继承 Base<Derived>，基类通过 static_cast<Derived*>(this) '
        '调用派生实现。没有虚函数、没有运行期开销，是编译期多态。'
        '常用于接口注入、计数等混入（mixin）。',
    code: '#include <iostream>\n\n'
        'template <typename Derived>\n'
        'class Shape {\n'
        'public:\n'
        '    double area() const { return static_cast<const Derived*>(this)->areaImpl(); }\n'
        '};\n\n'
        'class Square : public Shape<Square> {\n'
        'public:\n'
        '    explicit Square(double s) : side_(s) {}\n'
        '    double areaImpl() const { return side_ * side_; }\n'
        'private:\n'
        '    double side_;\n'
        '};\n\n'
        'int main() {\n'
        '    Square s(3.0);\n'
        '    std::cout << s.area() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '9\n',
    pitfalls: <String>[
      'CRTP 是编译期绑定，不能通过基类指针多态使用。',
      '派生类名必须在实例化时已知，因此不能跨翻译单元拆分得过于随意。',
      'areaImpl 需要 public 或基类为 friend。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '再加一个 Circle 派生类，验证 CRTP 静态分派。',
        hint: '实现 areaImpl 返回 πr²。',
        answer: 'Circle(1).area() 约为 3.14159。',
      ),
    ],
  ),
  ForgeTopic(
    id: 84,
    language: 'cpp',
    level: 'advanced',
    title: '策略式设计',
    summary: '把行为抽象成策略模板参数，在编译期组合出不同变体。',
    concepts: <String>['策略模式', '模板参数', '零开销抽象', '组合'],
    objective: '用策略模板参数在编译期选择算法。',
    prerequisites: <String>['CRTP：奇异递归模板模式'],
    standard: 'c++17',
    explain:
        '策略式设计把可替换的行为（如比较、舍入、日志）作为模板参数传入，'
        '编译器为每种组合生成专用代码，没有运行期分支或虚调用开销。'
        '它是标准库（如容器的比较器、分配器）使用的核心手法。',
    code: '#include <iostream>\n#include <vector>\n\n'
        'struct Ascending { static bool before(int a, int b) { return a < b; } };\n'
        'struct Descending { static bool before(int a, int b) { return a > b; } };\n\n'
        'template <typename Order>\n'
        'void sortAndPrint(std::vector<int> v) {\n'
        '    for (std::size_t i = 0; i + 1 < v.size(); ++i)\n'
        '        for (std::size_t j = 0; j + 1 < v.size() - i; ++j)\n'
        '            if (Order::before(v[j + 1], v[j])) std::swap(v[j], v[j + 1]);\n'
        '    for (int x : v) std::cout << x << " ";\n'
        '    std::cout << "\\n";\n'
        '}\n\n'
        'int main() {\n'
        '    sortAndPrint<Ascending>({3, 1, 2});\n'
        '    sortAndPrint<Descending>({3, 1, 2});\n'
        '    return 0;\n'
        '}\n',
    output: '1 2 3 \n3 2 1 \n',
    pitfalls: <String>[
      '策略组合会带来代码膨胀（每种组合一份实例）。',
      '策略接口应尽量小且无状态。',
      '运行期才决定策略时应改用虚函数或多态。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '加一个按绝对值排序的策略。',
        hint: 'before 比较 abs 值。',
        answer: '{-3,1,2} 按绝对值排为 1 2 -3。',
      ),
    ],
  ),
  ForgeTopic(
    id: 85,
    language: 'cpp',
    level: 'advanced',
    title: '类型擦除',
    summary: '用统一接口隐藏具体类型，保留运行期灵活性。',
    concepts: <String>['类型擦除', '概念建模', '多态包装', 'std::function 原理'],
    objective: '手写一个简单的类型擦除容器，理解 std::function 的内部原理。',
    prerequisites: <String>['策略式设计'],
    standard: 'c++17',
    explain:
        '类型擦除把“不同类型但接口一致”的对象包装到统一类型后面，'
        '通常结合虚函数与模板构造：模板构造函数把具体类型存进内部多态对象。'
        'std::function、std::any 都是这个套路。它用一点运行期开销换取灵活性。',
    code: '#include <iostream>\n#include <memory>\n#include <string>\n\n'
        'class AnyPrinter {\n'
        'public:\n'
        '    template <typename T>\n'
        '    explicit AnyPrinter(T value)\n'
        '        : impl_(std::make_unique<Model<T>>(std::move(value))) {}\n'
        '    void print() const { impl_->print(); }\n'
        'private:\n'
        '    struct Concept {\n'
        '        virtual ~Concept() = default;\n'
        '        virtual void print() const = 0;\n'
        '    };\n'
        '    template <typename T>\n'
        '    struct Model : Concept {\n'
        '        explicit Model(T v) : value_(std::move(v)) {}\n'
        '        void print() const override { std::cout << value_ << "\\n"; }\n'
        '        T value_;\n'
        '    };\n'
        '    std::unique_ptr<Concept> impl_;\n'
        '};\n\n'
        'int main() {\n'
        '    AnyPrinter a(42);\n'
        '    AnyPrinter b(std::string("hi"));\n'
        '    a.print();\n'
        '    b.print();\n'
        '    return 0;\n'
        '}\n',
    output: '42\nhi\n',
    pitfalls: <String>[
      '类型擦除引入间接调用与可能的堆分配。',
      'Model 可能被拷贝，注意大对象用移动。',
      '接口（Concept）要覆盖所有需要擦除的操作。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 AnyPrinter 加一个描述长度的 name() 方法。',
        hint: '在 Concept 里加虚函数，Model 里实现。',
        answer: '不同 Value 返回各自的长度描述。',
      ),
    ],
  ),
  ForgeTopic(
    id: 86,
    language: 'cpp',
    level: 'advanced',
    title: '自定义分配器',
    summary: '为容器提供自定义内存分配策略，观察分配次数。',
    concepts: <String>['allocator', '内存分配', 'allocate/deallocate', '计数'],
    objective: '写一个记录分配次数的简单分配器并用于容器。',
    prerequisites: <String>['类型擦除'],
    standard: 'c++17',
    explain:
        '分配器把“如何获取内存”从容器中分离。容器通过 allocator_traits 调用'
        'allocate/deallocate。自定义分配器可用于内存池、统计、对齐等。'
        '现代分配器只需提供 value_type、allocate、deallocate 和相等比较。',
    code: '#include <cstddef>\n#include <iostream>\n#include <memory>\n#include <vector>\n\n'
        'template <typename T>\n'
        'struct CountingAllocator {\n'
        '    using value_type = T;\n'
        '    CountingAllocator() = default;\n'
        '    template <typename U>\n'
        '    CountingAllocator(const CountingAllocator<U>&) {}\n'
        '    T* allocate(std::size_t n) {\n'
        '        ++allocations;\n'
        '        return static_cast<T*>(::operator new(n * sizeof(T)));\n'
        '    }\n'
        '    void deallocate(T* p, std::size_t) { ::operator delete(p); }\n'
        '    static inline int allocations = 0;\n'
        '};\n\n'
        'int main() {\n'
        '    std::vector<int, CountingAllocator<int>> v;\n'
        '    for (int i = 0; i < 100; ++i) v.push_back(i);\n'
        '    std::cout << "size=" << v.size() << "\\n";\n'
        '    std::cout << "allocations>0=" << (CountingAllocator<int>::allocations > 0) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'size=100\nallocations>0=1\n',
    pitfalls: <String>[
      '分配器要满足 allocator_traits 的要求（含相等比较、rebind）。',
      'allocate 返回的未初始化内存要用 placement new 构造对象。',
      '分配器在容器间要能比较是否等价。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '预留容量后观察分配次数是否减少。',
        hint: '使用 v.reserve(100)。',
        answer: 'reserve 后分配次数降为 1 次。',
      ),
    ],
  ),
  ForgeTopic(
    id: 87,
    language: 'cpp',
    level: 'advanced',
    title: 'std::span：非拥有视图',
    summary: '用 std::span 以零拷贝方式表示连续区间，替代指针+长度。',
    concepts: <String>['std::span', '非拥有视图', '连续内存', 'C++20'],
    objective: '用 span 传递数组/容器的一部分而不拷贝。',
    prerequisites: <String>['自定义分配器'],
    standard: 'c++20',
    explain:
        'std::span<T> 是对连续内存的非拥有视图，等价于“指针 + 长度”的安全封装。'
        '它能统一接收数组、vector、array 的片段，函数签名更清晰、也不丢长度。'
        '它是 C++20 引入的 view 类型之一。',
    code: '#include <iostream>\n#include <span>\n#include <vector>\n\n'
        'int sum(std::span<const int> data) {\n'
        '    int total = 0;\n'
        '    for (int x : data) total += x;\n'
        '    return total;\n'
        '}\n\n'
        'int main() {\n'
        '    int raw[] = {1, 2, 3};\n'
        '    std::vector<int> v = {4, 5, 6, 7};\n'
        '    std::cout << sum(raw) << "\\n";\n'
        '    std::cout << sum(v) << "\\n";\n'
        '    std::cout << sum(std::span(v).subspan(1, 2)) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '6\n22\n11\n',
    pitfalls: <String>[
      'span 不拥有数据，底层容器销毁后悬空。',
      'span 只适用于连续内存（list 不能用）。',
      'span 的 size 不检查，越界访问是未定义行为。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 span 只对 v 的前两个元素求和。',
        hint: 'std::span(v).first(2)。',
        answer: '返回 9。',
      ),
    ],
  ),
  ForgeTopic(
    id: 88,
    language: 'cpp',
    level: 'advanced',
    title: 'ranges 管道',
    summary: '用 views 组合出惰性、可读的数据变换管道。',
    concepts: <String>['views', '管道', '惰性求值', 'filter/transform/take'],
    objective: '用 views 管道筛选、变换并取前 N 个元素。',
    prerequisites: <String>['std::span：非拥有视图'],
    standard: 'c++20',
    explain:
        'ranges views 是惰性的、可组合的视图：filter 筛选、transform 变换、take 取前 N 个，'
        '用 | 连接成管道。每个元素只有在被遍历时才计算，避免中间容器。'
        '它让数据处理像写查询一样声明式。',
    code: '#include <iostream>\n#include <ranges>\n#include <vector>\n\n'
        'int main() {\n'
        '    std::vector<int> v = {1, 2, 3, 4, 5, 6};\n'
        '    auto pipeline = v\n'
        '        | std::views::filter([](int x) { return x % 2 == 0; })\n'
        '        | std::views::transform([](int x) { return x * x; });\n'
        '    for (int x : pipeline) std::cout << x << " ";\n'
        '    std::cout << "\\n";\n'
        '    for (int x : pipeline | std::views::take(2)) std::cout << x << " ";\n'
        '    std::cout << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '4 16 36 \n4 16 \n',
    pitfalls: <String>[
      'view 不拥有数据，绑定的容器必须比 view 活得久。',
      'view 每次遍历都会重新计算（除非缓存），注意性能。',
      'C++20 的 views 支持需要较新的标准库（WSL clang 18 / g++ 13 可用）。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '改成奇数并取平方，打印前三个。',
        hint: 'filter x%2!=0，再 take(3)。',
        answer: '输出 1 9 25。',
      ),
    ],
  ),
  ForgeTopic(
    id: 89,
    language: 'cpp',
    level: 'advanced',
    title: '三路比较运算符 <=>',
    summary: '用 C++20 的三路比较自动获得一致的 <、>、<=、>=、== 语义。',
    concepts: <String>['operator<=>', '三路比较', 'C++20', '比较一致性'],
    objective: '用 <=> 为一个类型定义完整且一致的比较语义。',
    prerequisites: <String>['ranges 管道'],
    standard: 'c++20',
    explain:
        'C++20 的三路比较运算符 <=>（spaceship）一次定义就能让编译器推导出'
        '==、!=、<、<=、>、>= 的关系。返回 std::strong_ordering 表达“小于/相等/大于”。'
        '它消除了手写六个比较运算符容易产生的不一致。\n'
        '附：C++20 也引入了协程（co_await/co_yield）作为无栈协程机制，'
        '但协程需要完整的 promise 类型与较新的标准库支持，跨 libstdc++/libc++ 实现差异较大，'
        '因此本课的配套示例选用可稳定运行的三路比较，协程仅作概念介绍。',
    code: '#include <compare>\n#include <iostream>\n\n'
        'struct Version {\n'
        '    int major;\n'
        '    int minor;\n'
        '    auto operator<=>(const Version&) const = default;\n'
        '};\n\n'
        'int main() {\n'
        '    Version a{1, 2};\n'
        '    Version b{1, 3};\n'
        '    std::cout << (a < b) << " " << (a == b) << " " << (a > b) << "\\n";\n'
        '    std::cout << (a <=> b == 0) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '1 0 0\n0\n',
    pitfalls: <String>[
      'auto operator<=>() = default 会逐成员比较，要求成员都可比较。',
      '浮点成员用 default 比较会得到 weak_ordering，与 NaN 语义有关。',
      '需要自定义时返回类型要用 std::strong_ordering/partial_ordering。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '再加一个 patch 字段，观察比较仍自动正确。',
        hint: 'default 的三路比较会依次比较 major、minor、patch。',
        answer: '新增字段后比较仍按声明顺序生效。',
      ),
    ],
  ),
];
