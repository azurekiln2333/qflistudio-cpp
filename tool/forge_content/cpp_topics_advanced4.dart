import 'forge_topic.dart';

/// C++ advanced track, part 4 of 4: topics 97..100 (capstone).
const List<ForgeTopic> cppTopicsAdvanced4 = <ForgeTopic>[
  ForgeTopic(
    id: 97,
    language: 'cpp',
    level: 'advanced',
    title: '编译期计算进阶',
    summary: '用 constexpr/模板在编译期完成可组合的计算与查表。',
    concepts: <String>['constexpr', '编译期查表', 'consteval', '零运行开销'],
    objective: '在编译期生成一张表并用于运行期查询。',
    prerequisites: <String>['基准测试与性能测量'],
    standard: 'c++20',
    explain:
        '把计算放到编译期能消除运行期开销：用 constexpr 函数生成数组、'
        '用 static_assert 验证结果。C++20 的 consteval 强制表达式必须在编译期求值。'
        '编译期查表适合三角函数近似、CRC 表、单位的换算因子等。',
    code: '#include <array>\n#include <iostream>\n\n'
        'constexpr std::array<int, 6> makeSquares() {\n'
        '    std::array<int, 6> a{};\n'
        '    for (std::size_t i = 0; i < a.size(); ++i) a[i] = static_cast<int>(i * i);\n'
        '    return a;\n'
        '}\n\n'
        'constexpr auto kSquares = makeSquares();\n'
        'static_assert(kSquares[3] == 9);\n\n'
        'consteval int compileOnly(int x) { return x + 1; }\n\n'
        'int main() {\n'
        '    std::cout << kSquares[5] << "\\n";\n'
        '    std::cout << compileOnly(41) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '25\n42\n',
    pitfalls: <String>[
      'constexpr 数组会被放进只读数据段，别试图在运行期修改。',
      'consteval 函数的所有调用都必须在编译期。',
      '编译期计算受编译期步数/内存限制，别生成过大的表。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 constexpr 生成一张 2 的幂表并打印第 10 项。',
        hint: '1 << i 生成 2^i。',
        answer: '第 10 项为 1024。',
      ),
    ],
  ),
  ForgeTopic(
    id: 98,
    language: 'cpp',
    level: 'advanced',
    title: '编译期多态与运行期多态对比',
    summary: '对比模板（编译期）与虚函数（运行期）多态的适用场景与取舍。',
    concepts: <String>['编译期多态', '运行期多态', '性能', '灵活性'],
    objective: '根据是否需要运行期替换来选择多态方式。',
    prerequisites: <String>['编译期计算进阶'],
    standard: 'c++20',
    explain:
        '编译期多态（模板/CRTP/concepts）零运行开销、可内联，但类型必须在编译期确定、'
        '会增大二进制。运行期多态（虚函数）能在运行期替换实现、接口稳定，但有间接调用开销。'
        '库设计常在性能敏感处用编译期多态、在插件/扩展点用运行期多态。',
    code: '#include <iostream>\n#include <memory>\n#include <vector>\n\n'
        '// 运行期多态：可在运行期选择实现\n'
        'struct Operation {\n'
        '    virtual ~Operation() = default;\n'
        '    virtual int apply(int x) const = 0;\n'
        '};\n'
        'struct Double : Operation {\n'
        '    int apply(int x) const override { return x * 2; }\n'
        '};\n'
        'struct Square : Operation {\n'
        '    int apply(int x) const override { return x * x; }\n'
        '};\n\n'
        '// 编译期多态：零开销、可内联（函数对象而非类层次）\n'
        'struct DoubleOp { int operator()(int x) const { return x * 2; } };\n'
        'struct SquareOp { int operator()(int x) const { return x * x; } };\n\n'
        'template <typename Op>\n'
        'int applyStatic(int x) { return Op{}(x); }\n\n'
        'int main() {\n'
        '    std::vector<std::unique_ptr<Operation>> ops;\n'
        '    ops.push_back(std::make_unique<Double>());\n'
        '    ops.push_back(std::make_unique<Square>());\n'
        '    for (const auto& op : ops) std::cout << op->apply(5) << " ";\n'
        '    std::cout << "\\n";\n'
        '    std::cout << applyStatic<DoubleOp>(5) << " " << applyStatic<SquareOp>(5) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '10 25 \n10 25\n',
    pitfalls: <String>[
      '运行期多态需要指针/引用，按值会切片。',
      '编译期多态无法用同构容器存放不同类型。',
      '性能问题要先测量（见基准测试课）再决定抽象方式。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '再加一个运行期实现 Triple，比较两种多态的写法差异。',
        hint: '运行期加一个派生类，编译期加一个函数对象。',
        answer: '两种方式都能实现 ×3，运行期通过派生类、编译期通过函数对象。',
      ),
    ],
  ),
  ForgeTopic(
    id: 99,
    language: 'cpp',
    level: 'advanced',
    title: '泛型算法与自定义投影',
    summary: '用投影（projection）让算法作用在对象的关键字段上。',
    concepts: <String>['投影', 'ranges 算法', '排序/查找', '成员指针'],
    objective: '用投影按对象字段排序与查找。',
    prerequisites: <String>['编译期多态与运行期多态对比'],
    standard: 'c++20',
    explain:
        'C++20 的 ranges 算法支持投影参数：把每个元素先经投影映射，再参与比较。'
        '投影可以是 lambda 或成员指针（&T::field）。它避免了为每个字段写不同的比较器，'
        '让按字段排序/查找变得简洁。',
    code: '#include <algorithm>\n#include <iostream>\n#include <ranges>\n#include <string>\n'
        '#include <vector>\n\n'
        'struct Employee {\n'
        '    std::string name;\n'
        '    int salary;\n'
        '};\n\n'
        'int main() {\n'
        '    std::vector<Employee> staff = {{"alice", 5000}, {"bob", 3500}, {"carol", 7000}};\n'
        '    std::ranges::sort(staff, std::less{}, &Employee::salary);\n'
        '    for (const auto& e : staff) std::cout << e.name << ":" << e.salary << " ";\n'
        '    std::cout << "\\n";\n'
        '    auto it = std::ranges::find(staff, std::string("carol"), &Employee::name);\n'
        '    std::cout << "found " << it->salary << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'bob:3500 alice:5000 carol:7000 \nfound 7000\n',
    pitfalls: <String>[
      '投影只在 ranges 算法上可用，经典 std::sort 没有该参数。',
      'find 用投影时第二参要与投影结果类型匹配。',
      '多字段排序要组合投影或自定义比较器。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '按 name 字母序排序并打印。',
        hint: '投影改成 &Employee::name。',
        answer: '输出 alice bob carol 的顺序。',
      ),
    ],
  ),
  ForgeTopic(
    id: 100,
    language: 'cpp',
    level: 'advanced',
    title: '综合项目：小型表达式解释器',
    summary: '综合运用继承、智能指针、variant、多态与递归下降，实现四则运算解释器。',
    concepts: <String>['综合', '递归下降', '多态', '智能指针', '解析'],
    objective: '把多态、智能指针与递归组合成一个可运行的表达式求值器。',
    prerequisites: <String>[
      '编译期多态与运行期多态对比',
      '泛型算法与自定义投影',
    ],
    standard: 'c++20',
    explain:
        '这一课把前面所学综合成一个能求值 "1+2*3" 的小解释器：'
        '用抽象基类 Expr 表示节点，Num/Add/Mul 派生类各自求值，'
        '用 unique_ptr 管理节点所有权，用递归下降解析表达式并处理运算符优先级。'
        '它体现了“抽象 + 所有权 + 递归”的完整工程思路。',
    code: '#include <cctype>\n#include <iostream>\n#include <memory>\n#include <string>\n\n'
        'struct Expr {\n'
        '    virtual ~Expr() = default;\n'
        '    virtual int eval() const = 0;\n'
        '};\n'
        'struct Num : Expr {\n'
        '    explicit Num(int v) : value(v) {}\n'
        '    int eval() const override { return value; }\n'
        '    int value;\n'
        '};\n'
        'struct Add : Expr {\n'
        '    Add(std::unique_ptr<Expr> l, std::unique_ptr<Expr> r)\n'
        '        : left(std::move(l)), right(std::move(r)) {}\n'
        '    int eval() const override { return left->eval() + right->eval(); }\n'
        '    std::unique_ptr<Expr> left, right;\n'
        '};\n'
        'struct Mul : Expr {\n'
        '    Mul(std::unique_ptr<Expr> l, std::unique_ptr<Expr> r)\n'
        '        : left(std::move(l)), right(std::move(r)) {}\n'
        '    int eval() const override { return left->eval() * right->eval(); }\n'
        '    std::unique_ptr<Expr> left, right;\n'
        '};\n\n'
        'class Parser {\n'
        'public:\n'
        '    explicit Parser(const std::string& text) : s_(text) {}\n'
        '    std::unique_ptr<Expr> parse() { return parseAdd(); }\n'
        'private:\n'
        '    std::unique_ptr<Expr> parseAdd() {\n'
        '        auto node = parseMul();\n'
        '        while (peek() == \'+\') { ++pos_; node = std::make_unique<Add>(std::move(node), parseMul()); }\n'
        '        return node;\n'
        '    }\n'
        '    std::unique_ptr<Expr> parseMul() {\n'
        '        auto node = parseAtom();\n'
        '        while (peek() == \'*\') { ++pos_; node = std::make_unique<Mul>(std::move(node), parseAtom()); }\n'
        '        return node;\n'
        '    }\n'
        '    std::unique_ptr<Expr> parseAtom() {\n'
        '        if (peek() == \'(\') {\n'
        '            ++pos_;\n'
        '            auto node = parseAdd();\n'
        '            ++pos_;  // skip )\n'
        '            return node;\n'
        '        }\n'
        '        int value = 0;\n'
        '        while (std::isdigit(static_cast<unsigned char>(peek()))) {\n'
        '            value = value * 10 + (s_[pos_++] - \'0\');\n'
        '        }\n'
        '        return std::make_unique<Num>(value);\n'
        '    }\n'
        '    char peek() const { return pos_ < s_.size() ? s_[pos_] : \'\\0\'; }\n'
        '    std::string s_;\n'
        '    std::size_t pos_ = 0;\n'
        '};\n\n'
        'int main() {\n'
        '    Parser p("1+2*3");\n'
        '    std::cout << p.parse()->eval() << "\\n";\n'
        '    Parser q("(1+2)*3");\n'
        '    std::cout << q.parse()->eval() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '7\n9\n',
    pitfalls: <String>[
      '运算符优先级靠递归层级表达（Add 调用 Mul 调用 Atom）。',
      '节点用 unique_ptr 独占所有权，move 转移避免拷贝。',
      '本示例不处理负数、空格与错误输入，真实解析器需要更完整的错误处理。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '让解析器支持减法 \'-\'，注意左结合。',
        hint: '在 parseAdd 里增加对 \'-\' 的分支，并新增 Sub 节点。',
        answer: '解析 "5-2-1" 得到 2（左结合）。',
      ),
    ],
  ),
];
