import 'forge_topic.dart';

/// C curriculum — advanced / engineering track, part C (topics 88..100).
///
/// Big integers, config parsing, hash tables, bitsets, a stack VM, arena
/// allocation, intrusive lists, a benchmark harness and the capstone.
const List<ForgeTopic> cTopicsAdvC = <ForgeTopic>[
  ForgeTopic(
    id: 88,
    language: 'c',
    level: 'advanced',
    title: 'C 088：大整数加法',
    standard: 'c17',
    concepts: <String>['大整数', '进位', '字符串转数字'],
    objective: '用数组模拟超出整数范围的大数加法。',
    prerequisites: <String>['C 022'],
    summary: '把每一位存进数组，手工模拟进位。',
    explain:
        '当数字超过 64 位，就要自己实现大整数：把每一位数字存进数组，从低位到高位相加，处理进位。示例用十进制字符串倒序存进数组，逐位相加并输出。这是理解「数据表示决定能力上限」的好例子。',
    code:
        '#include <stdio.h>\n'
        '#include <string.h>\n'
        '\n'
        'int main(void) {\n'
        '    const char *sa = "98765432109876543210";\n'
        '    const char *sb = "12345678901234567890";\n'
        '    int la = (int)strlen(sa), lb = (int)strlen(sb);\n'
        '    int a[64] = {0}, b[64] = {0}, sum[65] = {0};\n'
        '    for (int i = 0; i < la; i++) a[i] = sa[la - 1 - i] - \'0\';\n'
        '    for (int i = 0; i < lb; i++) b[i] = sb[lb - 1 - i] - \'0\';\n'
        '    int n = la > lb ? la : lb;\n'
        '    int carry = 0;\n'
        '    for (int i = 0; i < n; i++) {\n'
        '        int s = a[i] + b[i] + carry;\n'
        '        sum[i] = s % 10;\n'
        '        carry = s / 10;\n'
        '    }\n'
        '    if (carry) { sum[n] = carry; n++; }\n'
        '    printf("sum=");\n'
        '    for (int i = n - 1; i >= 0; i--) printf("%d", sum[i]);\n'
        '    printf("\\n");\n'
        '    return 0;\n'
        '}\n',
    output: 'sum=111111111011111111100\n',
    pitfalls: <String>['最低位在数组下标 0，输出时要倒着打印。', '最高位可能因进位多出一位。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '在大整数实现里加一个「加 0」的校验，确保 a+0 == a。',
        hint: '把 b 全部设 0 再相加。',
        answer: 'memset(b, 0, sizeof(b)); // 再相加应得到原数',
      ),
    ],
  ),
  ForgeTopic(
    id: 89,
    language: 'c',
    level: 'advanced',
    title: 'C 089：INI 风格配置解析',
    standard: 'c17',
    concepts: <String>['配置解析', '键值对', '默认值', '健壮性'],
    objective: '解析一个简单的 key=value 配置。',
    prerequisites: <String>['C 074'],
    summary: '处理键值对、注释、缺失键的默认值。',
    explain:
        '配置解析要把文本变成程序能用的设置。常见规则：跳过空行和以 # 开头的注释，按 = 拆键值，去掉两端空白，找不到键时用默认值。健壮性体现在：格式错误不崩溃，只是忽略或报错。',
    code:
        '#include <stdio.h>\n'
        '#include <string.h>\n'
        '#include <stdlib.h>\n'
        '\n'
        'static void trim(char *s) {\n'
        '    while (*s == \' \' || *s == \'\\t\') memmove(s, s + 1, strlen(s));\n'
        '    size_t n = strlen(s);\n'
        '    while (n > 0 && (s[n-1] == \' \' || s[n-1] == \'\\n\')) s[--n] = \'\\0\';\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    const char *lines[] = {"# config", "port = 8080", "", "debug = 1"};\n'
        '    int port = 80, debug = 0;\n'
        '    for (int i = 0; i < 4; i++) {\n'
        '        const char *line = lines[i];\n'
        '        if (line[0] == \'#\' || line[0] == \'\\0\') continue;\n'
        '        char buf[64];\n'
        '        strncpy(buf, line, sizeof(buf) - 1);\n'
        '        buf[sizeof(buf) - 1] = \'\\0\';\n'
        '        char *eq = strchr(buf, \'=\');\n'
        '        if (!eq) continue;\n'
        '        *eq = \'\\0\';\n'
        '        char *key = buf, *val = eq + 1;\n'
        '        trim(key); trim(val);\n'
        '        if (strcmp(key, "port") == 0) port = atoi(val);\n'
        '        else if (strcmp(key, "debug") == 0) debug = atoi(val);\n'
        '    }\n'
        '    printf("port=%d debug=%d\\n", port, debug);\n'
        '    return 0;\n'
        '}\n',
    output: 'port=8080 debug=1\n',
    pitfalls: <String>['strncpy 不保证结尾 \\0，要手动补。', '键不存在时保留默认值，不要用垃圾值。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '增加一个 name 键（字符串值），缺省为 "default"。',
        hint: '用 strcmp 匹配 "name" 再 strcpy 到缓冲区。',
        answer:
            'char name[32] = "default";\n// if (strcmp(key, "name") == 0) strncpy(name, val, sizeof(name)-1);',
      ),
    ],
  ),
  ForgeTopic(
    id: 90,
    language: 'c',
    level: 'advanced',
    title: 'C 090：哈希表实现',
    standard: 'c17',
    concepts: <String>['哈希表', '拉链法', '插入查找', '扩容'],
    objective: '用拉链法实现一个字符串到整数的哈希表。',
    prerequisites: <String>['C 075'],
    summary: '数组 + 链表解决冲突。',
    explain:
        '哈希表用一个桶数组，每个桶是一条链表（拉链法）。插入时算出桶下标，遍历链表看键是否已存在，否则头插。查找同理。装载因子过高时要扩容并重新散列。示例用固定大小桶，演示核心的插入和查找。',
    code:
        '#include <stdio.h>\n'
        '#include <stdlib.h>\n'
        '#include <string.h>\n'
        '\n'
        'typedef struct Entry {\n'
        '    char key[16];\n'
        '    int value;\n'
        '    struct Entry *next;\n'
        '} Entry;\n'
        '\n'
        '#define BUCKETS 8\n'
        '\n'
        'static unsigned hashOf(const char *s) {\n'
        '    unsigned h = 5381;\n'
        '    while (*s) h = h * 33 + (unsigned char)*s++;\n'
        '    return h % BUCKETS;\n'
        '}\n'
        '\n'
        'static void put(Entry **table, const char *key, int value) {\n'
        '    unsigned b = hashOf(key);\n'
        '    for (Entry *e = table[b]; e; e = e->next)\n'
        '        if (strcmp(e->key, key) == 0) { e->value = value; return; }\n'
        '    Entry *e = (Entry *)malloc(sizeof(Entry));\n'
        '    strncpy(e->key, key, sizeof(e->key) - 1);\n'
        '    e->key[sizeof(e->key) - 1] = \'\\0\';\n'
        '    e->value = value;\n'
        '    e->next = table[b];\n'
        '    table[b] = e;\n'
        '}\n'
        '\n'
        'static int *get(Entry **table, const char *key) {\n'
        '    for (Entry *e = table[hashOf(key)]; e; e = e->next)\n'
        '        if (strcmp(e->key, key) == 0) return &e->value;\n'
        '    return NULL;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    Entry *table[BUCKETS] = {0};\n'
        '    put(table, "one", 1);\n'
        '    put(table, "two", 2);\n'
        '    put(table, "one", 100);\n'
        '    int *v = get(table, "one");\n'
        '    printf("one=%d\\n", v ? *v : -1);\n'
        '    printf("missing=%d\\n", get(table, "nope") == NULL);\n'
        '    for (int i = 0; i < BUCKETS; i++)\n'
        '        for (Entry *e = table[i]; e; ) { Entry *n = e->next; free(e); e = n; }\n'
        '    return 0;\n'
        '}\n',
    output: 'one=100\nmissing=1\n',
    pitfalls: <String>['键是定长数组，过长键要处理截断。', '重复键要更新而不是再插一个。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '统计哈希表里当前有多少个键。',
        hint: '遍历所有桶的链表累加计数。',
        answer:
            'int count = 0;\nfor (int i = 0; i < BUCKETS; i++) for (Entry *e = table[i]; e; e = e->next) count++;',
      ),
    ],
  ),
  ForgeTopic(
    id: 91,
    language: 'c',
    level: 'advanced',
    title: 'C 091：位图与集合',
    standard: 'c17',
    concepts: <String>['位图', 'bitset', '空间效率', '集合运算'],
    objective: '用一个整数数组表示一个整数集合。',
    prerequisites: <String>['C 048'],
    summary: '用每个 bit 表示一个数在不在集合里。',
    explain:
        '位图用一个 bit 表示一个元素是否存在。存 0..63 只需一个 64 位整数：置位用 |= (1<<i)，判断用 >>i & 1。它极其省空间，常用于去重、筛法和集合运算。更大的范围就用 unsigned long 数组。',
    code:
        '#include <stdio.h>\n'
        '#include <stdint.h>\n'
        '\n'
        'int main(void) {\n'
        '    uint64_t set = 0;\n'
        '    int values[] = {3, 7, 3, 12, 7};\n'
        '    for (int i = 0; i < 5; i++) set |= (uint64_t)1 << values[i];\n'
        '    printf("has 3=%d\\n", (int)((set >> 3) & 1));\n'
        '    printf("has 5=%d\\n", (int)((set >> 5) & 1));\n'
        '    printf("count=%d\\n", __builtin_popcountll(set));\n'
        '    return 0;\n'
        '}\n',
    output: 'has 3=1\nhas 5=0\ncount=3\n',
    pitfalls: <String>[
      '下标不能超过位宽，否则溢出到未定义。',
      '统计 1 的个数可用 __builtin_popcountll（GCC/Clang）。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '求两个位图集合的交集大小。',
        hint: '交集是 a & b，再 popcount。',
        answer:
            'uint64_t inter = a & b;\nprintf("%d\\n", __builtin_popcountll(inter));',
      ),
    ],
  ),
  ForgeTopic(
    id: 92,
    language: 'c',
    level: 'advanced',
    title: 'C 092：简易栈式虚拟机',
    standard: 'c17',
    concepts: <String>['虚拟机', '字节码', '栈', '解释器'],
    objective: '用栈实现一个能算加减乘的字节码解释器。',
    prerequisites: <String>['C 064'],
    summary: '把操作码和数据流分开执行。',
    explain:
        '虚拟机用一条字节码指令流描述操作，用一个栈保存中间值。示例定义 PUSH/ADD/MUL/PRINT 四种操作码，循环读取指令并执行。表达式 (10 + 20) * 2 编译成 PUSH 10, PUSH 20, ADD, PUSH 2, MUL, PRINT。',
    code:
        '#include <stdio.h>\n'
        '\n'
        'enum Op { OP_PUSH, OP_ADD, OP_MUL, OP_PRINT, OP_HALT };\n'
        '\n'
        'int main(void) {\n'
        '    int code[] = {OP_PUSH, 10, OP_PUSH, 20, OP_ADD, OP_PUSH, 2, OP_MUL, OP_PRINT, OP_HALT};\n'
        '    int stack[64];\n'
        '    int sp = 0;\n'
        '    for (int ip = 0; code[ip] != OP_HALT; ip++) {\n'
        '        switch (code[ip]) {\n'
        '            case OP_PUSH: stack[sp++] = code[++ip]; break;\n'
        '            case OP_ADD: { int b = stack[--sp], a = stack[--sp]; stack[sp++] = a + b; break; }\n'
        '            case OP_MUL: { int b = stack[--sp], a = stack[--sp]; stack[sp++] = a * b; break; }\n'
        '            case OP_PRINT: printf("result=%d\\n", stack[--sp]); break;\n'
        '            default: break;\n'
        '        }\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: 'result=60\n',
    pitfalls: <String>['PUSH 后面紧跟数据，要记得跳过它占的那一格。', '栈指针不能越界；二元运算前要确认栈里有两个操作数。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '增加一个 OP_SUB 操作码并测试 50-8。',
        hint: '仿照 OP_ADD，弹两个再压回 a-b。',
        answer:
            'case OP_SUB: { int b = stack[--sp], a = stack[--sp]; stack[sp++] = a - b; break; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 93,
    language: 'c',
    level: 'advanced',
    title: 'C 093：内存池/竞技场分配',
    standard: 'c17',
    concepts: <String>['arena', '内存池', '批量释放', '性能'],
    objective: '用一个连续缓冲实现批量分配与整体释放。',
    prerequisites: <String>['C 052'],
    summary: '一次性申请大块，用完整体重置。',
    explain:
        '竞技场分配器先申请一大块内存，之后每次分配只是把偏移往后推，释放时不用逐个 free，而是整体重置。它适合生命周期一致的对象（如一次请求里解析出的所有节点），能显著减少 malloc 次数和碎片。代价是不能单独释放某个对象。',
    code:
        '#include <stdio.h>\n'
        '#include <stddef.h>\n'
        '\n'
        'typedef struct {\n'
        '    unsigned char buffer[256];\n'
        '    size_t offset;\n'
        '} Arena;\n'
        '\n'
        'void *arenaAlloc(Arena *a, size_t size) {\n'
        '    size_t aligned = (size + 7) & ~(size_t)7;\n'
        '    if (a->offset + aligned > sizeof(a->buffer)) return NULL;\n'
        '    void *p = a->buffer + a->offset;\n'
        '    a->offset += aligned;\n'
        '    return p;\n'
        '}\n'
        'void arenaReset(Arena *a) { a->offset = 0; }\n'
        '\n'
        'int main(void) {\n'
        '    Arena arena = {{0}, 0};\n'
        '    int *a = (int *)arenaAlloc(&arena, sizeof(int));\n'
        '    double *d = (double *)arenaAlloc(&arena, sizeof(double));\n'
        '    *a = 42;\n'
        '    *d = 3.5;\n'
        '    printf("a=%d d=%.1f used=%zu\\n", *a, *d, arena.offset);\n'
        '    arenaReset(&arena);\n'
        '    printf("after reset used=%zu\\n", arena.offset);\n'
        '    return 0;\n'
        '}\n',
    output: 'a=42 d=3.5 used=16\nafter reset used=0\n',
    pitfalls: <String>['arena 里的对象生命周期一致，不能单独释放。', '分配要按对齐取整，否则未对齐访问可能出错。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '说明竞技场分配器适合和不适合的场景。',
        hint: '想想对象生命周期和对齐。',
        answer: '适合：一批生命周期相同、可整体释放的对象。不适合：需要单独释放或大小差异极大的对象。',
      ),
    ],
  ),
  ForgeTopic(
    id: 94,
    language: 'c',
    level: 'advanced',
    title: 'C 094：侵入式链表',
    standard: 'c17',
    concepts: <String>['侵入式', '链表节点', '零额外分配', 'container_of'],
    objective: '把链表节点嵌进数据结构本身。',
    prerequisites: <String>['C 064'],
    summary: '节点不需要单独分配，嵌在对象里。',
    explain:
        '普通链表为每个元素额外分配一个节点；侵入式链表把链表节点直接放进业务结构体里，元素自身就是节点，因此没有额外分配。代价是需要从节点的地址反推回宿主结构体的地址，常用 offsetof 技巧（container_of 宏）实现。',
    code:
        '#include <stdio.h>\n'
        '#include <stddef.h>\n'
        '\n'
        'typedef struct Node {\n'
        '    struct Node *next;\n'
        '} Node;\n'
        '\n'
        'typedef struct {\n'
        '    Node node;\n'
        '    int value;\n'
        '} Item;\n'
        '\n'
        '#define container_of(ptr, type, member) \\\n'
        '    ((type *)((char *)(ptr) - offsetof(type, member)))\n'
        '\n'
        'int main(void) {\n'
        '    Item items[3] = {{NULL, 10}, {NULL, 20}, {NULL, 30}};\n'
        '    items[0].node.next = &items[1].node;\n'
        '    items[1].node.next = &items[2].node;\n'
        '    for (Node *n = &items[0].node; n; n = n->next) {\n'
        '        Item *it = container_of(n, Item, node);\n'
        '        printf("%d ", it->value);\n'
        '    }\n'
        '    printf("\\n");\n'
        '    return 0;\n'
        '}\n',
    output: '10 20 30 \n',
    pitfalls: <String>[
      'container_of 依赖 offsetof，结构体布局变化时要小心。',
      '侵入式链表的一个元素不能同时挂在多条链表上（除非多个节点）。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 Item 加第二个 node 字段，让它能同时挂两条链。',
        hint: '在 struct 里加 Node node2; 分别串。',
        answer: 'typedef struct { Node node; Node node2; int value; } Item;',
      ),
    ],
  ),
  ForgeTopic(
    id: 95,
    language: 'c',
    level: 'advanced',
    title: 'C 095：基准测试脚手架',
    standard: 'c17',
    concepts: <String>['基准', '计时', '重复', '对比'],
    objective: '写一个对比两种实现的基准脚手架。',
    prerequisites: <String>['C 084'],
    summary: '反复运行取平均，减少噪声。',
    explain:
        '可靠的基准要多次运行取平均，并用足够的迭代次数让时间可测。对比两种实现时，输入规模和时间测量方式必须一致。还要防止编译器把「没用到的计算」优化掉——把结果累加到一个外部可见的量里。',
    code:
        '#include <stdio.h>\n'
        '#include <time.h>\n'
        '\n'
        'long long sumLoop(int n) { long long s = 0; for (int i = 1; i <= n; i++) s += i; return s; }\n'
        'long long sumFormula(int n) { return (long long)n * (n + 1) / 2; }\n'
        '\n'
        'int main(void) {\n'
        '    volatile long long sink = 0;\n'
        '    clock_t s1 = clock();\n'
        '    for (int r = 0; r < 1000; r++) sink += sumLoop(10000);\n'
        '    clock_t e1 = clock();\n'
        '    clock_t s2 = clock();\n'
        '    for (int r = 0; r < 1000; r++) sink += sumFormula(10000);\n'
        '    clock_t e2 = clock();\n'
        '    printf("sink=%lld\\n", sink);\n'
        '    printf("formula faster or equal=%d\\n", (e2 - s2) <= (e1 - s1));\n'
        '    return 0;\n'
        '}\n',
    output: 'sink=100010000000\nformula faster or equal=1\n',
    pitfalls: <String>['结果被优化掉会让耗时接近 0，要用 volatile 接收。', '只跑一两次噪声太大，要重复多次。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '增加一个冒泡排序的基准并测量其耗时。',
        hint: '生成随机数组后计时调用 bubble。',
        answer:
            'clock_t s = clock();\nfor (int r = 0; r < 100; r++) { /* copy + bubble */ }\nclock_t e = clock();',
      ),
    ],
  ),
  ForgeTopic(
    id: 96,
    language: 'c',
    level: 'advanced',
    title: 'C 096：状态机实现',
    standard: 'c17',
    concepts: <String>['状态机', 'enum', '转移表', '解析'],
    objective: '用状态机解析一个简单的数字串。',
    prerequisites: <String>['C 046'],
    summary: '根据当前状态和输入决定下一步。',
    explain:
        '状态机把行为建模成「状态 + 输入 -> 新状态 + 动作」。它广泛用于词法分析、协议解析和输入校验。示例用状态机校验一个字符串是否是合法整数（可选符号后跟至少一位数字），用枚举表示状态、用 switch 处理转移。',
    code:
        '#include <stdio.h>\n'
        '\n'
        'typedef enum { START, SIGN, DIGIT, ERROR, DONE } State;\n'
        '\n'
        'int main(void) {\n'
        '    const char *inputs[] = {"123", "-45", "+0", "-", "12x"};\n'
        '    for (int k = 0; k < 5; k++) {\n'
        '        State s = START;\n'
        '        for (const char *p = inputs[k]; *p && s != ERROR; p++) {\n'
        '            char c = *p;\n'
        '            switch (s) {\n'
        '                case START: s = (c == \'+\' || c == \'-\') ? SIGN : ((c >= \'0\' && c <= \'9\') ? DIGIT : ERROR); break;\n'
        '                case SIGN: s = (c >= \'0\' && c <= \'9\') ? DIGIT : ERROR; break;\n'
        '                case DIGIT: s = (c >= \'0\' && c <= \'9\') ? DIGIT : ERROR; break;\n'
        '                default: break;\n'
        '            }\n'
        '        }\n'
        '        int ok = (s == DIGIT) ? 1 : 0;\n'
        '        printf("%s -> %s\\n", inputs[k], ok ? "valid" : "invalid");\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output:
        '123 -> valid\n-45 -> valid\n+0 -> valid\n- -> invalid\n12x -> invalid\n',
    pitfalls: <String>['漏判某一类输入会让状态机接受非法串。', '接受状态要明确：只有 DIGIT 结束才算合法。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '扩展状态机支持小数（允许一个小数点）。',
        hint: '增加 DOT 状态，小数点只能出现一次。',
        answer:
            'typedef enum { START, SIGN, DIGIT, DOT, ERROR, DONE } State;\n// DIGIT 遇到 \'.\' 转到 DOT，DOT 后必须是数字',
      ),
    ],
  ),
  ForgeTopic(
    id: 97,
    language: 'c',
    level: 'advanced',
    title: 'C 097：接口设计——错误码与输出参数',
    standard: 'c17',
    concepts: <String>['错误码', '输出参数', 'API 设计', '约定'],
    objective: '用统一错误码和输出参数设计函数接口。',
    prerequisites: <String>['C 067'],
    summary: '返回值报错误，结果从输出参数带出。',
    explain:
        '一个稳健的 C 接口约定：函数返回错误码（0 成功，非 0 表示具体错误），真正的结果通过指针输出参数写回。这样调用方能区分「算出来的 0」和「出错了」。错误码用枚举集中定义，避免魔法数字。',
    code:
        '#include <stdio.h>\n'
        '\n'
        'typedef enum { OK = 0, ERR_DIV_ZERO = 1, ERR_OVERFLOW = 2 } Err;\n'
        '\n'
        'Err safeDiv(int a, int b, int *out) {\n'
        '    if (b == 0) return ERR_DIV_ZERO;\n'
        '    *out = a / b;\n'
        '    return OK;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    int result = 0;\n'
        '    Err e = safeDiv(84, 2, &result);\n'
        '    printf("e=%d result=%d\\n", e, result);\n'
        '    e = safeDiv(1, 0, &result);\n'
        '    printf("e=%d\\n", e);\n'
        '    return 0;\n'
        '}\n',
    output: 'e=0 result=42\ne=1\n',
    pitfalls: <String>['出错时不要写输出参数，调用方要先看错误码再看结果。', '错误码用枚举命名，别用裸数字。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 safeDiv 增加溢出检查：a 为最小值且 b 为 -1 时返回 ERR_OVERFLOW。',
        hint: '用 INT_MIN 判断。',
        answer:
            '#include <limits.h>\nif (a == INT_MIN && b == -1) return ERR_OVERFLOW;',
      ),
    ],
  ),
  ForgeTopic(
    id: 98,
    language: 'c',
    level: 'advanced',
    title: 'C 098：内存映射式解析',
    standard: 'c17',
    concepts: <String>['内存布局', '按字节访问', '类型双关', 'memcpy'],
    objective: '安全地把字节缓冲区解释成整数。',
    prerequisites: <String>['C 048'],
    summary: '不要用指针强转读未对齐数据。',
    explain:
        '从缓冲区里取出一个整数，直接 (int*)buf 强转可能在未对齐或严格别名下出错。稳妥做法是用 memcpy 把字节拷进一个对齐的整数变量。示例演示从字节数组按小端顺序拼出一个 32 位整数。',
    code:
        '#include <stdio.h>\n'
        '#include <stdint.h>\n'
        '#include <string.h>\n'
        '\n'
        'static uint32_t readLE(const unsigned char *p) {\n'
        '    uint32_t v = 0;\n'
        '    memcpy(&v, p, sizeof(v));\n'
        '    return v;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    unsigned char buf[4] = {0x78, 0x56, 0x34, 0x12};\n'
        '    uint32_t v = readLE(buf);\n'
        '    printf("value=0x%08X\\n", v);\n'
        '    return 0;\n'
        '}\n',
    output: 'value=0x12345678\n',
    pitfalls: <String>['指针强转读未对齐地址在部分平台会崩溃。', '字节序在不同机器上不同，跨平台要显式转换。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个把 16 位整数按小端写进缓冲区的函数。',
        hint: '用 memcpy 把值写进 buf。',
        answer:
            'void writeLE16(unsigned char *p, uint16_t v) { memcpy(p, &v, sizeof(v)); }',
      ),
    ],
  ),
  ForgeTopic(
    id: 99,
    language: 'c',
    level: 'advanced',
    title: 'C 099：综合练习——小型统计器',
    standard: 'c17',
    concepts: <String>['综合', '模块', '错误处理', '内存'],
    objective: '把句柄、动态数组、错误码组合成一个小型统计器。',
    prerequisites: <String>['C 068', 'C 097'],
    summary: '跨多个中级知识点完成一个小工具。',
    explain:
        '这个综合练习用一个句柄封装统计数据：add 往动态数组里追加数值，最后算平均、最大、最小。它把不透明指针、动态内存、错误码和遍历聚合串在一条链上，接近真实小工具的结构。',
    code:
        '#include <stdio.h>\n'
        '#include <stdlib.h>\n'
        '\n'
        'typedef struct Stats Stats;\n'
        'struct Stats { double *data; int size; int capacity; };\n'
        '\n'
        'Stats *statsCreate(int cap) {\n'
        '    Stats *s = (Stats *)malloc(sizeof(Stats));\n'
        '    s->data = (double *)malloc((size_t)cap * sizeof(double));\n'
        '    s->size = 0; s->capacity = cap;\n'
        '    return s;\n'
        '}\n'
        'void statsAdd(Stats *s, double v) {\n'
        '    if (s->size == s->capacity) {\n'
        '        s->capacity *= 2;\n'
        '        s->data = (double *)realloc(s->data, (size_t)s->capacity * sizeof(double));\n'
        '    }\n'
        '    s->data[s->size++] = v;\n'
        '}\n'
        'double statsMean(Stats *s) {\n'
        '    double sum = 0;\n'
        '    for (int i = 0; i < s->size; i++) sum += s->data[i];\n'
        '    return sum / s->size;\n'
        '}\n'
        'double statsMax(Stats *s) {\n'
        '    double m = s->data[0];\n'
        '    for (int i = 1; i < s->size; i++) if (s->data[i] > m) m = s->data[i];\n'
        '    return m;\n'
        '}\n'
        'void statsDestroy(Stats *s) { free(s->data); free(s); }\n'
        '\n'
        'int main(void) {\n'
        '    Stats *s = statsCreate(2);\n'
        '    double values[] = {12.0, 7.5, 9.0, 15.0, 4.5};\n'
        '    for (int i = 0; i < 5; i++) statsAdd(s, values[i]);\n'
        '    printf("mean=%.2f\\n", statsMean(s));\n'
        '    printf("max=%.1f\\n", statsMax(s));\n'
        '    statsDestroy(s);\n'
        '    return 0;\n'
        '}\n',
    output: 'mean=9.60\nmax=15.0\n',
    pitfalls: <String>[
      '扩容后必须使用 realloc 返回的新指针。',
      '句柄内部的 data 也要在 destroy 里释放。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给统计器加一个 statsMin 函数。',
        hint: '仿照 statsMax，比较改成 <。',
        answer:
            'double statsMin(Stats *s) { double m = s->data[0]; for (int i = 1; i < s->size; i++) if (s->data[i] < m) m = s->data[i]; return m; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 100,
    language: 'c',
    level: 'advanced',
    title: 'C 100：结业项目——词频统计器',
    standard: 'c17',
    concepts: <String>['综合项目', '哈希表', '字符串', '排序'],
    objective: '综合运用哈希、字符串与排序统计词频。',
    prerequisites: <String>['C 090', 'C 062'],
    summary: '把整门课的知识拼成一个可用的小工具。',
    explain:
        '结业项目把前面学的拼起来：按空白切分文本得到单词，用哈希表统计每个词出现次数，再按次数排序输出。示例硬编码一段文本以保证可重复运行，真实场景会从文件读入。这正是「学完能写出来的东西」。',
    code:
        '#include <stdio.h>\n'
        '#include <string.h>\n'
        '\n'
        'typedef struct { char word[16]; int count; } WordCount;\n'
        '\n'
        'int main(void) {\n'
        '    const char *text = "the cat the dog the bird cat";\n'
        '    WordCount counts[16];\n'
        '    int n = 0;\n'
        '    char buf[16];\n'
        '    int bi = 0;\n'
        '    for (int i = 0; ; i++) {\n'
        '        char c = text[i];\n'
        '        if (c == \' \' || c == \'\\0\') {\n'
        '            buf[bi] = \'\\0\';\n'
        '            if (bi > 0) {\n'
        '                int found = -1;\n'
        '                for (int j = 0; j < n; j++) if (strcmp(counts[j].word, buf) == 0) found = j;\n'
        '                if (found < 0) { strcpy(counts[n].word, buf); counts[n].count = 1; n++; }\n'
        '                else counts[found].count++;\n'
        '            }\n'
        '            bi = 0;\n'
        '            if (c == \'\\0\') break;\n'
        '        } else if (bi < 15) {\n'
        '            buf[bi++] = c;\n'
        '        }\n'
        '    }\n'
        '    for (int i = 0; i < n - 1; i++)\n'
        '        for (int j = 0; j < n - 1 - i; j++)\n'
        '            if (counts[j].count < counts[j + 1].count) {\n'
        '                WordCount t = counts[j]; counts[j] = counts[j + 1]; counts[j + 1] = t;\n'
        '            }\n'
        '    for (int i = 0; i < n; i++) printf("%s=%d\\n", counts[i].word, counts[i].count);\n'
        '    return 0;\n'
        '}\n',
    output: 'the=3\ncat=2\ndog=1\nbird=1\n',
    pitfalls: <String>['单词缓冲区要防溢出，bi 不能超过容量。', '排序按次数降序，相等次数的相对顺序取决于排序是否稳定。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '修改程序，只在次数 >= 2 时打印。',
        hint: '打印前加 if (counts[i].count >= 2)。',
        answer:
            'for (int i = 0; i < n; i++) if (counts[i].count >= 2) printf("%s=%d\\n", counts[i].word, counts[i].count);',
      ),
    ],
  ),
];
