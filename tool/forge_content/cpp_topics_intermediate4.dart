import 'forge_topic.dart';

/// C++ intermediate track, part 4 of 6: topics 56..62.
const List<ForgeTopic> cppTopicsIntermediate4 = <ForgeTopic>[
  ForgeTopic(
    id: 56,
    language: 'cpp',
    level: 'intermediate',
    title: '模板特化',
    summary: '为特定类型提供模板的专门实现，理解全特化与偏特化。',
    concepts: <String>['全特化', '偏特化', '模板匹配', '定制行为'],
    objective: '为一个通用模板提供特定类型的特化版本。',
    prerequisites: <String>['类模板'],
    standard: 'c++17',
    explain:
        '模板特化让某个具体类型走专用实现。全特化 template <> 指定所有参数；'
        '偏特化只固定部分参数（类模板可用）。'
        '特化常用于优化特定类型或为指针类型提供不同语义。',
    code: '#include <iostream>\n#include <string>\n\n'
        'template <typename T>\n'
        'struct TypeName { static const char* get() { return "unknown"; } };\n\n'
        'template <>\n'
        'struct TypeName<int> { static const char* get() { return "int"; } };\n\n'
        'template <>\n'
        'struct TypeName<double> { static const char* get() { return "double"; } };\n\n'
        'int main() {\n'
        '    std::cout << TypeName<int>::get() << "\\n";\n'
        '    std::cout << TypeName<double>::get() << "\\n";\n'
        '    std::cout << TypeName<std::string>::get() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'int\ndouble\nunknown\n',
    pitfalls: <String>[
      '全特化要写 template <> 且列全所有模板参数。',
      '函数模板不支持偏特化，只能用重载或 if constexpr 替代。',
      '特化必须在被使用前可见。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '为 TypeName<char> 加一个特化返回 "char"。',
        hint: '仿照 int 的写法。',
        answer: 'TypeName<char>::get() 返回 "char"。',
      ),
    ],
  ),
  ForgeTopic(
    id: 57,
    language: 'cpp',
    level: 'intermediate',
    title: '迭代器基础',
    summary: '用迭代器遍历容器，理解 begin/end 与解引用、前进。',
    concepts: <String>['迭代器', 'begin/end', '解引用', '++'],
    objective: '用迭代器遍历并修改容器元素。',
    prerequisites: <String>['std::vector：动态数组'],
    standard: 'c++17',
    explain:
        '迭代器是容器与算法之间的桥梁：它像指针一样支持 *（取值）、++（前进）、==（比较）。'
        'begin() 指向首元素，end() 指向尾后位置（不指向元素）。半开区间 [begin, end) '
        '是标准库的统一约定。',
    code: '#include <iostream>\n#include <vector>\n\n'
        'int main() {\n'
        '    std::vector<int> v = {10, 20, 30};\n'
        '    for (auto it = v.begin(); it != v.end(); ++it) {\n'
        '        *it += 1;\n'
        '    }\n'
        '    for (auto it = v.begin(); it != v.end(); ++it) {\n'
        '        std::cout << *it << " ";\n'
        '    }\n'
        '    std::cout << "\\n";\n'
        '    auto it = v.begin();\n'
        '    std::cout << *(it + 1) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '11 21 31 \n21\n',
    pitfalls: <String>[
      '解引用 end() 是未定义行为。',
      '改动容器（插入/删除）后原有迭代器可能失效。',
      '不同容器的迭代器能力不同（随机访问 vs 前向）。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用迭代器找出 v 中值为 21 的元素位置。',
        hint: '遍历比较 *it == 21。',
        answer: '在第二个位置（索引 1）。',
      ),
    ],
  ),
  ForgeTopic(
    id: 58,
    language: 'cpp',
    level: 'intermediate',
    title: '迭代器类别',
    summary: '区分输入、前向、双向、随机访问迭代器的能力差异。',
    concepts: <String>['迭代器类别', '随机访问', '双向', '算法约束'],
    objective: '说明不同容器提供的迭代器能力以及算法的要求。',
    prerequisites: <String>['迭代器基础'],
    standard: 'c++17',
    explain:
        '迭代器按能力分级：输入/输出（单遍）、前向（多遍）、双向（可 --）、'
        '随机访问（可 +n、-、<）。算法要求特定类别，例如 std::sort 需要随机访问，'
        '所以 std::list 不能用它（list 只提供双向迭代器）。',
    code: '#include <forward_list>\n#include <iostream>\n#include <list>\n#include <vector>\n\n'
        'int main() {\n'
        '    std::vector<int> v = {1, 2, 3};\n'
        '    std::list<int> l = {4, 5, 6};\n'
        '    std::forward_list<int> f = {7, 8, 9};\n'
        '    std::cout << v[1] << "\\n";           // 随机访问\n'
        '    auto lit = l.begin();\n'
        '    ++lit; --lit;                          // 双向\n'
        '    std::cout << *lit << "\\n";\n'
        '    int sum = 0;\n'
        '    for (int x : f) sum += x;               // 前向遍历\n'
        '    std::cout << sum << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '2\n4\n24\n',
    pitfalls: <String>[
      '对 list/forward_list 用 std::sort 会编译失败，它们有成员 sort。',
      'vector 迭代器是随机访问，可直接 it + n。',
      '算法要求的迭代器类别不够会编译报错，看错误信息里的类别提示。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '尝试对 std::list 调用 std::sort，观察编译错误。',
        hint: '改为调用 list 的成员 sort()。',
        answer: 'std::sort(l.begin(), l.end()) 编译失败，应写 l.sort()。',
      ),
    ],
  ),
  ForgeTopic(
    id: 59,
    language: 'cpp',
    level: 'intermediate',
    title: 'std::map：有序键值表',
    summary: '用 std::map 存储键值对，按键有序、查找对数时间。',
    concepts: <String>['std::map', '键值对', 'operator[]', 'find'],
    objective: '插入、查找、遍历 map，理解其有序性与 O(log n)。',
    prerequisites: <String>['结构化绑定'],
    standard: 'c++17',
    explain:
        'std::map<K,V> 是按键有序的红黑树，查找/插入 O(log n)。'
        '[] 会插入默认值（键不存在时），count/find 用于只查询。'
        '遍历时按 key 升序，配合结构化绑定 auto& [k, v] 很简洁。',
    code: '#include <iostream>\n#include <map>\n#include <string>\n\n'
        'int main() {\n'
        '    std::map<std::string, int> ages;\n'
        '    ages["alice"] = 30;\n'
        '    ages["bob"] = 25;\n'
        '    ages["carol"] = 28;\n'
        '    std::cout << "alice=" << ages["alice"] << "\\n";\n'
        '    std::cout << "count bob=" << ages.count("bob") << "\\n";\n'
        '    for (const auto& [name, age] : ages) {\n'
        '        std::cout << name << ":" << age << " ";\n'
        '    }\n'
        '    std::cout << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'alice=30\ncount bob=1\nalice:30 bob:25 carol:28 \n',
    pitfalls: <String>[
      'ages[key] 在键不存在时会插入默认值，只查询用 find/count。',
      'map 的 key 必须可比较（有 operator<）。',
      '需要哈希性能时用 unordered_map。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 find 判断 "dave" 是否存在并打印结果。',
        hint: 'ages.find("dave") == ages.end() 表示不存在。',
        answer: '打印 1（表示不存在）。',
      ),
    ],
  ),
  ForgeTopic(
    id: 60,
    language: 'cpp',
    level: 'intermediate',
    title: 'std::unordered_map：哈希表',
    summary: '用无序哈希表获得平均 O(1) 的键值查找。',
    concepts: <String>['unordered_map', '哈希', '平均 O(1)', '桶'],
    objective: '用 unordered_map 做高频键值查询。',
    prerequisites: <String>['std::map：有序键值表'],
    standard: 'c++17',
    explain:
        'std::unordered_map 用哈希表实现，平均 O(1) 查找，但无序、最坏 O(n)。'
        '键需要 std::hash 特化与 operator==。'
        '不需要有序遍历时，它通常比 map 更快。',
    code: '#include <iostream>\n#include <string>\n#include <unordered_map>\n\n'
        'int main() {\n'
        '    std::unordered_map<std::string, int> freq;\n'
        '    for (const char* w : {"a", "b", "a", "c", "a"}) ++freq[w];\n'
        '    std::cout << "a=" << freq["a"] << "\\n";\n'
        '    std::cout << "size=" << freq.size() << "\\n";\n'
        '    std::cout << "has b=" << (freq.count("b") > 0) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'a=3\nsize=3\nhas b=1\n',
    pitfalls: <String>[
      'unordered_map 遍历顺序不确定，不要依赖它。',
      '哈希冲突严重时退化为 O(n)，必要时调整桶数或换哈希。',
      '自定义类型作 key 需提供 std::hash 特化。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '统计输入中每个单词出现的次数（用 freq 输出 a/b/c）。',
        hint: '遍历 map 打印 k:v。',
        answer: 'a=3 b=1 c=1（顺序不限）。',
      ),
    ],
  ),
  ForgeTopic(
    id: 61,
    language: 'cpp',
    level: 'intermediate',
    title: 'std::set 与 unordered_set',
    summary: '用 set 去重并保持有序，用 unordered_set 获得最快成员查询。',
    concepts: <String>['std::set', 'unordered_set', '去重', '成员查询'],
    objective: '用 set/unordered_set 去重与查询成员。',
    prerequisites: <String>['std::unordered_map：哈希表'],
    standard: 'c++17',
    explain:
        'std::set 是按键有序、元素唯一的树，insert 返回是否新插入；'
        'unordered_set 是哈希版本，平均 O(1) 查询但无序。'
        '它们天然去重，适合“是否出现过”这类判断。',
    code: '#include <iostream>\n#include <set>\n#include <vector>\n\n'
        'int main() {\n'
        '    std::vector<int> nums = {3, 1, 3, 2, 1};\n'
        '    std::set<int> unique;\n'
        '    for (int x : nums) unique.insert(x);\n'
        '    std::cout << "unique=" << unique.size() << "\\n";\n'
        '    for (int x : unique) std::cout << x << " ";\n'
        '    std::cout << "\\n";\n'
        '    std::cout << "has 2=" << (unique.count(2) > 0) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'unique=3\n1 2 3 \nhas 2=1\n',
    pitfalls: <String>[
      'set 元素不可就地修改（会破坏有序性），要先删再插。',
      'insert 返回 pair<iterator,bool>，bool 表示是否新插入。',
      '只判断存在性优先用 unordered_set。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 set 求两个数组的交集。',
        hint: '把第一个放 set，遍历第二个查 count。',
        answer: '打印同时出现在两个数组里的元素。',
      ),
    ],
  ),
  ForgeTopic(
    id: 62,
    language: 'cpp',
    level: 'intermediate',
    title: 'std::deque：双端队列',
    summary: '用 deque 在两端高效增删，理解与 vector 的取舍。',
    concepts: <String>['std::deque', 'push_front', 'push_back', '分段存储'],
    objective: '用 deque 在两端增删并随机访问。',
    prerequisites: <String>['std::vector：动态数组'],
    standard: 'c++17',
    explain:
        'std::deque 支持在两端 O(1) 增删并随机访问，内部是分段连续存储。'
        '它不像 vector 那样要求整体连续，因此 front 插入便宜，但内存局部性略差。'
        '需要双端操作时选 deque，只在一端增长优先 vector。',
    code: '#include <deque>\n#include <iostream>\n\n'
        'int main() {\n'
        '    std::deque<int> d;\n'
        '    d.push_back(2);\n'
        '    d.push_back(3);\n'
        '    d.push_front(1);\n'
        '    for (int x : d) std::cout << x << " ";\n'
        '    std::cout << "\\n";\n'
        '    std::cout << "front=" << d.front() << " back=" << d.back() << "\\n";\n'
        '    d.pop_front();\n'
        '    std::cout << "size=" << d.size() << " front=" << d.front() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '1 2 3 \nfront=1 back=3\nsize=2 front=2\n',
    pitfalls: <String>[
      'deque 不保证整体连续，不能传给需要连续数组的 C 接口。',
      '中间插入仍是 O(n)。',
      '迭代器在两端增删时也可能失效。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 deque 模拟队列：push_back 入队、pop_front 出队。',
        hint: 'FIFO：从尾进、从头出。',
        answer: '依次出队顺序与入队一致。',
      ),
    ],
  ),
];
