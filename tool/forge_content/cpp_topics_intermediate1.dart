import 'forge_topic.dart';

/// C++ intermediate track, part 1 of 6: topics 35..41.
const List<ForgeTopic> cppTopicsIntermediate1 = <ForgeTopic>[
  ForgeTopic(
    id: 35,
    language: 'cpp',
    level: 'intermediate',
    title: '类与封装',
    summary: '用 class 定义对象，用访问控制隐藏实现细节。',
    concepts: <String>['class', '封装', 'private/public', '成员函数'],
    objective: '定义带私有数据和公有接口的类，理解封装的动机。',
    prerequisites: <String>['const 正确性入门'],
    standard: 'c++17',
    explain:
        'class 把数据和行为放在一起，默认成员是 private。'
        '把数据设为 private、只暴露必要的方法叫封装：外部只能通过接口改变状态，'
        '类的作者可以在不破坏调用方的前提下修改内部实现。struct 默认 public，'
        '语义上常用于纯数据聚合。',
    code: '#include <iostream>\n\n'
        'class Counter {\n'
        'public:\n'
        '    void increment() { ++value_; }\n'
        '    int value() const { return value_; }\n'
        'private:\n'
        '    int value_ = 0;\n'
        '};\n\n'
        'int main() {\n'
        '    Counter c;\n'
        '    c.increment();\n'
        '    c.increment();\n'
        '    std::cout << c.value() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '2\n',
    pitfalls: <String>[
      'class 默认 private，忘记写 public: 会导致接口无法访问。',
      '成员变量命名常用尾下划线（value_）以区别参数。',
      '把观察方法标成 const，否则 const 对象无法调用。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 Counter 加一个 reset() 方法把值清零。',
        hint: 'void reset() { value_ = 0; }',
        answer: '调用 reset() 后 value() 返回 0。',
      ),
    ],
  ),
  ForgeTopic(
    id: 36,
    language: 'cpp',
    level: 'intermediate',
    title: '构造函数',
    summary: '用构造函数初始化对象，并理解重载构造函数与默认构造。',
    concepts: <String>['构造函数', '重载构造', '默认构造', 'explicit'],
    objective: '定义多个构造函数初始化为不同状态的对象。',
    prerequisites: <String>['类与封装'],
    standard: 'c++17',
    explain:
        '构造函数与类同名、无返回类型，在对象创建时运行。可以重载提供多种初始化方式。'
        '没有显式构造函数时编译器生成默认构造。单参数构造函数加 explicit 可阻止意外的隐式转换。',
    code: '#include <iostream>\n#include <string>\n\n'
        'class Point {\n'
        'public:\n'
        '    Point() : x_(0), y_(0) {}\n'
        '    Point(int x, int y) : x_(x), y_(y) {}\n'
        '    explicit Point(int v) : x_(v), y_(v) {}\n'
        '    void print() const { std::cout << "(" << x_ << "," << y_ << ")\\n"; }\n'
        'private:\n'
        '    int x_;\n'
        '    int y_;\n'
        '};\n\n'
        'int main() {\n'
        '    Point a;\n'
        '    Point b(3, 4);\n'
        '    Point c(5);\n'
        '    a.print();\n'
        '    b.print();\n'
        '    c.print();\n'
        '    return 0;\n'
        '}\n',
    output: '(0,0)\n(3,4)\n(5,5)\n',
    pitfalls: <String>[
      '构造函数不能声明返回类型。',
      '未初始化的内置类型成员是垃圾值，务必初始化。',
      'explicit 只对单参数构造有意义，但建议默认加上。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 Point 再加一个构造函数接受字符串 "x,y"。',
        hint: '解析字符串后委托给 (int,int) 构造。',
        answer: '新增构造后 Point p("1,2") 打印 (1,2)。',
      ),
    ],
  ),
  ForgeTopic(
    id: 37,
    language: 'cpp',
    level: 'intermediate',
    title: '成员初始化列表',
    summary: '用初始化列表在构造时直接初始化成员，理解与赋值的区别。',
    concepts: <String>['成员初始化列表', '初始化顺序', 'const 成员', '引用成员'],
    objective: '用成员初始化列表初始化 const、引用和无默认构造的成员。',
    prerequisites: <String>['构造函数'],
    standard: 'c++17',
    explain:
        '构造函数冒号后的初始化列表在进入函数体前初始化成员。'
        '对 const 成员、引用成员、没有默认构造的类类型成员，必须用初始化列表，'
        '在函数体里“赋值”为时已晚。成员按声明顺序初始化，与列表书写顺序无关。',
    code: '#include <iostream>\n#include <string>\n\n'
        'class Config {\n'
        'public:\n'
        '    Config(std::string name, int id)\n'
        '        : name_(std::move(name)), id_(id), tag_(id_ * 10) {}\n'
        '    void print() const {\n'
        '        std::cout << name_ << " " << id_ << " " << tag_ << "\\n";\n'
        '    }\n'
        'private:\n'
        '    std::string name_;\n'
        '    int id_;\n'
        '    const int tag_;\n'
        '};\n\n'
        'int main() {\n'
        '    Config c("server", 7);\n'
        '    c.print();\n'
        '    return 0;\n'
        '}\n',
    output: 'server 7 70\n',
    pitfalls: <String>[
      'const/引用成员必须在初始化列表里初始化。',
      '成员初始化顺序由声明顺序决定，别依赖列表顺序。',
      '用初始化列表而非函数体赋值可避免先默认构造再赋值。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 tag_ 的初始化改成依赖 name_ 的长度。',
        hint: 'tag_(static_cast<int>(name_.size()))',
        answer: '对 "server"（6 个字符）tag_ 变为 6。',
      ),
    ],
  ),
  ForgeTopic(
    id: 38,
    language: 'cpp',
    level: 'intermediate',
    title: '析构函数与 RAII',
    summary: '用析构函数在对象销毁时释放资源，理解 RAII 是 C++ 资源管理的核心。',
    concepts: <String>['析构函数', 'RAII', '确定性析构', '作用域'],
    objective: '编写析构函数并在作用域结束或异常时自动释放资源。',
    prerequisites: <String>['成员初始化列表'],
    standard: 'c++17',
    explain:
        '析构函数 ~ClassName() 在对象生命周期结束时自动调用，即使因异常离开作用域也会调用。'
        'RAII（资源获取即初始化）把资源绑定到对象生命周期：构造时获取、析构时释放，'
        '从而无需手写清理代码、也不会漏掉。智能指针和文件流都是 RAII 的例子。',
    code: '#include <iostream>\n\n'
        'class Tracer {\n'
        'public:\n'
        '    explicit Tracer(const char* name) : name_(name) {\n'
        '        std::cout << "创建 " << name_ << "\\n";\n'
        '    }\n'
        '    ~Tracer() { std::cout << "销毁 " << name_ << "\\n"; }\n'
        'private:\n'
        '    const char* name_;\n'
        '};\n\n'
        'void scope() {\n'
        '    Tracer inner("inner");\n'
        '}\n\n'
        'int main() {\n'
        '    Tracer outer("outer");\n'
        '    scope();\n'
        '    std::cout << "main 结束前\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '创建 outer\n创建 inner\n销毁 inner\nmain 结束前\n销毁 outer\n',
    pitfalls: <String>[
      '析构函数不抛出异常；抛异常可能导致 terminate。',
      '多态基类需要虚析构函数（见后续课程）。',
      '按值返回局部对象时，移动/拷贝省略会影响析构次数，别依赖具体次数。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '再加一层嵌套作用域，观察析构顺序。',
        hint: '析构按创建的反序进行。',
        answer: '内层对象先销毁，外层后销毁。',
      ),
    ],
  ),
  ForgeTopic(
    id: 39,
    language: 'cpp',
    level: 'intermediate',
    title: '拷贝语义',
    summary: '理解拷贝构造与拷贝赋值的默认行为，以及在什么情况下需要自定义。',
    concepts: <String>['拷贝构造', '拷贝赋值', '深拷贝', '资源所有权'],
    objective: '识别浅拷贝的陷阱并实现深拷贝。',
    prerequisites: <String>['析构函数与 RAII'],
    standard: 'c++17',
    explain:
        '编译器默认的拷贝是逐成员浅拷贝：若成员是裸指针，两个对象会指向同一块内存，'
        '析构时重复释放。拥有资源的类需要自定义拷贝构造/拷贝赋值做深拷贝，'
        '或者干脆禁用拷贝、改用移动。',
    code: '#include <cstring>\n#include <iostream>\n\n'
        'class Buffer {\n'
        'public:\n'
        '    explicit Buffer(const char* text) {\n'
        '        size_ = std::strlen(text);\n'
        '        data_ = new char[size_ + 1];\n'
        '        std::memcpy(data_, text, size_ + 1);\n'
        '    }\n'
        '    Buffer(const Buffer& other) {  // 深拷贝\n'
        '        size_ = other.size_;\n'
        '        data_ = new char[size_ + 1];\n'
        '        std::memcpy(data_, other.data_, size_ + 1);\n'
        '    }\n'
        '    ~Buffer() { delete[] data_; }\n'
        '    std::size_t size() const { return size_; }\n'
        '    const char* c_str() const { return data_; }\n'
        'private:\n'
        '    char* data_ = nullptr;\n'
        '    std::size_t size_ = 0;\n'
        '};\n\n'
        'int main() {\n'
        '    Buffer a("hello");\n'
        '    Buffer b = a;\n'
        '    b.c_str();\n'
        '    std::cout << a.c_str() << " " << a.size() << "\\n";\n'
        '    std::cout << b.c_str() << " " << b.size() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'hello 5\nhello 5\n',
    pitfalls: <String>[
      '默认浅拷贝会导致同一资源被释放两次（double free）。',
      '自定义拷贝后别忘了拷贝赋值和析构（三者通常一起定义）。',
      '能用智能指针/容器就不手写裸指针管理。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 Buffer 加一个拷贝赋值运算符 operator=。',
        hint: '注意自赋值与先分配再拷贝的顺序。',
        answer: '实现后 b = a 能安全复制内容。',
      ),
    ],
  ),
  ForgeTopic(
    id: 40,
    language: 'cpp',
    level: 'intermediate',
    title: '移动语义',
    summary: '用移动构造/移动赋值从临时对象窃取资源，避免不必要的深拷贝。',
    concepts: <String>['移动构造', '移动赋值', 'std::move', '右值引用'],
    objective: '实现移动构造与移动赋值，理解何时被调用。',
    prerequisites: <String>['拷贝语义'],
    standard: 'c++17',
    explain:
        '移动构造接收右值引用 T&&，把源对象的资源“偷”过来，再把源置空，'
        '因此比深拷贝便宜。std::move 把一个左值标记成可移动的右值。'
        '移动后源对象仍可析构、可赋值，但值未指定。',
    code: '#include <iostream>\n#include <string>\n#include <utility>\n\n'
        'class Box {\n'
        'public:\n'
        '    explicit Box(std::string name) : name_(std::move(name)) {}\n'
        '    Box(Box&& other) noexcept : name_(std::move(other.name_)) {\n'
        '        other.name_ = "(moved)";\n'
        '        std::cout << "移动构造\\n";\n'
        '    }\n'
        '    const std::string& name() const { return name_; }\n'
        'private:\n'
        '    std::string name_;\n'
        '};\n\n'
        'int main() {\n'
        '    Box a("alice");\n'
        '    Box b(std::move(a));\n'
        '    std::cout << "b=" << b.name() << "\\n";\n'
        '    std::cout << "a=" << a.name() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '移动构造\nb=alice\na=(moved)\n',
    pitfalls: <String>[
      '移动后不要再使用源对象的值。',
      '移动操作尽量标 noexcept，容器扩容时才会优先选移动。',
      '对 const 对象用 std::move 会退化成拷贝。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '加一个移动赋值 operator=(Box&&) 并观察输出。',
        hint: '先释放自身资源，再窃取对方资源。',
        answer: '实现后赋值会打印自定义标记。',
      ),
    ],
  ),
  ForgeTopic(
    id: 41,
    language: 'cpp',
    level: 'intermediate',
    title: '三/五/零法则',
    summary: '理解拷贝、移动、析构之间的依赖，优先选择“零法则”。',
    concepts: <String>['三法则', '五法则', '零法则', '特殊成员函数'],
    objective: '判断什么类需要自定义特殊成员函数，什么时候什么都不写。',
    prerequisites: <String>['移动语义'],
    standard: 'c++17',
    explain:
        '三法则：自定义析构、拷贝构造、拷贝赋值中的任一个，通常三个都要定义。'
        '五法则另加移动构造与移动赋值。零法则：如果类只由能自我管理的成员'
        '（string、vector、智能指针）组成，就不写任何特殊成员函数，让编译器生成正确的版本。'
        '现代 C++ 优先用零法则。',
    code: '#include <iostream>\n#include <string>\n#include <vector>\n\n'
        '// 零法则：成员都能自我管理，不需要手写任何特殊成员函数\n'
        'class Team {\n'
        'public:\n'
        '    explicit Team(std::string name) : name_(std::move(name)) {}\n'
        '    void add(const std::string& member) { members_.push_back(member); }\n'
        '    std::size_t size() const { return members_.size(); }\n'
        '    const std::string& name() const { return name_; }\n'
        'private:\n'
        '    std::string name_;\n'
        '    std::vector<std::string> members_;\n'
        '};\n\n'
        'int main() {\n'
        '    Team t("core");\n'
        '    t.add("alice");\n'
        '    t.add("bob");\n'
        '    Team copy = t;  // 编译器生成的拷贝正确工作\n'
        '    std::cout << copy.name() << " " << copy.size() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'core 2\n',
    pitfalls: <String>[
      '只要写了析构，编译器就不再生成移动操作（会退化为拷贝）。',
      '手写特殊成员函数时容易漏掉某一个，用 = default / = delete 明确意图。',
      '能用零法则就别手写三/五法则。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 Team 显式写 Team(const Team&) = default; 观察是否仍正确。',
        hint: 'default 让编译器生成，与零法则等价。',
        answer: '显式 default 后行为不变，仍能正确拷贝。',
      ),
    ],
  ),
];
