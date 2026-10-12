import 'forge_topic.dart';

/// C++ intermediate track, part 2 of 6: topics 42..48.
const List<ForgeTopic> cppTopicsIntermediate2 = <ForgeTopic>[
  ForgeTopic(
    id: 42,
    language: 'cpp',
    level: 'intermediate',
    title: '运算符重载',
    summary: '为自定义类型重载算术与比较运算符，让类型像内置类型一样自然使用。',
    concepts: <String>['operator+', 'operator==', '成员 vs 非成员', '返回值'],
    objective: '为值类型重载 + 和 == 运算符。',
    prerequisites: <String>['类与封装'],
    standard: 'c++17',
    explain:
        '运算符重载让自定义类型参与自然表达式。成员函数形式左侧是 *this，'
        '非成员（friend）形式两侧对等。== 常与 != 配套。'
        '不要滥用重载，语义要符合直觉（+ 应是某种加法/拼接）。',
    code: '#include <iostream>\n\n'
        'struct Vec2 {\n'
        '    double x;\n'
        '    double y;\n'
        '    Vec2 operator+(const Vec2& o) const { return {x + o.x, y + o.y}; }\n'
        '    bool operator==(const Vec2& o) const { return x == o.x && y == o.y; }\n'
        '};\n\n'
        'int main() {\n'
        '    Vec2 a{1.0, 2.0};\n'
        '    Vec2 b{3.0, 4.0};\n'
        '    Vec2 c = a + b;\n'
        '    std::cout << c.x << "," << c.y << "\\n";\n'
        '    std::cout << (a == b) << " " << (a == a) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '4,6\n0 1\n',
    pitfalls: <String>[
      '重载不应改变运算符的优先级或结合性。',
      '== 与 != 要成对定义以保持一致。',
      '能作为非成员的运算符尽量写成非成员，支持左侧隐式转换。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '加一个 operator- 计算差向量。',
        hint: '返回 {x - o.x, y - o.y}。',
        answer: 'a - b 得到 (-2,-2)。',
      ),
    ],
  ),
  ForgeTopic(
    id: 43,
    language: 'cpp',
    level: 'intermediate',
    title: 'operator<< 输出自定义类型',
    summary: '重载 << 让自定义类型可直接用 std::cout 打印。',
    concepts: <String>['operator<<', 'std::ostream', 'friend', '链式输出'],
    objective: '为自定义类型实现 operator<< 以支持流式打印。',
    prerequisites: <String>['运算符重载'],
    standard: 'c++17',
    explain:
        'operator<< 必须写成非成员（友元），因为左操作数是 std::ostream。'
        '它返回 std::ostream& 以支持链式 std::cout << a << b。'
        '把打印逻辑集中在一处，避免到处手写字段格式化。',
    code: '#include <iostream>\n#include <string>\n\n'
        'struct Point {\n'
        '    int x;\n'
        '    int y;\n'
        '};\n\n'
        'std::ostream& operator<<(std::ostream& os, const Point& p) {\n'
        '    return os << "(" << p.x << ", " << p.y << ")";\n'
        '}\n\n'
        'int main() {\n'
        '    Point a{1, 2};\n'
        '    Point b{3, 4};\n'
        '    std::cout << a << " -> " << b << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '(1, 2) -> (3, 4)\n',
    pitfalls: <String>[
      '写成成员函数会导致 cout << p 无法编译（左操作数顺序错误）。',
      '要返回 ostream& 才能链式输出。',
      '输出格式要与解析保持一致，方便回读。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把格式改成 "x=1,y=2"。',
        hint: '调整函数体内的输出。',
        answer: '输出变为 x=1,y=2。',
      ),
    ],
  ),
  ForgeTopic(
    id: 44,
    language: 'cpp',
    level: 'intermediate',
    title: '继承',
    summary: '用继承表达“是一种”关系，派生子类复用并扩展基类。',
    concepts: <String>['继承', 'public 继承', '基类/派生类', 'is-a'],
    objective: '定义基类与派生类，访问基类的公有和保护成员。',
    prerequisites: <String>['类与封装'],
    standard: 'c++17',
    explain:
        'public 继承表示 is-a：派生类拥有基类的全部成员，并能访问 public/protected 成员。'
        '派生类构造函数通过初始化列表调用基类构造。继承用于复用共同接口和实现，'
        '不要为了复用实现而滥用继承（优先组合）。',
    code: '#include <iostream>\n#include <string>\n\n'
        'class Animal {\n'
        'public:\n'
        '    explicit Animal(std::string name) : name_(std::move(name)) {}\n'
        '    const std::string& name() const { return name_; }\n'
        'protected:\n'
        '    std::string describe() const { return "动物 " + name_; }\n'
        'private:\n'
        '    std::string name_;\n'
        '};\n\n'
        'class Dog : public Animal {\n'
        'public:\n'
        '    explicit Dog(std::string name) : Animal(std::move(name)) {}\n'
        '    void speak() const { std::cout << describe() << " 汪\\n"; }\n'
        '};\n\n'
        'int main() {\n'
        '    Dog d("旺财");\n'
        '    std::cout << d.name() << "\\n";\n'
        '    d.speak();\n'
        '    return 0;\n'
        '}\n',
    output: '旺财\n动物 旺财 汪\n',
    pitfalls: <String>[
      '基类私有成员派生类不可见，需要 protected 或接口。',
      '派生类构造必须在初始化列表调用合适的基类构造。',
      '基类析构不是 virtual 时，通过基类指针删除派生对象是未定义行为。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '再派生一个 Cat 类并实现 speak 输出“喵”。',
        hint: '仿照 Dog 写即可。',
        answer: 'Cat c("咪咪"); c.speak() 输出「动物 咪咪 喵」。',
      ),
    ],
  ),
  ForgeTopic(
    id: 45,
    language: 'cpp',
    level: 'intermediate',
    title: '虚函数与动态派发',
    summary: '用 virtual 让通过基类指针/引用调用时执行派生类的实现。',
    concepts: <String>['virtual', 'override', '动态派发', '多态'],
    objective: '用虚函数实现运行期多态。',
    prerequisites: <String>['继承'],
    standard: 'c++17',
    explain:
        '把基类函数标为 virtual，用基类指针或引用调用时会根据对象的实际类型'
        '分派到派生类实现，这叫动态派发/多态。派生类用 override 显式表明覆盖，'
        '编译器会检查签名是否匹配，避免“以为覆盖了其实没有”。',
    code: '#include <iostream>\n#include <memory>\n#include <vector>\n\n'
        'class Shape {\n'
        'public:\n'
        '    virtual ~Shape() = default;\n'
        '    virtual double area() const = 0;\n'
        '    virtual const char* name() const = 0;\n'
        '};\n\n'
        'class Circle : public Shape {\n'
        'public:\n'
        '    explicit Circle(double r) : r_(r) {}\n'
        '    double area() const override { return 3.14159 * r_ * r_; }\n'
        '    const char* name() const override { return "circle"; }\n'
        'private:\n'
        '    double r_;\n'
        '};\n\n'
        'int main() {\n'
        '    std::vector<std::unique_ptr<Shape>> shapes;\n'
        '    shapes.push_back(std::make_unique<Circle>(1.0));\n'
        '    for (const auto& s : shapes) {\n'
        '        std::cout << s->name() << " " << s->area() << "\\n";\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: 'circle 3.14159\n',
    pitfalls: <String>[
      '忘记 virtual 会静态绑定，得到基类实现。',
      '覆盖时签名必须完全一致，否则是隐藏而非覆盖；用 override 让编译器把关。',
      '基类作为多态使用时，析构函数必须是 virtual。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '再加一个 Square 派生类并放进容器。',
        hint: '实现 area/name。',
        answer: '输出会多一行 square 及其面积。',
      ),
    ],
  ),
  ForgeTopic(
    id: 46,
    language: 'cpp',
    level: 'intermediate',
    title: '抽象类与接口',
    summary: '用纯虚函数定义只有接口没有实现的抽象基类。',
    concepts: <String>['纯虚函数', '抽象类', '接口', '= 0'],
    objective: '定义抽象基类并用它作为接口约束实现者。',
    prerequisites: <String>['虚函数与动态派发'],
    standard: 'c++17',
    explain:
        '含纯虚函数（= 0）的类是抽象类，不能实例化，只能作为接口被继承。'
        '派生类必须实现所有纯虚函数才能实例化。'
        '接口把“能做什么”与“怎么做”分离，是依赖倒置的基础。',
    code: '#include <iostream>\n#include <memory>\n\n'
        'class Logger {\n'
        'public:\n'
        '    virtual ~Logger() = default;\n'
        '    virtual void log(const char* msg) = 0;\n'
        '};\n\n'
        'class ConsoleLogger : public Logger {\n'
        'public:\n'
        '    void log(const char* msg) override { std::cout << "[console] " << msg << "\\n"; }\n'
        '};\n\n'
        'class FileLogger : public Logger {\n'
        'public:\n'
        '    void log(const char* msg) override { std::cout << "[file] " << msg << "\\n"; }\n'
        '};\n\n'
        'void useLogger(Logger& logger) { logger.log("hello"); }\n\n'
        'int main() {\n'
        '    ConsoleLogger c;\n'
        '    FileLogger f;\n'
        '    useLogger(c);\n'
        '    useLogger(f);\n'
        '    return 0;\n'
        '}\n',
    output: '[console] hello\n[file] hello\n',
    pitfalls: <String>[
      '抽象类不能实例化，但可以有数据成员和普通函数。',
      '接口应保持小而稳定，改动会波及所有实现者。',
      '按引用/指针接收接口，不要按值（会切片）。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '再加一个 NullLogger，log 什么都不做。',
        hint: '空实现即可（Null Object 模式）。',
        answer: 'useLogger(nullLogger) 不产生输出。',
      ),
    ],
  ),
  ForgeTopic(
    id: 47,
    language: 'cpp',
    level: 'intermediate',
    title: '虚析构函数',
    summary: '多态基类的析构函数应为 virtual，避免只析构基类子对象。',
    concepts: <String>['虚析构', 'delete 语义', '多态删除', '资源泄漏'],
    objective: '理解为什么多态基类需要虚析构函数。',
    prerequisites: <String>['抽象类与接口'],
    standard: 'c++17',
    explain:
        '当用基类指针 delete 派生对象时，如果基类析构不是 virtual，'
        '只会调用基类析构，派生类的清理被跳过（未定义行为/资源泄漏）。'
        '把基类析构设为 virtual 会按实际类型调用正确的析构。'
        '只要类可能被多态使用，就给它虚析构。',
    code: '#include <iostream>\n\n'
        'class Base {\n'
        'public:\n'
        '    virtual ~Base() { std::cout << "~Base\\n"; }\n'
        '};\n\n'
        'class Derived : public Base {\n'
        'public:\n'
        '    ~Derived() override { std::cout << "~Derived\\n"; }\n'
        '};\n\n'
        'int main() {\n'
        '    Base* p = new Derived();\n'
        '    delete p;  // 虚析构：先 ~Derived 再 ~Base\n'
        '    return 0;\n'
        '}\n',
    output: '~Derived\n~Base\n',
    pitfalls: <String>[
      '基类析构非 virtual 时多态删除只析构基类子对象。',
      '不要从没有虚析构的类（如 std::string）公开继承并多态删除。',
      '虚析构会引入 vptr 开销，纯数据类不需要。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把基类析构的 virtual 去掉，观察输出变化。',
        hint: '去掉后只输出 ~Base。',
        answer: '只析构基类，派生类清理被跳过。',
      ),
    ],
  ),
  ForgeTopic(
    id: 48,
    language: 'cpp',
    level: 'intermediate',
    title: 'unique_ptr：独占所有权',
    summary: '用 std::unique_ptr 表达独占所有权，自动释放、不可拷贝可移动。',
    concepts: <String>['unique_ptr', 'make_unique', '所有权', 'move'],
    objective: '用 unique_ptr 管理动态对象并转移所有权。',
    prerequisites: <String>['虚析构函数'],
    standard: 'c++17',
    explain:
        'std::unique_ptr<T> 独占一块动态资源，离开作用域自动 delete；'
        '不能拷贝，只能 move 转移所有权。std::make_unique 更安全（异常安全、少写类型）。'
        '它替代裸 new/delete，是默认的堆对象管理方式。',
    code: '#include <iostream>\n#include <memory>\n\n'
        'struct Resource {\n'
        '    explicit Resource(int id) : id(id) { std::cout << "acquire " << id << "\\n"; }\n'
        '    ~Resource() { std::cout << "release " << id << "\\n"; }\n'
        '    int id;\n'
        '};\n\n'
        'int main() {\n'
        '    auto a = std::make_unique<Resource>(1);\n'
        '    std::cout << a->id << "\\n";\n'
        '    auto b = std::move(a);  // 所有权转移\n'
        '    std::cout << (a == nullptr) << "\\n";\n'
        '    std::cout << b->id << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'acquire 1\n1\n1\n1\nrelease 1\n',
    pitfalls: <String>[
      'unique_ptr 不能拷贝，转移所有权要用 std::move。',
      '转移后原指针为 null，解引用是未定义行为。',
      '优先 make_unique 而非 new。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 a 转移给 b 后打印 a == nullptr 的结果。',
        hint: 'a 在 move 后为空。',
        answer: '输出 1，表示 a 已不拥有资源。',
      ),
    ],
  ),
];
