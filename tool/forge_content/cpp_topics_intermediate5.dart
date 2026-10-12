import 'forge_topic.dart';

/// C++ intermediate track, part 5 of 6: topics 63..69.
const List<ForgeTopic> cppTopicsIntermediate5 = <ForgeTopic>[
  ForgeTopic(
    id: 63,
    language: 'cpp',
    level: 'intermediate',
    title: 'std::list：双向链表',
    summary: '用 list 在任意位置 O(1) 插入删除，理解链表与数组的取舍。',
    concepts: <String>['std::list', '双向链表', 'splice', '迭代器稳定性'],
    objective: '用 list 做频繁中间插入删除，理解其访问代价。',
    prerequisites: <String>['迭代器类别'],
    standard: 'c++17',
    explain:
        'std::list 是双向链表，插入/删除是 O(1) 且不使其他元素迭代器失效，'
        '但随机访问是 O(n)、内存局部性差。它有成员 sort()/splice()，'
        '因为通用算法需要随机访问迭代器。',
    code: '#include <iostream>\n#include <list>\n\n'
        'int main() {\n'
        '    std::list<int> l = {3, 1, 2};\n'
        '    l.sort();\n'
        '    l.push_front(0);\n'
        '    auto it = l.begin();\n'
        '    ++it;\n'
        '    l.insert(it, 9);\n'
        '    for (int x : l) std::cout << x << " ";\n'
        '    std::cout << "\\n";\n'
        '    l.remove(9);\n'
        '    std::cout << "size=" << l.size() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '0 9 1 2 3 \nsize=4\n',
    pitfalls: <String>[
      'list 没有随机访问，不能用 std::sort，要用成员 sort()。',
      '中间插入快但每次都要遍历定位，整体未必比 vector 快。',
      '缓存不友好，大序列上 vector 往往更快。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 splice 把一个 list 的元素移动到另一个 list。',
        hint: 'dest.splice(pos, src)。',
        answer: 'src 变空，dest 包含合并后的元素。',
      ),
    ],
  ),
  ForgeTopic(
    id: 64,
    language: 'cpp',
    level: 'intermediate',
    title: 'std::stack 与 std::queue',
    summary: '用容器适配器获得栈（LIFO）与队列（FIFO）接口。',
    concepts: <String>['std::stack', 'std::queue', '容器适配器', 'LIFO/FIFO'],
    objective: '用 stack 和 queue 实现基本的数据结构操作。',
    prerequisites: <String>['std::deque：双端队列'],
    standard: 'c++17',
    explain:
        'std::stack 和 std::queue 是容器适配器：它们包装底层容器（默认 deque）'
        '只暴露受限接口。stack 是后进先出，push/pop/top；queue 是先进先出，'
        'push/pop/front/back。适配器让意图明确、避免误用。',
    code: '#include <iostream>\n#include <queue>\n#include <stack>\n\n'
        'int main() {\n'
        '    std::stack<int> s;\n'
        '    s.push(1); s.push(2); s.push(3);\n'
        '    std::cout << "stack:";\n'
        '    while (!s.empty()) { std::cout << " " << s.top(); s.pop(); }\n'
        '    std::cout << "\\n";\n\n'
        '    std::queue<int> q;\n'
        '    q.push(1); q.push(2); q.push(3);\n'
        '    std::cout << "queue:";\n'
        '    while (!q.empty()) { std::cout << " " << q.front(); q.pop(); }\n'
        '    std::cout << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'stack: 3 2 1\nqueue: 1 2 3\n',
    pitfalls: <String>[
      '空的 stack/queue 上调用 top/front/pop 是未定义行为，先判 empty。',
      'stack/queue 不支持遍历，只暴露顶端。',
      '需要优先队列用 std::priority_queue。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 stack 判断一个字符串的括号是否匹配。',
        hint: '遇左括号入栈，遇右括号弹出。',
        answer: '匹配则最后栈为空。',
      ),
    ],
  ),
  ForgeTopic(
    id: 65,
    language: 'cpp',
    level: 'intermediate',
    title: 'std::variant',
    summary: '用 std::variant 表达“多种类型之一”，类型安全地替代 union。',
    concepts: <String>['std::variant', 'std::get', 'std::visit', '代数数据类型'],
    objective: '用 variant 保存不同类型并安全访问。',
    prerequisites: <String>['std::optional 入门'],
    standard: 'c++17',
    explain:
        'std::variant<A,B,...> 任一时刻持有其中一种类型，比裸 union 安全（会正确构造析构）。'
        'std::get<T>/get<index> 取值（类型不符抛异常），std::visit 用访问者统一处理所有分支。'
        '它适合“结果可能是错误或值”这类场景。',
    code: '#include <iostream>\n#include <string>\n#include <variant>\n\n'
        'int main() {\n'
        '    std::variant<int, std::string> v;\n'
        '    v = 42;\n'
        '    std::cout << std::get<int>(v) << "\\n";\n'
        '    v = std::string("hello");\n'
        '    std::cout << std::get<std::string>(v) << "\\n";\n'
        '    std::cout << "index=" << v.index() << "\\n";\n'
        '    std::visit([](const auto& x) { std::cout << "visit:" << x << "\\n"; }, v);\n'
        '    return 0;\n'
        '}\n',
    output: '42\nhello\nindex=1\nvisit:hello\n',
    pitfalls: <String>[
      'std::get 用了错误的类型会抛 std::bad_variant_access。',
      'variant 默认构造第一个可默认构造的类型，注意别访问错。',
      'std::visit 的访问者要能处理所有备选类型。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 std::holds_alternative 判断当前持有哪种类型。',
        hint: 'holds_alternative<int>(v)。',
        answer: '字符串时返回 false。',
      ),
    ],
  ),
  ForgeTopic(
    id: 66,
    language: 'cpp',
    level: 'intermediate',
    title: 'stringstream 格式化与解析',
    summary: '综合用 stringstream 做表格化文本生成与字段解析。',
    concepts: <String>['stringstream', '格式化', '解析', '分隔符'],
    objective: '用 stringstream 生成带分隔符的记录并重新解析。',
    prerequisites: <String>['stringstream：字符串作为流'],
    standard: 'c++17',
    explain:
        'stringstream 既能组装文本记录，也能按分隔符解析。'
        '生成 CSV 风格行时用 << 拼接；解析时用 getline(ss, field, \',\') 按逗号切分。'
        '它避免了手写字符串切分的边界错误。',
    code: '#include <iostream>\n#include <sstream>\n#include <string>\n#include <vector>\n\n'
        'int main() {\n'
        '    std::vector<std::pair<std::string, int>> data = {{"apple", 3}, {"pear", 5}};\n'
        '    std::ostringstream csv;\n'
        '    for (const auto& [name, count] : data) csv << name << "," << count << ";";\n'
        '    std::string text = csv.str();\n'
        '    std::cout << text << "\\n";\n\n'
        '    std::istringstream in(text);\n'
        '    std::string record;\n'
        '    int total = 0;\n'
        '    while (std::getline(in, record, \';\')) {\n'
        '        if (record.empty()) continue;\n'
        '        std::istringstream rs(record);\n'
        '        std::string name, countStr;\n'
        '        std::getline(rs, name, \',\');\n'
        '        std::getline(rs, countStr, \',\');\n'
        '        total += std::stoi(countStr);\n'
        '    }\n'
        '    std::cout << "total=" << total << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'apple,3;pear,5;\ntotal=8\n',
    pitfalls: <String>[
      'getline 的第三个参数是分隔符；末尾分隔符会产生空记录。',
      'std::stoi 解析失败会抛异常，健壮代码要捕获。',
      '重复用 stringstream 要 clear() 重置状态。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给数据再加一条记录，观察 total 变化。',
        hint: '在初始化列表里加一项。',
        answer: 'total 增加对应数值。',
      ),
    ],
  ),
  ForgeTopic(
    id: 67,
    language: 'cpp',
    level: 'intermediate',
    title: 'std::error_code 错误处理',
    summary: '用 error_code 表达可预期的失败，避免异常与哨兵值。',
    concepts: <String>['std::error_code', '错误码', '异常 vs 错误码', '可预期错误'],
    objective: '用 error_code 返回可预期的失败并检查。',
    prerequisites: <String>['多种异常与自定义异常'],
    standard: 'c++17',
    explain:
        'std::error_code 携带错误码和类别，适合“打开文件失败”这类可预期、'
        '调用方需要就地处理的错误。异常适合无法就地处理的错误。'
        '两者并不互斥：标准库部分接口同时提供 error_code 重载。',
    code: '#include <iostream>\n#include <system_error>\n\n'
        'std::error_code divide(int a, int b, int& out) {\n'
        '    if (b == 0) return std::make_error_code(std::errc::invalid_argument);\n'
        '    out = a / b;\n'
        '    return {};\n'
        '}\n\n'
        'int main() {\n'
        '    int result = 0;\n'
        '    if (auto ec = divide(10, 2, result)) {\n'
        '        std::cout << "error: " << ec.message() << "\\n";\n'
        '    } else {\n'
        '        std::cout << "result=" << result << "\\n";\n'
        '    }\n'
        '    if (auto ec = divide(1, 0, result)) {\n'
        '        std::cout << "error: " << ec.message() << "\\n";\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: 'result=5\nerror: Invalid argument\n',
    pitfalls: <String>[
      'error_code 为 0/false 表示成功，注意判断方向。',
      '别把可预期错误也抛异常，反之亦然。',
      'ec.message() 的文本随平台/本地化变化，别依赖精确文本。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个 parse 函数用 error_code 报告非法输入。',
        hint: '失败返回 errc::invalid_argument。',
        answer: '合法输入写入 out 并返回空 error_code。',
      ),
    ],
  ),
  ForgeTopic(
    id: 68,
    language: 'cpp',
    level: 'intermediate',
    title: 'const 正确性进阶',
    summary: '用 mutable、const 重载、返回 const 引用精确表达只读与惰性缓存。',
    concepts: <String>['mutable', 'const 重载', 'const 返回值', '惰性求值'],
    objective: '用 mutable 做惰性缓存，用 const 重载区分读写。',
    prerequisites: <String>['虚函数与动态派发'],
    standard: 'c++17',
    explain:
        'mutable 成员可在 const 成员函数里修改，常用于缓存/计数这类'
        '不改变“逻辑状态”的实现细节。operator[] 可同时提供 const（只读）与'
        '非 const（可写）重载，const 对象走只读版本。',
    code: '#include <iostream>\n#include <string>\n\n'
        'class Word {\n'
        'public:\n'
        '    explicit Word(std::string text) : text_(std::move(text)) {}\n'
        '    std::size_t size() const {\n'
        '        if (cachedSize_ == 0) {\n'
        '            cachedSize_ = text_.size();  // mutable 缓存\n'
        '        }\n'
        '        return cachedSize_;\n'
        '    }\n'
        'private:\n'
        '    std::string text_;\n'
        '    mutable std::size_t cachedSize_ = 0;\n'
        '};\n\n'
        'int main() {\n'
        '    const Word w("hello");\n'
        '    std::cout << w.size() << "\\n";\n'
        '    std::cout << w.size() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '5\n5\n',
    pitfalls: <String>[
      'mutable 是给实现细节用的，别用它绕过 const 语义去改逻辑状态。',
      'mutable 在多线程下可能引入数据竞争。',
      '返回 const 引用时要确保对象在调用者使用期间存活。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把缓存改成统计 size() 被调用次数并打印。',
        hint: '用 mutable 计数器。',
        answer: '第二次调用后计数为 2。',
      ),
    ],
  ),
  ForgeTopic(
    id: 69,
    language: 'cpp',
    level: 'intermediate',
    title: '类型转换：static_cast 与 dynamic_cast',
    summary: '用 static_cast 做编译期已知的转换，用 dynamic_cast 做多态下的安全向下转换。',
    concepts: <String>['static_cast', 'dynamic_cast', '向下转换', 'RTTI'],
    objective: '用 static_cast 与 dynamic_cast 做正确的类型转换。',
    prerequisites: <String>['虚析构函数'],
    standard: 'c++17',
    explain:
        'static_cast 用于相关类型间的编译期转换（数值、上行转换），不做运行期检查。'
        'dynamic_cast 在多态类型间做运行期检查的向下/交叉转换，失败对指针返回 nullptr、'
        '对引用抛 bad_cast。C 风格强制转换不安全，应避免。',
    code: '#include <iostream>\n\n'
        'class Base {\n'
        'public:\n'
        '    virtual ~Base() = default;\n'
        '};\n'
        'class Derived : public Base {\n'
        'public:\n'
        '    void hello() const { std::cout << "derived\\n"; }\n'
        '};\n\n'
        'int main() {\n'
        '    double d = 3.9;\n'
        '    int i = static_cast<int>(d);\n'
        '    std::cout << i << "\\n";\n'
        '    Base* b = new Derived();\n'
        '    if (auto* p = dynamic_cast<Derived*>(b)) {\n'
        '        p->hello();\n'
        '    }\n'
        '    Base* plain = new Base();\n'
        '    std::cout << (dynamic_cast<Derived*>(plain) == nullptr) << "\\n";\n'
        '    delete b;\n'
        '    delete plain;\n'
        '    return 0;\n'
        '}\n',
    output: '3\nderived\n1\n',
    pitfalls: <String>[
      'static_cast 向下转换不做检查，转错类型是未定义行为。',
      'dynamic_cast 需要基类至少有一个虚函数（多态类型）。',
      'reinterpret_cast 最危险，除底层字节操作外尽量别用。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 static_cast<int>(3.9) 换成 static_cast<int>(3.2) 观察结果。',
        hint: 'static_cast 对数值是截断而非四舍五入。',
        answer: '输出 3。',
      ),
    ],
  ),
];
