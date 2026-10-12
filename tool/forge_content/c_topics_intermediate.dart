import 'forge_topic.dart';

/// C curriculum — intermediate track (topics 35..75).
///
/// Pointers and memory, strings and safety, structs and enums, function
/// pointers, recursion, sorting/searching, and core data structures. Every
/// `code` is a complete runnable C11 program with exact stdout in `output`.
const List<ForgeTopic> cTopicsIntermediate = <ForgeTopic>[
  ForgeTopic(
    id: 35,
    language: 'c',
    level: 'intermediate',
    title: 'C 035：指针入门——地址与解引用',
    standard: 'c17',
    concepts: <String>['指针', '& 取地址', '* 解引用', '指针类型'],
    objective: '理解指针存的是地址，学会用 & 和 * 读写。',
    prerequisites: <String>['C 034'],
    summary: '指针是地址，解引用是访问地址上的值。',
    explain:
        '指针变量存放另一个变量的地址，类型写成 int *。&x 取 x 的地址，*p 取出 p 指向的值。声明 int *p 与使用 *p 是两回事：声明里 * 表示「是指针」，表达式里 * 表示「解引用」。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int value = 42;\n'
        '    int *p = &value;\n'
        '    printf("value=%d\\n", value);\n'
        '    printf("*p=%d\\n", *p);\n'
        '    *p = 100;\n'
        '    printf("after *p=100, value=%d\\n", value);\n'
        '    printf("same address=%d\\n", p == &value);\n'
        '    return 0;\n'
        '}\n',
    output: 'value=42\n*p=42\nafter *p=100, value=100\nsame address=1\n',
    pitfalls: <String>[
      '解引用未初始化的指针会访问随机内存并崩溃。',
      'int *p, q; 里只有 p 是指针，q 是 int。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '通过指针把 value 变成 7，并打印新的值。',
        hint: '写 *p = 7; 再打印 value。',
        answer: '*p = 7;\nprintf("%d\\n", value); // 7',
      ),
    ],
  ),
  ForgeTopic(
    id: 36,
    language: 'c',
    level: 'intermediate',
    title: 'C 036：用指针交换两个变量',
    standard: 'c17',
    concepts: <String>['指针参数', 'swap', '原地修改'],
    objective: '通过传指针让函数修改调用方的变量。',
    prerequisites: <String>['C 035'],
    summary: '经典 swap：解释为什么必须传指针。',
    explain:
        'C 参数按值传递，函数改参数不影响调用方。把变量地址传进去，函数就能通过 *p 修改原变量。swap 是理解这一点的最好例子：参数是 int *，交换的是 *a 和 *b。',
    code: '#include <stdio.h>\n'
        '\n'
        'void swap(int *a, int *b) {\n'
        '    int t = *a;\n'
        '    *a = *b;\n'
        '    *b = t;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    int x = 1, y = 2;\n'
        '    swap(&x, &y);\n'
        '    printf("x=%d y=%d\\n", x, y);\n'
        '    return 0;\n'
        '}\n',
    output: 'x=2 y=1\n',
    pitfalls: <String>[
      '调用时忘记取地址 swap(x, y) 会传入非法指针。',
      '在 swap 里直接交换指针形参本身不会影响调用方。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个函数同时把两个数加一。',
        hint: '参数是 int *，函数体里 (*a)++; (*b)++;。',
        answer: 'void incBoth(int *a, int *b) { (*a)++; (*b)++; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 37,
    language: 'c',
    level: 'intermediate',
    title: 'C 037：指针与数组的关系',
    standard: 'c17',
    concepts: <String>['数组名退化', '指针算术', '*(p+i)'],
    objective: '理解数组名可当指针用，以及等价的两种下标写法。',
    prerequisites: <String>['C 035'],
    summary: 'arr[i] 就是 *(arr + i)。',
    explain:
        '数组名在表达式里会退化成指向首元素的指针。arr[i] 完全等价于 *(arr + i)。指针加 1 不是加 1 个字节，而是加一个元素的大小。这解释了为什么指针和数组在函数参数里几乎可以互换。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int arr[4] = {10, 20, 30, 40};\n'
        '    int *p = arr;\n'
        '    printf("arr[2]=%d\\n", arr[2]);\n'
        '    printf("*(arr+2)=%d\\n", *(arr + 2));\n'
        '    printf("p[3]=%d\\n", p[3]);\n'
        '    printf("*(p+1)=%d\\n", *(p + 1));\n'
        '    return 0;\n'
        '}\n',
    output: 'arr[2]=30\n*(arr+2)=30\np[3]=40\n*(p+1)=20\n',
    pitfalls: <String>[
      '指针加法按元素大小移动，不是按字节。',
      '数组名是常量指针，不能写 arr++。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用指针遍历数组并打印所有元素。',
        hint: '用 for (int *q = arr; q < arr + 4; q++)。',
        answer: 'for (int *q = arr; q < arr + 4; q++) printf("%d ", *q);',
      ),
    ],
  ),
  ForgeTopic(
    id: 38,
    language: 'c',
    level: 'intermediate',
    title: 'C 038：指针遍历与指针算术',
    standard: 'c17',
    concepts: <String>['指针自增', '首尾指针', '减法求长度'],
    objective: '用指针移动遍历数组，用指针差求元素个数。',
    prerequisites: <String>['C 037'],
    summary: '移到末尾再相减，就是元素个数。',
    explain:
        '指针可以自增自减，指向下一个或上一个元素。两个指向同一数组的指针相减，得到它们之间的元素个数（类型是 ptrdiff_t）。用「起点指针」和「移动指针」相减是求长度的常用技巧。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int arr[5] = {3, 6, 9, 12, 15};\n'
        '    int *begin = arr;\n'
        '    int *end = arr + 5;\n'
        '    int sum = 0;\n'
        '    for (int *p = begin; p != end; p++) {\n'
        '        sum += *p;\n'
        '    }\n'
        '    printf("count=%ld\\n", (long)(end - begin));\n'
        '    printf("sum=%d\\n", sum);\n'
        '    return 0;\n'
        '}\n',
    output: 'count=5\nsum=45\n',
    pitfalls: <String>[
      '两个不同数组的指针相减是未定义行为。',
      'end 指向最后一个元素的下一个位置，不能解引用。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用指针求数组元素的最大值。',
        hint: '从第二个元素开始比较，更新 best。',
        answer: 'int best = *arr;\nfor (int *p = arr + 1; p < end; p++) if (*p > best) best = *p;',
      ),
    ],
  ),
  ForgeTopic(
    id: 39,
    language: 'c',
    level: 'intermediate',
    title: 'C 039：const 指针与指向 const 的指针',
    standard: 'c17',
    concepts: <String>['const int *', 'int * const', '只读'],
    objective: '分清「不能改指向」和「不能改内容」。',
    prerequisites: <String>['C 035'],
    summary: 'const 放在 * 的哪边决定限制谁。',
    explain:
        'const int *p 表示不能通过 p 修改它指向的值（但 p 可以指向别处）。int * const p 表示 p 本身不能改指向。函数参数用 const int * 表明只读，是良好的接口习惯。',
    code: '#include <stdio.h>\n'
        '\n'
        'int sum(const int *values, int n) {\n'
        '    int total = 0;\n'
        '    for (int i = 0; i < n; i++) total += values[i];\n'
        '    return total;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    int arr[3] = {5, 10, 15};\n'
        '    printf("sum=%d\\n", sum(arr, 3));\n'
        '    return 0;\n'
        '}\n',
    output: 'sum=30\n',
    pitfalls: <String>[
      '在只读参数里写 values[i] = 0 会编译错误，这是有意保护。',
      'const 的位置很重要：const int * 与 int * const 不同。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个只读函数找出数组中的最小值。',
        hint: '参数用 const int *，只读不改。',
        answer: 'int minOf(const int *v, int n) { int m = v[0]; for (int i = 1; i < n; i++) if (v[i] < m) m = v[i]; return m; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 40,
    language: 'c',
    level: 'intermediate',
    title: 'C 040：strlen / strcpy / strcmp 深入',
    standard: 'c17',
    concepts: <String>['strlen', 'strcpy', 'strcmp 返回语义', '自己实现'],
    objective: '理解标准字符串函数的实现细节与边界。',
    prerequisites: <String>['C 025'],
    summary: '动手实现一遍，才算真的懂。',
    explain:
        'strlen 数到 \\0 为止；strcmp 逐个字符比较，遇到第一个不同就返回两者之差，全相等才返回 0；strcpy 复制包括 \\0。自己实现一遍能看清它们都依赖 \\0，也提醒你目标缓冲区必须够大。',
    code: '#include <stdio.h>\n'
        '#include <string.h>\n'
        '\n'
        'size_t myStrlen(const char *s) {\n'
        '    size_t n = 0;\n'
        '    while (s[n] != \'\\0\') n++;\n'
        '    return n;\n'
        '}\n'
        '\n'
        'int myStrcmp(const char *a, const char *b) {\n'
        '    while (*a && *a == *b) { a++; b++; }\n'
        '    return (unsigned char)*a - (unsigned char)*b;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    printf("len=%zu\\n", myStrlen("hello"));\n'
        '    printf("cmp=%d\\n", myStrcmp("abc", "abd") < 0);\n'
        '    printf("eq=%d\\n", myStrcmp("same", "same") == 0);\n'
        '    return 0;\n'
        '}\n',
    output: 'len=5\ncmp=1\neq=1\n',
    pitfalls: <String>[
      'strcmp 返回的不是 -1/0/1，判断请用 < 0 / == 0。',
      '自己实现时用 unsigned char 比较，避免符号扩展影响顺序。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '实现 myStrcpy 并演示复制一个短字符串。',
        hint: '逐字符复制直到包含 \\0。',
        answer: 'char *myStrcpy(char *dst, const char *src) { char *d = dst; while ((*d++ = *src++)); return dst; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 41,
    language: 'c',
    level: 'intermediate',
    title: 'C 041：strtok 拆分子串',
    standard: 'c17',
    concepts: <String>['strtok', '分隔符', '原地切分'],
    objective: '用 strtok 按分隔符逐段解析字符串。',
    prerequisites: <String>['C 040'],
    summary: '把 "a,b,c" 拆成三段。',
    explain:
        'strtok 按给定分隔符把字符串切成若干段。第一次传入原字符串，之后传 NULL 继续取下一段。它会就地修改字符串（把分隔符替换成 \\0），所以不能传字符串字面量，要传可写的 char 数组。',
    code: '#include <stdio.h>\n'
        '#include <string.h>\n'
        '\n'
        'int main(void) {\n'
        '    char line[] = "apple,banana,,cherry";\n'
        '    int count = 0;\n'
        '    char *token = strtok(line, ",");\n'
        '    while (token != NULL) {\n'
        '        printf("[%s]\\n", token);\n'
        '        count++;\n'
        '        token = strtok(NULL, ",");\n'
        '    }\n'
        '    printf("count=%d\\n", count);\n'
        '    return 0;\n'
        '}\n',
    output: '[apple]\n[banana]\n[cherry]\ncount=3\n',
    pitfalls: <String>[
      'strtok 会跳过连续分隔符产生的空段。',
      '传入字符串字面量会因写入只读内存而崩溃。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 "12-34-56" 按 - 拆开并求三段之和。',
        hint: '在循环里用 atoi 转成整数累加。',
        answer: 'int sum = 0;\nfor (char *t = strtok(s, "-"); t; t = strtok(NULL, "-")) sum += atoi(t);',
      ),
    ],
  ),
  ForgeTopic(
    id: 42,
    language: 'c',
    level: 'intermediate',
    title: 'C 042：结构体基础',
    standard: 'c17',
    concepts: <String>['struct', '成员访问', '初始化'],
    objective: '用 struct 把相关字段打包成一个类型。',
    prerequisites: <String>['C 019'],
    summary: '把名字和坐标绑在一起。',
    explain:
        'struct 让你自定义组合类型。定义后是一个新类型，用点号 . 访问成员。初始化用花括号按字段顺序给值，也可以用「指定初始化器」.name = ... 按名字赋值，更不易出错。',
    code: '#include <stdio.h>\n'
        '\n'
        'struct Point {\n'
        '    int x;\n'
        '    int y;\n'
        '};\n'
        '\n'
        'int main(void) {\n'
        '    struct Point a = {3, 4};\n'
        '    struct Point b = {.x = -1, .y = 7};\n'
        '    printf("a=(%d,%d)\\n", a.x, a.y);\n'
        '    printf("b=(%d,%d)\\n", b.x, b.y);\n'
        '    a.x += 10;\n'
        '    printf("a.x=%d\\n", a.x);\n'
        '    return 0;\n'
        '}\n',
    output: 'a=(3,4)\nb=(-1,7)\na.x=13\n',
    pitfalls: <String>[
      'struct 定义末尾的分号不能漏。',
      '指定初始化器按名字赋值，顺序可以打乱。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 Point 加一个计算到原点距离平方的函数。',
        hint: '返回 p.x*p.x + p.y*p.y。',
        answer: 'int lenSq(struct Point p) { return p.x * p.x + p.y * p.y; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 43,
    language: 'c',
    level: 'intermediate',
    title: 'C 043：结构体数组与遍历',
    standard: 'c17',
    concepts: <String>['struct 数组', '遍历', '聚合统计'],
    objective: '用结构体数组存一张表并做统计。',
    prerequisites: <String>['C 042'],
    summary: '结构体数组就是一张记录表。',
    explain:
        '结构体数组把多条记录连续存放，用下标访问第 i 条记录的成员：list[i].score。遍历可以做求和、求极值、查找等任何聚合操作。结构体数组是 C 里表达「表格」的常用方式。',
    code: '#include <stdio.h>\n'
        '\n'
        'struct Student {\n'
        '    char name[16];\n'
        '    int score;\n'
        '};\n'
        '\n'
        'int main(void) {\n'
        '    struct Student list[3] = {\n'
        '        {"小明", 88},\n'
        '        {"小红", 95},\n'
        '        {"小刚", 72},\n'
        '    };\n'
        '    int sum = 0, best = 0;\n'
        '    for (int i = 0; i < 3; i++) {\n'
        '        sum += list[i].score;\n'
        '        if (list[i].score > list[best].score) best = i;\n'
        '        printf("%s: %d\\n", list[i].name, list[i].score);\n'
        '    }\n'
        '    printf("avg=%.1f best=%s\\n", sum / 3.0, list[best].name);\n'
        '    return 0;\n'
        '}\n',
    output: '小明: 88\n小红: 95\n小刚: 72\navg=85.0 best=小红\n',
    pitfalls: <String>[
      'name 字段是定长数组，存不下过长名字会截断。',
      '比较用 > 还是 >= 决定并列时取哪一个。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '统计分数及格（>= 60）的人数。',
        hint: '遍历时用 if (list[i].score >= 60) count++;。',
        answer: 'int pass = 0;\nfor (int i = 0; i < 3; i++) if (list[i].score >= 60) pass++;',
      ),
    ],
  ),
  ForgeTopic(
    id: 44,
    language: 'c',
    level: 'intermediate',
    title: 'C 044：结构体指针与 -> 运算符',
    standard: 'c17',
    concepts: <String>['结构体指针', '->', '(*p).x'],
    objective: '通过指针访问结构体成员，理解 -> 的由来。',
    prerequisites: <String>['C 043'],
    summary: 'p->x 就是 (*p).x 的简写。',
    explain:
        '当 p 是指向结构体的指针时，(*p).x 写法繁琐且易错，于是有了 ->：p->x 等价于 (*p).x。传结构体给函数时通常传指针，避免整个结构体被复制，也能在函数里修改原结构体。',
    code: '#include <stdio.h>\n'
        '\n'
        'struct Counter {\n'
        '    int value;\n'
        '    int step;\n'
        '};\n'
        '\n'
        'void advance(struct Counter *c) {\n'
        '    c->value += c->step;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    struct Counter c = {0, 5};\n'
        '    advance(&c);\n'
        '    advance(&c);\n'
        '    printf("value=%d\\n", c.value);\n'
        '    printf("via arrow=%d\\n", (&c)->value);\n'
        '    return 0;\n'
        '}\n',
    output: 'value=10\nvia arrow=10\n',
    pitfalls: <String>[
      '对非指针用 -> 是语法错误，对指针用 . 也是。',
      '传指针给函数要取地址 advance(&c)。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个函数把 Counter 清零。',
        hint: '参数是 struct Counter *，把 value 设 0。',
        answer: 'void reset(struct Counter *c) { c->value = 0; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 45,
    language: 'c',
    level: 'intermediate',
    title: 'C 045：typedef 简化类型名',
    standard: 'c17',
    concepts: <String>['typedef', '类型别名', '可读性'],
    objective: '用 typedef 给类型起短名，提升可读性。',
    prerequisites: <String>['C 042'],
    summary: 'typedef struct {...} Name; 的常见写法。',
    explain:
        'typedef 给已有类型起别名。最常用的形式是 typedef struct { ... } Point;，这样就不必每次都写 struct Point。typedef 只是别名，不产生新类型，也不影响运行时。',
    code: '#include <stdio.h>\n'
        '\n'
        'typedef struct {\n'
        '    double real;\n'
        '    double imag;\n'
        '} Complex;\n'
        '\n'
        'Complex add(Complex a, Complex b) {\n'
        '    Complex r = {a.real + b.real, a.imag + b.imag};\n'
        '    return r;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    Complex a = {1.0, 2.0};\n'
        '    Complex b = {3.0, 4.0};\n'
        '    Complex c = add(a, b);\n'
        '    printf("sum=%.1f+%.1fi\\n", c.real, c.imag);\n'
        '    return 0;\n'
        '}\n',
    output: 'sum=4.0+6.0i\n',
    pitfalls: <String>[
      'typedef 不创建新类型，别名与原类型完全互通。',
      'typedef 与 #define 不同，它受作用域和类型系统约束。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 typedef 给 unsigned long 起名 Size，并声明一个变量。',
        hint: 'typedef unsigned long Size;。',
        answer: 'typedef unsigned long Size;\nSize n = 42;',
      ),
    ],
  ),
  ForgeTopic(
    id: 46,
    language: 'c',
    level: 'intermediate',
    title: 'C 046：enum 枚举',
    standard: 'c17',
    concepts: <String>['enum', '命名常量', '状态机'],
    objective: '用 enum 给一组相关整数起名字。',
    prerequisites: <String>['C 045'],
    summary: '让状态和选项自解释。',
    explain:
        'enum 定义一组命名的整数常量，默认从 0 开始递增。它让 switch 语句和状态表达更清晰：不用记 0 代表什么，直接写 Red。枚举值本质是 int，可以参与比较和运算，但可读性更好。',
    code: '#include <stdio.h>\n'
        '\n'
        'typedef enum { RED, GREEN, YELLOW } Light;\n'
        '\n'
        'const char *nameOf(Light l) {\n'
        '    switch (l) {\n'
        '        case RED: return "red";\n'
        '        case GREEN: return "green";\n'
        '        case YELLOW: return "yellow";\n'
        '    }\n'
        '    return "unknown";\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    Light current = GREEN;\n'
        '    printf("current=%s\\n", nameOf(current));\n'
        '    printf("red value=%d\\n", RED);\n'
        '    return 0;\n'
        '}\n',
    output: 'current=green\nred value=0\n',
    pitfalls: <String>[
      'enum 值本质是整数，不能直接用 %s 打印，要靠映射函数。',
      '在 switch 里漏 case 不报错，必要时加 default。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 Light 增加一个 PURPLE 值并返回其名字。',
        hint: '在枚举和 switch 里各加一项。',
        answer: 'typedef enum { RED, GREEN, YELLOW, PURPLE } Light;\n// switch 里加 case PURPLE: return "purple";',
      ),
    ],
  ),
  ForgeTopic(
    id: 47,
    language: 'c',
    level: 'intermediate',
    title: 'C 047：union 联合体',
    standard: 'c17',
    concepts: <String>['union', '共享内存', '类型双关'],
    objective: '理解 union 的成员共享同一块内存。',
    prerequisites: <String>['C 042'],
    summary: '同一块内存的多种解释。',
    explain:
        'union 的所有成员共用同一块内存，大小等于最大成员。写入一个成员会覆盖其他成员。它常用于节省内存（同一时刻只用一个字段）或查看同一段字节的不同表示。读取「最后写入之外」的成员是易错点。',
    code: '#include <stdio.h>\n'
        '\n'
        'union Value {\n'
        '    int i;\n'
        '    float f;\n'
        '    unsigned char bytes[4];\n'
        '};\n'
        '\n'
        'int main(void) {\n'
        '    union Value v;\n'
        '    v.i = 0x01020304;\n'
        '    printf("i=%d\\n", v.i);\n'
        '    printf("bytes=%02x %02x %02x %02x\\n",\n'
        '           v.bytes[0], v.bytes[1], v.bytes[2], v.bytes[3]);\n'
        '    printf("size=%zu\\n", sizeof(union Value));\n'
        '    return 0;\n'
        '}\n',
    output: 'i=16909060\nbytes=04 03 02 01\nsize=4\n',
    pitfalls: <String>[
      '字节顺序依赖机器（小端/大端），结果不可跨平台假设。',
      '写入一个成员后读取另一个成员的值是实现定义行为。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 union 判断本机是小端还是大端。',
        hint: '写 v.i = 1，看 v.bytes[0] 是否为 1。',
        answer: 'v.i = 1;\nprintf(v.bytes[0] == 1 ? "little" : "big");',
      ),
    ],
  ),
  ForgeTopic(
    id: 48,
    language: 'c',
    level: 'intermediate',
    title: 'C 048：位运算与位掩码',
    standard: 'c17',
    concepts: <String>['& | ^ ~', '<< >>', '置位', '掩码'],
    objective: '用位运算操作二进制位。',
    prerequisites: <String>['C 004'],
    summary: '置位、清位、取位、翻转位。',
    explain:
        '位运算直接操作二进制位：x | (1<<n) 置位，x & ~(1<<n) 清位，(x>>n)&1 取第 n 位，x ^ (1<<n) 翻转。它广泛用于标志位、协议解析和性能敏感代码。注意 << 对负数左移是未定义行为。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    unsigned flags = 0;\n'
        '    flags |= (1u << 2);\n'
        '    flags |= (1u << 5);\n'
        '    printf("set bit2=%u bit5=%u\\n", (flags >> 2) & 1u, (flags >> 5) & 1u);\n'
        '    flags &= ~(1u << 2);\n'
        '    printf("cleared bit2=%u\\n", (flags >> 2) & 1u);\n'
        '    printf("flags=%u\\n", flags);\n'
        '    return 0;\n'
        '}\n',
    output: 'set bit2=1 bit5=1\ncleared bit2=0\nflags=32\n',
    pitfalls: <String>[
      '1<<n 用 int，n 较大时要写成 1u<<n 避免符号问题。',
      '用 & 判断标志位时结果可能是 2、4 等，判断非零即可。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '统计一个无符号整数里二进制 1 的个数。',
        hint: '循环 x &= x - 1; 每轮消除最低位的 1。',
        answer: 'int count = 0;\nwhile (x) { x &= x - 1; count++; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 49,
    language: 'c',
    level: 'intermediate',
    title: 'C 049：按位实现标志集合',
    standard: 'c17',
    concepts: <String>['位标志', 'enum 掩码', '权限'],
    objective: '把多个开关位打包进一个整数。',
    prerequisites: <String>['C 048'],
    summary: '用一个整数表示一组开关。',
    explain:
        '把每个权限/开关定义成 2 的幂（1、2、4、8...），用一个整数保存它们的组合。判断用 (set & flag) != 0，添加用 |=，移除用 &= ~flag。这比用多个 bool 更省空间，也能一次传递多个开关。',
    code: '#include <stdio.h>\n'
        '\n'
        'enum Perm {\n'
        '    PERM_READ = 1 << 0,\n'
        '    PERM_WRITE = 1 << 1,\n'
        '    PERM_EXEC = 1 << 2,\n'
        '};\n'
        '\n'
        'int has(int set, int flag) { return (set & flag) != 0; }\n'
        '\n'
        'int main(void) {\n'
        '    int perms = PERM_READ | PERM_EXEC;\n'
        '    printf("read=%d write=%d exec=%d\\n",\n'
        '           has(perms, PERM_READ), has(perms, PERM_WRITE), has(perms, PERM_EXEC));\n'
        '    perms |= PERM_WRITE;\n'
        '    printf("after add write=%d\\n", has(perms, PERM_WRITE));\n'
        '    perms &= ~PERM_READ;\n'
        '    printf("after remove read=%d\\n", has(perms, PERM_READ));\n'
        '    return 0;\n'
        '}\n',
    output: 'read=1 write=0 exec=1\nafter add write=1\nafter remove read=0\n',
    pitfalls: <String>[
      '标志值必须是 2 的幂，不能重复。',
      '用 == 判断组合标志会出错，要用 (set & flag) != 0。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '打印 perms 里还剩下哪些权限。',
        hint: '逐个用 has 判断并打印名字。',
        answer: 'if (has(perms, PERM_READ)) printf("read ");\nif (has(perms, PERM_WRITE)) printf("write ");\nif (has(perms, PERM_EXEC)) printf("exec ");',
      ),
    ],
  ),
  ForgeTopic(
    id: 50,
    language: 'c',
    level: 'intermediate',
    title: 'C 050：函数指针',
    standard: 'c17',
    concepts: <String>['函数指针', '回调', '返回类型 (*)(参数)'],
    objective: '声明函数指针并通过它调用函数。',
    prerequisites: <String>['C 035'],
    summary: '把函数当参数传递。',
    explain:
        '函数指针存放函数的地址，类型写法是 返回类型 (*名字)(参数类型)。赋值时写函数名即可。通过函数指针调用可以像普通函数一样。它是 C 实现回调、策略选择的基础。',
    code: '#include <stdio.h>\n'
        '\n'
        'int add(int a, int b) { return a + b; }\n'
        'int mul(int a, int b) { return a * b; }\n'
        '\n'
        'int main(void) {\n'
        '    int (*op)(int, int) = add;\n'
        '    printf("add=%d\\n", op(3, 4));\n'
        '    op = mul;\n'
        '    printf("mul=%d\\n", op(3, 4));\n'
        '    return 0;\n'
        '}\n',
    output: 'add=7\nmul=12\n',
    pitfalls: <String>[
      '写成 int *op(int,int) 是「返回指针的函数」，不是函数指针。',
      '函数指针签名必须与目标函数完全一致。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '声明一个函数指针指向一个求最大值的函数。',
        hint: '签名 int (int, int)。',
        answer: 'int maxOf(int a, int b) { return a > b ? a : b; }\nint (*op)(int, int) = maxOf;',
      ),
    ],
  ),
  ForgeTopic(
    id: 51,
    language: 'c',
    level: 'intermediate',
    title: 'C 051：回调函数',
    standard: 'c17',
    concepts: <String>['回调', '高阶函数', '遍历'],
    objective: '把函数作为参数传给另一个函数。',
    prerequisites: <String>['C 050'],
    summary: '让调用方决定「对每个元素做什么」。',
    explain:
        '回调就是「把函数当参数传进去，由被调用者在合适时机调用它」。例如遍历数组并对每个元素应用一个操作，操作本身由调用方提供。这样同一个遍历框架能支持求和、打印、统计等不同行为。',
    code: '#include <stdio.h>\n'
        '\n'
        'void forEach(int *arr, int n, void (*visit)(int)) {\n'
        '    for (int i = 0; i < n; i++) visit(arr[i]);\n'
        '}\n'
        '\n'
        'void printIt(int x) { printf("%d ", x); }\n'
        'void squareIt(int x) { printf("%d ", x * x); }\n'
        '\n'
        'int main(void) {\n'
        '    int arr[4] = {1, 2, 3, 4};\n'
        '    forEach(arr, 4, printIt);\n'
        '    printf("\\n");\n'
        '    forEach(arr, 4, squareIt);\n'
        '    printf("\\n");\n'
        '    return 0;\n'
        '}\n',
    output: '1 2 3 4 \n1 4 9 16 \n',
    pitfalls: <String>[
      '回调的签名必须与参数类型匹配。',
      '回调里用到的外部状态要在调用前准备好。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个回调把每个元素打印成 [x] 形式。',
        hint: '回调签名 void (int)，打印 [ 值 ]。',
        answer: 'void bracket(int x) { printf("[%d]", x); }\nforEach(arr, 4, bracket);',
      ),
    ],
  ),
  ForgeTopic(
    id: 52,
    language: 'c',
    level: 'intermediate',
    title: 'C 052：malloc 与 free',
    standard: 'c17',
    concepts: <String>['malloc', 'free', '堆内存', '泄漏'],
    objective: '在堆上分配和释放内存。',
    prerequisites: <String>['C 036'],
    summary: '运行时才确定大小的内存。',
    explain:
        'malloc 在堆上分配指定字节数，返回 void *，失败返回 NULL。用完后必须 free 释放，否则内存泄漏。malloc 不会清零内存，需要清零可用 calloc。分配和释放要一一对应。',
    code: '#include <stdio.h>\n'
        '#include <stdlib.h>\n'
        '\n'
        'int main(void) {\n'
        '    int n = 5;\n'
        '    int *arr = (int *)malloc((size_t)n * sizeof(int));\n'
        '    if (arr == NULL) {\n'
        '        printf("alloc failed\\n");\n'
        '        return 1;\n'
        '    }\n'
        '    for (int i = 0; i < n; i++) arr[i] = i * i;\n'
        '    for (int i = 0; i < n; i++) printf("%d ", arr[i]);\n'
        '    printf("\\n");\n'
        '    free(arr);\n'
        '    return 0;\n'
        '}\n',
    output: '0 1 4 9 16 \n',
    pitfalls: <String>[
      '忘记检查 malloc 返回 NULL 会崩溃。',
      'free 后继续用该指针是悬空指针，行为未定义。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '分配一个能存 10 个 double 的数组并全部置 0。',
        hint: 'malloc 后逐个赋值，或用 calloc(10, sizeof(double))。',
        answer: 'double *v = (double *)calloc(10, sizeof(double));\n// 用完后 free(v);',
      ),
    ],
  ),
  ForgeTopic(
    id: 53,
    language: 'c',
    level: 'intermediate',
    title: 'C 053：calloc 与 realloc',
    standard: 'c17',
    concepts: <String>['calloc', 'realloc', '扩容', '临时指针'],
    objective: '用 calloc 分配清零内存，用 realloc 扩容。',
    prerequisites: <String>['C 052'],
    summary: '动态数组的扩容套路。',
    explain:
        'calloc(n, size) 分配并清零。realloc(ptr, newSize) 调整已分配内存大小，可能搬到新地址并返回新指针；失败返回 NULL 且原内存仍有效。所以要先存到临时指针，成功后再赋回。',
    code: '#include <stdio.h>\n'
        '#include <stdlib.h>\n'
        '\n'
        'int main(void) {\n'
        '    int *a = (int *)calloc(3, sizeof(int));\n'
        '    for (int i = 0; i < 3; i++) printf("%d ", a[i]);\n'
        '    printf("\\n");\n'
        '    int *tmp = (int *)realloc(a, 5 * sizeof(int));\n'
        '    if (tmp == NULL) {\n'
        '        free(a);\n'
        '        return 1;\n'
        '    }\n'
        '    a = tmp;\n'
        '    a[3] = 100;\n'
        '    a[4] = 200;\n'
        '    for (int i = 0; i < 5; i++) printf("%d ", a[i]);\n'
        '    printf("\\n");\n'
        '    free(a);\n'
        '    return 0;\n'
        '}\n',
    output: '0 0 0 \n0 0 0 100 200 \n',
    pitfalls: <String>[
      '把 realloc 的返回值直接赋给原指针，失败时会泄漏原内存。',
      'realloc 后旧指针可能失效，必须使用返回的新指针。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 realloc 把长度为 3 的数组扩到 8，并在新位置写值。',
        hint: '先存临时指针再赋回。',
        answer: 'int *t = realloc(a, 8 * sizeof(int));\nif (t) a = t;',
      ),
    ],
  ),
  ForgeTopic(
    id: 54,
    language: 'c',
    level: 'intermediate',
    title: 'C 054：动态数组的增删',
    standard: 'c17',
    concepts: <String>['动态数组', 'size/capacity', '追加'],
    objective: '用 size 与 capacity 管理一个可增长数组。',
    prerequisites: <String>['C 053'],
    summary: '当 size 追平 capacity 就翻倍扩容。',
    explain:
        '可增长数组记录两个量：size（已有元素数）和 capacity（已分配容量）。追加时若 size == capacity 就先扩容（常见做法是容量翻倍），再写入。这种「翻倍扩容」使追加的平均代价接近常数。',
    code: '#include <stdio.h>\n'
        '#include <stdlib.h>\n'
        '\n'
        'int main(void) {\n'
        '    int capacity = 2, size = 0;\n'
        '    int *a = (int *)malloc((size_t)capacity * sizeof(int));\n'
        '    for (int v = 10; v <= 60; v += 10) {\n'
        '        if (size == capacity) {\n'
        '            capacity *= 2;\n'
        '            a = (int *)realloc(a, (size_t)capacity * sizeof(int));\n'
        '        }\n'
        '        a[size++] = v;\n'
        '    }\n'
        '    printf("size=%d capacity=%d\\n", size, capacity);\n'
        '    for (int i = 0; i < size; i++) printf("%d ", a[i]);\n'
        '    printf("\\n");\n'
        '    free(a);\n'
        '    return 0;\n'
        '}\n',
    output: 'size=6 capacity=8\n10 20 30 40 50 60 \n',
    pitfalls: <String>[
      '扩容后要使用 realloc 返回的新指针。',
      'capacity 是容量不是长度，别用它遍历元素。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '在追加前检查 size==capacity 并打印每次扩容。',
        hint: '扩容分支里打印 old capacity -> new。',
        answer: 'if (size == capacity) { printf("grow %d->%d\\n", capacity, capacity * 2); capacity *= 2; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 55,
    language: 'c',
    level: 'intermediate',
    title: 'C 055：内存安全——越界、泄漏、悬空',
    standard: 'c17',
    concepts: <String>['越界', '泄漏', '悬空指针', '双重释放'],
    objective: '识别并避免四类常见内存错误。',
    prerequisites: <String>['C 052'],
    summary: 'C 不替你检查内存，规则要自己守。',
    explain:
        '四类典型错误：越界（写到数组外）、泄漏（malloc 后忘记 free）、悬空指针（free 后继续用）、双重释放（对同一块 free 两次）。规矩是：谁分配谁释放，释放后把指针置 NULL，边界用长度变量守。',
    code: '#include <stdio.h>\n'
        '#include <stdlib.h>\n'
        '\n'
        'int main(void) {\n'
        '    int n = 3;\n'
        '    int *a = (int *)malloc((size_t)n * sizeof(int));\n'
        '    for (int i = 0; i < n; i++) a[i] = i + 1;\n'
        '    printf("sum=%d\\n", a[0] + a[1] + a[2]);\n'
        '    free(a);\n'
        '    a = NULL;\n'
        '    printf("freed and nulled=%d\\n", a == NULL);\n'
        '    return 0;\n'
        '}\n',
    output: 'sum=6\nfreed and nulled=1\n',
    pitfalls: <String>[
      'free 后不置 NULL，之后误用仍会编译通过但运行出错。',
      '在循环里反复 malloc 却不 free 是最隐蔽的泄漏。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '说明为什么 free 之后要把指针置为 NULL。',
        hint: '防止重复释放和悬空访问。',
        answer: '置 NULL 后误用会立刻以空指针暴露，重复 free(NULL) 也被定义为安全。',
      ),
    ],
  ),
  ForgeTopic(
    id: 56,
    language: 'c',
    level: 'intermediate',
    title: 'C 056：二维数组',
    standard: 'c17',
    concepts: <String>['二维数组', '行列遍历', '内存布局'],
    objective: '声明并遍历二维数组，理解行优先存储。',
    prerequisites: <String>['C 043'],
    summary: '矩阵就是数组的数组。',
    explain:
        'int m[2][3] 是 2 行 3 列的矩阵，m[i][j] 访问第 i 行第 j 列。它在内存里是行优先连续存放的。遍历时用两层循环，外层行、内层列。把二维数组传给函数时，列数必须写进参数类型。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int m[2][3] = {{1, 2, 3}, {4, 5, 6}};\n'
        '    int sum = 0;\n'
        '    for (int i = 0; i < 2; i++) {\n'
        '        for (int j = 0; j < 3; j++) {\n'
        '            printf("%d ", m[i][j]);\n'
        '            sum += m[i][j];\n'
        '        }\n'
        '        printf("\\n");\n'
        '    }\n'
        '    printf("sum=%d\\n", sum);\n'
        '    return 0;\n'
        '}\n',
    output: '1 2 3 \n4 5 6 \nsum=21\n',
    pitfalls: <String>[
      'm[2][3] 是「2 行 3 列」，索引顺序别反。',
      '传二维数组给函数时第二维长度是类型的一部分，不能省。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '求出矩阵每行的和并打印。',
        hint: '每行内层循环累加一个 rowSum。',
        answer: 'for (int i = 0; i < 2; i++) { int rowSum = 0; for (int j = 0; j < 3; j++) rowSum += m[i][j]; printf("row%d=%d\\n", i, rowSum); }',
      ),
    ],
  ),
  ForgeTopic(
    id: 57,
    language: 'c',
    level: 'intermediate',
    title: 'C 057：递归——阶乘与斐波那契',
    standard: 'c17',
    concepts: <String>['递归', '基准情形', '调用栈'],
    objective: '用递归解决可分拆的问题。',
    prerequisites: <String>['C 052'],
    summary: '函数调用自己，直到触及基准情形。',
    explain:
        '递归函数必须有一个「基准情形」直接返回，否则会无限递归导致栈溢出。阶乘 n! = n * (n-1)!，基准是 0! = 1。斐波那契的朴素递归会重复计算大量子问题，只适合演示。',
    code: '#include <stdio.h>\n'
        '\n'
        'long factorial(int n) {\n'
        '    if (n <= 1) return 1;\n'
        '    return n * factorial(n - 1);\n'
        '}\n'
        '\n'
        'int fib(int n) {\n'
        '    if (n < 2) return n;\n'
        '    return fib(n - 1) + fib(n - 2);\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    printf("5! = %ld\\n", factorial(5));\n'
        '    printf("fib(10) = %d\\n", fib(10));\n'
        '    return 0;\n'
        '}\n',
    output: '5! = 120\nfib(10) = 55\n',
    pitfalls: <String>[
      '忘了基准情形会栈溢出。',
      '朴素 fib 是指数级复杂度，n 稍大就极慢。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用递归求 1 到 n 的和。',
        hint: '基准 n<=0 返回 0，否则 n + sum(n-1)。',
        answer: 'int sumTo(int n) { return n <= 0 ? 0 : n + sumTo(n - 1); }',
      ),
    ],
  ),
  ForgeTopic(
    id: 58,
    language: 'c',
    level: 'intermediate',
    title: 'C 058：递归与迭代的取舍',
    standard: 'c17',
    concepts: <String>['尾递归', '迭代', '栈深度'],
    objective: '理解递归与迭代的等价与代价。',
    prerequisites: <String>['C 057'],
    summary: '能用迭代就别用深递归。',
    explain:
        '任何递归都能改写成迭代。递归逻辑清晰但有栈深度限制和函数调用开销；迭代更快、内存更省。像「遍历目录」「解析嵌套结构」这类问题递归更自然，而简单累加用迭代更稳。',
    code: '#include <stdio.h>\n'
        '\n'
        'long factIter(int n) {\n'
        '    long r = 1;\n'
        '    for (int i = 2; i <= n; i++) r *= i;\n'
        '    return r;\n'
        '}\n'
        '\n'
        'int gcdIter(int a, int b) {\n'
        '    while (b != 0) {\n'
        '        int t = a % b;\n'
        '        a = b;\n'
        '        b = t;\n'
        '    }\n'
        '    return a;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    printf("10! = %ld\\n", factIter(10));\n'
        '    printf("gcd(48,36) = %d\\n", gcdIter(48, 36));\n'
        '    return 0;\n'
        '}\n',
    output: '10! = 3628800\ngcd(48,36) = 12\n',
    pitfalls: <String>[
      '阶乘结果很快超出 int 范围，要用 long。',
      '深递归（几十万层）会耗尽栈，应改迭代。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用迭代实现从 n 倒着打印到 1。',
        hint: 'for (int i = n; i >= 1; i--)。',
        answer: 'for (int i = n; i >= 1; i--) printf("%d ", i);',
      ),
    ],
  ),
  ForgeTopic(
    id: 59,
    language: 'c',
    level: 'intermediate',
    title: 'C 059：冒泡排序',
    standard: 'c17',
    concepts: <String>['排序', '冒泡', '交换', '提前退出'],
    objective: '实现冒泡排序并理解它的复杂度。',
    prerequisites: <String>['C 038'],
    summary: '相邻比较，大的往后浮。',
    explain:
        '冒泡排序重复走访数组，比较相邻两元素，逆序就交换。每一轮把当前最大的「冒」到末尾。如果某一轮没有发生交换，说明已经有序，可以提前结束。平均和最坏是 O(n^2)。',
    code: '#include <stdio.h>\n'
        '\n'
        'void bubble(int *a, int n) {\n'
        '    for (int i = 0; i < n - 1; i++) {\n'
        '        int swapped = 0;\n'
        '        for (int j = 0; j < n - 1 - i; j++) {\n'
        '            if (a[j] > a[j + 1]) {\n'
        '                int t = a[j]; a[j] = a[j + 1]; a[j + 1] = t;\n'
        '                swapped = 1;\n'
        '            }\n'
        '        }\n'
        '        if (!swapped) break;\n'
        '    }\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    int a[6] = {5, 2, 9, 1, 5, 6};\n'
        '    bubble(a, 6);\n'
        '    for (int i = 0; i < 6; i++) printf("%d ", a[i]);\n'
        '    printf("\\n");\n'
        '    return 0;\n'
        '}\n',
    output: '1 2 5 5 6 9 \n',
    pitfalls: <String>[
      '内层循环上界是 n-1-i，已排好的尾部不用再看。',
      '相等元素不交换，才保证稳定排序。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '改成降序排序。',
        hint: '把内层比较的 > 改成 <。',
        answer: 'if (a[j] < a[j + 1]) { int t = a[j]; a[j] = a[j + 1]; a[j + 1] = t; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 60,
    language: 'c',
    level: 'intermediate',
    title: 'C 060：选择排序与插入排序',
    standard: 'c17',
    concepts: <String>['选择排序', '插入排序', '稳定性'],
    objective: '实现两种 O(n^2) 排序并比较适用场景。',
    prerequisites: <String>['C 059'],
    summary: '选择排序每轮选最小，插入排序像理牌。',
    explain:
        '选择排序每轮从未排序区间挑出最小元素放到前面，交换次数少。插入排序把新元素插入到已排好序的前缀里，像整理扑克牌；对近乎有序的数据非常快，而且是稳定的。两者都是 O(n^2)。',
    code: '#include <stdio.h>\n'
        '\n'
        'void selection(int *a, int n) {\n'
        '    for (int i = 0; i < n - 1; i++) {\n'
        '        int min = i;\n'
        '        for (int j = i + 1; j < n; j++) if (a[j] < a[min]) min = j;\n'
        '        int t = a[i]; a[i] = a[min]; a[min] = t;\n'
        '    }\n'
        '}\n'
        '\n'
        'void insertion(int *a, int n) {\n'
        '    for (int i = 1; i < n; i++) {\n'
        '        int key = a[i], j = i - 1;\n'
        '        while (j >= 0 && a[j] > key) { a[j + 1] = a[j]; j--; }\n'
        '        a[j + 1] = key;\n'
        '    }\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    int a[6] = {4, 7, 2, 9, 1, 5};\n'
        '    selection(a, 6);\n'
        '    for (int i = 0; i < 6; i++) printf("%d ", a[i]);\n'
        '    printf("\\n");\n'
        '    int b[6] = {4, 7, 2, 9, 1, 5};\n'
        '    insertion(b, 6);\n'
        '    for (int i = 0; i < 6; i++) printf("%d ", b[i]);\n'
        '    printf("\\n");\n'
        '    return 0;\n'
        '}\n',
    output: '1 2 4 5 7 9 \n1 2 4 5 7 9 \n',
    pitfalls: <String>[
      '选择排序不稳定，相同值的相对顺序可能改变。',
      '插入排序内层用 > 才稳定，用 >= 会破坏稳定性。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '说明插入排序为什么对近乎有序的数据很快。',
        hint: '看 while 循环进入的次数。',
        answer: '近乎有序时内层 while 很少进入，移动次数接近 0，整体接近 O(n)。',
      ),
    ],
  ),
  ForgeTopic(
    id: 61,
    language: 'c',
    level: 'intermediate',
    title: 'C 061：归并排序',
    standard: 'c17',
    concepts: <String>['分治', '归并', 'O(n log n)', '额外空间'],
    objective: '用分治实现稳定 O(n log n) 排序。',
    prerequisites: <String>['C 057'],
    summary: '分成两半排好再合并。',
    explain:
        '归并排序把数组一分为二，分别排好序，再合并两个有序数组。合并时从两边取较小者，保证稳定。时间复杂度 O(n log n)，代价是需要 O(n) 的额外空间。递归下降的基准是区间只剩一个元素。',
    code: '#include <stdio.h>\n'
        '#include <stdlib.h>\n'
        '\n'
        'void merge(int *a, int *tmp, int lo, int mid, int hi) {\n'
        '    int i = lo, j = mid + 1, k = lo;\n'
        '    while (i <= mid && j <= hi) tmp[k++] = (a[i] <= a[j]) ? a[i++] : a[j++];\n'
        '    while (i <= mid) tmp[k++] = a[i++];\n'
        '    while (j <= hi) tmp[k++] = a[j++];\n'
        '    for (int t = lo; t <= hi; t++) a[t] = tmp[t];\n'
        '}\n'
        '\n'
        'void msort(int *a, int *tmp, int lo, int hi) {\n'
        '    if (lo >= hi) return;\n'
        '    int mid = lo + (hi - lo) / 2;\n'
        '    msort(a, tmp, lo, mid);\n'
        '    msort(a, tmp, mid + 1, hi);\n'
        '    merge(a, tmp, lo, mid, hi);\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    int a[7] = {38, 27, 43, 3, 9, 82, 10};\n'
        '    int *tmp = (int *)malloc(7 * sizeof(int));\n'
        '    msort(a, tmp, 0, 6);\n'
        '    for (int i = 0; i < 7; i++) printf("%d ", a[i]);\n'
        '    printf("\\n");\n'
        '    free(tmp);\n'
        '    return 0;\n'
        '}\n',
    output: '3 9 10 27 38 43 82 \n',
    pitfalls: <String>[
      'merge 里用 a[i] <= a[j] 才稳定。',
      '中间下标用 lo + (hi - lo) / 2 避免大数相加溢出。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '说明归并排序比冒泡排序快在哪里。',
        hint: '比较两者复杂度。',
        answer: '归并是 O(n log n)，冒泡是 O(n^2)；数据越大差距越明显，代价是额外 O(n) 空间。',
      ),
    ],
  ),
  ForgeTopic(
    id: 62,
    language: 'c',
    level: 'intermediate',
    title: 'C 062：快速排序与 qsort',
    standard: 'c17',
    concepts: <String>['快排', '分区', 'qsort', '比较函数'],
    objective: '理解快排分区，并会用标准 qsort。',
    prerequisites: <String>['C 061'],
    summary: '选基准分区，再递归两边。',
    explain:
        '快速排序选一个基准，把比它小的放到左边、大的放到右边，再对两边递归。平均 O(n log n)，原地排序。标准库的 qsort 就是通用快排，需要你提供一个比较函数：返回负数、0 或正数表示 a 小于、等于、大于 b。',
    code: '#include <stdio.h>\n'
        '#include <stdlib.h>\n'
        '\n'
        'int cmpAsc(const void *a, const void *b) {\n'
        '    int x = *(const int *)a;\n'
        '    int y = *(const int *)b;\n'
        '    return (x > y) - (x < y);\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    int a[6] = {42, 8, 17, 4, 23, 15};\n'
        '    qsort(a, 6, sizeof(int), cmpAsc);\n'
        '    for (int i = 0; i < 6; i++) printf("%d ", a[i]);\n'
        '    printf("\\n");\n'
        '    return 0;\n'
        '}\n',
    output: '4 8 15 17 23 42 \n',
    pitfalls: <String>[
      '比较函数必须返回 int，不能直接 return a - b（可能溢出）。',
      '(x > y) - (x < y) 是写出三态比较的简洁技巧。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个降序比较函数并用 qsort 排序。',
        hint: '把两个减法交换方向即可。',
        answer: 'int cmpDesc(const void *a, const void *b) { int x = *(const int*)a, y = *(const int*)b; return (y > x) - (y < x); }',
      ),
    ],
  ),
  ForgeTopic(
    id: 63,
    language: 'c',
    level: 'intermediate',
    title: 'C 063：二分查找',
    standard: 'c17',
    concepts: <String>['二分查找', '有序前提', '边界'],
    objective: '在有序数组里用 O(log n) 查找目标。',
    prerequisites: <String>['C 062'],
    summary: '每次砍掉一半区间。',
    explain:
        '二分查找要求数组已排序。每次看中间元素，比目标小就把左边界右移，比目标大就把右边界左移。关键是 mid 的计算和边界更新要避免死循环：mid = lo + (hi - lo)/2，区间用闭区间 [lo, hi]。',
    code: '#include <stdio.h>\n'
        '\n'
        'int bsearchInt(const int *a, int n, int target) {\n'
        '    int lo = 0, hi = n - 1;\n'
        '    while (lo <= hi) {\n'
        '        int mid = lo + (hi - lo) / 2;\n'
        '        if (a[mid] == target) return mid;\n'
        '        if (a[mid] < target) lo = mid + 1;\n'
        '        else hi = mid - 1;\n'
        '    }\n'
        '    return -1;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    int a[7] = {2, 5, 8, 12, 16, 23, 38};\n'
        '    printf("find 16 -> %d\\n", bsearchInt(a, 7, 16));\n'
        '    printf("find 9 -> %d\\n", bsearchInt(a, 7, 9));\n'
        '    return 0;\n'
        '}\n',
    output: 'find 16 -> 4\nfind 9 -> -1\n',
    pitfalls: <String>[
      '对未排序数组做二分结果是错的。',
      '边界写成 lo < hi 或更新写 mid 本身都可能死循环。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '找出目标第一次出现的下标（数组有重复时）。',
        hint: '找到后不要立即返回，继续往左收缩 hi = mid - 1。',
        answer: 'if (a[mid] == target) { result = mid; hi = mid - 1; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 64,
    language: 'c',
    level: 'intermediate',
    title: 'C 064：单链表',
    standard: 'c17',
    concepts: <String>['链表', '节点', 'next 指针', '插入遍历'],
    objective: '用节点和 next 指针实现链表。',
    prerequisites: <String>['C 052'],
    summary: '节点存数据加一个指向下一个的指针。',
    explain:
        '链表由节点组成，每个节点含数据和指向下一个节点的指针，最后一个节点的 next 是 NULL。头插法在头部插入是 O(1)。遍历靠 next 指针一个个走。链表插入删除比数组灵活，但随机访问是 O(n)。',
    code: '#include <stdio.h>\n'
        '#include <stdlib.h>\n'
        '\n'
        'typedef struct Node {\n'
        '    int value;\n'
        '    struct Node *next;\n'
        '} Node;\n'
        '\n'
        'Node *push(Node *head, int value) {\n'
        '    Node *n = (Node *)malloc(sizeof(Node));\n'
        '    n->value = value;\n'
        '    n->next = head;\n'
        '    return n;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    Node *head = NULL;\n'
        '    for (int i = 1; i <= 3; i++) head = push(head, i);\n'
        '    for (Node *p = head; p != NULL; p = p->next) printf("%d ", p->value);\n'
        '    printf("\\n");\n'
        '    while (head != NULL) { Node *t = head->next; free(head); head = t; }\n'
        '    return 0;\n'
        '}\n',
    output: '3 2 1 \n',
    pitfalls: <String>[
      '头插法让元素顺序反转，最后插入的在最前。',
      '释放链表要先存下一个节点，再 free 当前节点。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个函数求链表长度。',
        hint: '遍历时用计数器累加。',
        answer: 'int length(Node *head) { int n = 0; for (Node *p = head; p; p = p->next) n++; return n; }',
      ),
    ],
  ),
];
