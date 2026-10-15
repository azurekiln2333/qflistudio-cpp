import 'forge_topic.dart';

/// C curriculum — advanced / engineering track, part B (topics 75..87).
///
/// Hashing, multi-file build engineering, assertions, struct layout, ring
/// buffers, generic containers, functional style, performance and bit-fields.
const List<ForgeTopic> cTopicsAdvB = <ForgeTopic>[
  ForgeTopic(
    id: 75,
    language: 'c',
    level: 'advanced',
    title: 'C 075：散列函数与哈希表思想',
    standard: 'c17',
    concepts: <String>['哈希', 'FNV', '冲突', '装载因子'],
    objective: '实现一个字符串散列函数并理解冲突。',
    prerequisites: <String>['C 064'],
    summary: '把字符串映射成一个整数下标。',
    explain:
        '哈希表靠散列函数把键映射到桶下标，从而平均 O(1) 查找。FNV-1a 是简单可靠的字符串散列：先取一个偏移基数，再对每个字节先异或后乘。不同键可能落到同一桶（冲突），需要拉链或开放寻址处理。装载因子过高会退化。',
    code:
        '#include <stdio.h>\n'
        '#include <stdint.h>\n'
        '\n'
        'uint32_t fnv1a(const char *s) {\n'
        '    uint32_t h = 2166136261u;\n'
        '    while (*s) {\n'
        '        h ^= (unsigned char)*s++;\n'
        '        h *= 16777619u;\n'
        '    }\n'
        '    return h;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    const char *keys[] = {"apple", "banana", "cherry"};\n'
        '    for (int i = 0; i < 3; i++) {\n'
        '        printf("%s bucket=%u\\n", keys[i], fnv1a(keys[i]) % 16);\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: 'apple bucket=15\nbanana bucket=0\ncherry bucket=8\n',
    pitfalls: <String>['用乘法和异或，别用取模，否则分布差。', '桶数取质数或 2 的幂会得到不同分布。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个更简单的 djb2 散列并比较结果。',
        hint: 'h = h*33 + c，初值 5381。',
        answer:
            'uint32_t djb2(const char *s) { uint32_t h = 5381; while (*s) h = h * 33 + (unsigned char)*s++; return h; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 76,
    language: 'c',
    level: 'advanced',
    title: 'C 076：多文件工程与头文件分工',
    standard: 'c17',
    concepts: <String>['模块', '声明/定义', 'include guard', '内部/外部链接'],
    objective: '把代码按模块拆分成 .h 和 .c。',
    prerequisites: <String>['C 032'],
    summary: '接口放头文件，实现放源文件。',
    explain:
        '多文件工程里，模块的公共接口放在 .h 头文件（只放声明），实现放在 .c 源文件。头文件加 include guard 防重复包含。只在模块内部使用的函数应加 static，限制在文件内。示例用注释展示典型的文件划分，代码保持单文件自包含以便运行。',
    code:
        '#include <stdio.h>\n'
        '\n'
        '/* 典型三文件结构：\n'
        '     stack.h  : typedef + 函数声明（带 include guard）\n'
        '     stack.c  : 结构体定义 + 函数实现（static 辅助函数）\n'
        '     main.c   : #include "stack.h" 后使用\n'
        '   这里合并为单文件演示同一逻辑。 */\n'
        '\n'
        'typedef struct { int data[8]; int top; } Stack;\n'
        '\n'
        'static void push(Stack *s, int v) { s->data[s->top++] = v; }\n'
        'static int pop(Stack *s) { return s->data[--s->top]; }\n'
        '\n'
        'int main(void) {\n'
        '    Stack s = {{0}, 0};\n'
        '    push(&s, 1);\n'
        '    push(&s, 2);\n'
        '    push(&s, 3);\n'
        '    printf("pop=%d\\n", pop(&s));\n'
        '    printf("pop=%d\\n", pop(&s));\n'
        '    return 0;\n'
        '}\n',
    output: 'pop=3\npop=2\n',
    pitfalls: <String>[
      '把定义放进头文件并被多个 .c 包含会导致重复定义。',
      'static 函数只在本文件可见，是模块私有化的手段。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写出 stack.h 的 include guard 与 push 声明。',
        hint: '#ifndef/#define/#endif 包裹再声明 push。',
        answer:
            '#ifndef STACK_H\n#define STACK_H\ntypedef struct { int data[8]; int top; } Stack;\nvoid push(Stack *, int);\nint pop(Stack *);\n#endif',
      ),
    ],
  ),
  ForgeTopic(
    id: 77,
    language: 'c',
    level: 'advanced',
    title: 'C 077：分离编译与链接顺序',
    standard: 'c17',
    concepts: <String>['分离编译', '链接', '符号', 'undefined reference'],
    objective: '理解编译每个文件、再链接成可执行文件的过程。',
    prerequisites: <String>['C 076'],
    summary: '为什么函数找不到是链接错误。',
    explain:
        '大项目把每个 .c 单独编译成 .o 目标文件（只检查本文件），再由链接器把所有 .o 和库合并成可执行文件。链接期才检查「函数是否真的存在」，所以拼错或漏实现报的是 undefined reference。用 nm 可以查看目标文件的符号。',
    code:
        '#include <stdio.h>\n'
        '\n'
        '/* 模拟两个翻译单元：unit_a 提供 add，main 调用它。\n'
        '   真实构建：cc -c unit_a.c 得到 unit_a.o\n'
        '             cc -c main.c   得到 main.o\n'
        '             cc unit_a.o main.o -o app  （链接） */\n'
        '\n'
        'int add(int a, int b);\n'
        '\n'
        'int main(void) {\n'
        '    printf("add=%d\\n", add(20, 22));\n'
        '    return 0;\n'
        '}\n'
        '\n'
        'int add(int a, int b) { return a + b; }\n',
    output: 'add=42\n',
    pitfalls: <String>[
      '编译单个 .c 时只需声明；链接时才需要定义。',
      '重复定义（两个 .o 里有同名非 static 函数）会报错。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '说明为什么把函数定义写进头文件容易出现重复定义。',
        hint: '头文件被多个 .c 包含后，每个 .o 都有一份定义。',
        answer: '头文件被多个源文件包含后，每个目标文件都含一份非 static 定义，链接时冲突。',
      ),
    ],
  ),
  ForgeTopic(
    id: 78,
    language: 'c',
    level: 'advanced',
    title: 'C 078：Makefile 与增量构建',
    standard: 'c17',
    concepts: <String>['make', '目标', '依赖', '增量'],
    objective: '看懂 Makefile 的规则和增量构建思想。',
    prerequisites: <String>['C 077'],
    summary: '只重新编译改动过的文件。',
    explain:
        'Makefile 用「目标: 依赖」描述构建规则，命令在下一行（前面必须是一个制表符）。make 比较目标文件和依赖的时间戳，只重建过期的目标，这就是增量构建。变量 CC、CFLAGS 让编译选项集中管理。示例不依赖 make 运行，只讲解结构。',
    code:
        '#include <stdio.h>\n'
        '\n'
        '/* 典型 Makefile：\n'
        '     CC = gcc\n'
        '     CFLAGS = -std=c17 -Wall -Wextra\n'
        '     app: main.o util.o\n'
        '     \t\$(CC) \$(CFLAGS) main.o util.o -o app\n'
        '     main.o: main.c util.h\n'
        '     \t\$(CC) \$(CFLAGS) -c main.c\n'
        '   目标 app 依赖两个 .o；只要某个 .c 比 .o 新就重建。 */\n'
        '\n'
        'int main(void) {\n'
        '    printf("make keeps builds incremental\\n");\n'
        '    return 0;\n'
        '}\n',
    output: 'make keeps builds incremental\n',
    pitfalls: <String>[
      '命令行前必须是制表符，空格会报 missing separator。',
      '依赖漏写头文件，改头文件后不会触发重建。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写出 app 目标依赖 main.o 与 util.o 的规则行。',
        hint: '目标: 依赖 换行后跟构建命令。',
        answer: 'app: main.o util.o\n\t\$(CC) \$(CFLAGS) main.o util.o -o app',
      ),
    ],
  ),
  ForgeTopic(
    id: 79,
    language: 'c',
    level: 'advanced',
    title: 'C 079：断言与运行时检查',
    standard: 'c17',
    concepts: <String>['assert', 'NDEBUG', '防御式编程', '前置条件'],
    objective: '用 assert 检查不应发生的条件。',
    prerequisites: <String>['C 067'],
    summary: '断言帮你抓住「本不该发生」的 bug。',
    explain:
        'assert(条件) 在条件为假时打印文件名行号并终止程序。它用来检查程序内部不变量和前置条件，是调试利器。定义 NDEBUG 后 assert 会被移除，所以不要用它处理可预期的错误（那要用返回值/errno）。',
    code:
        '#include <stdio.h>\n'
        '#include <assert.h>\n'
        '\n'
        'int divide(int a, int b) {\n'
        '    assert(b != 0 && "divisor must not be zero");\n'
        '    return a / b;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    printf("divide=%d\\n", divide(84, 2));\n'
        '    printf("checks passed\\n");\n'
        '    return 0;\n'
        '}\n',
    output: 'divide=42\nchecks passed\n',
    pitfalls: <String>[
      '断言里不要放有副作用的表达式，NDEBUG 下它会被删掉。',
      '可预期的输入错误要用返回值和 errno，不是 assert。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '在求数组平均值的函数里用 assert 检查长度大于 0。',
        hint: 'assert(n > 0);',
        answer:
            'double average(const int *v, int n) { assert(n > 0); int s = 0; for (int i = 0; i < n; i++) s += v[i]; return (double)s / n; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 80,
    language: 'c',
    level: 'advanced',
    title: 'C 080：结构体对齐与填充',
    standard: 'c17',
    concepts: <String>['对齐', '填充', 'offsetof', 'sizeof'],
    objective: '理解结构体为什么比字段之和更大。',
    prerequisites: <String>['C 045'],
    summary: '对齐要求让结构体出现空洞。',
    explain:
        '为了访问效率，编译器要求每个字段按自身大小对齐，于是字段之间会有填充字节，sizeof(struct) 可能大于字段之和。调整字段顺序（大的在前）常能减少填充。offsetof 宏可以查某个字段的偏移。',
    code:
        '#include <stdio.h>\n'
        '#include <stddef.h>\n'
        '\n'
        'struct Padded { char a; int b; char c; };\n'
        'struct Packed { int b; char a; char c; };\n'
        '\n'
        'int main(void) {\n'
        '    printf("padded=%zu\\n", sizeof(struct Padded));\n'
        '    printf("packed=%zu\\n", sizeof(struct Packed));\n'
        '    printf("offset b=%zu\\n", offsetof(struct Padded, b));\n'
        '    return 0;\n'
        '}\n',
    output: 'padded=12\npacked=8\noffset b=4\n',
    pitfalls: <String>['不要假设结构体大小等于字段之和。', '把结构体直接写入文件/网络会带上填充字节。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 struct Padded 的字段重排以减少填充，并打印大小。',
        hint: '把 int 放最前。',
        answer:
            'struct Padded { int b; char a; char c; };\nprintf("%zu\\n", sizeof(struct Padded)); // 8',
      ),
    ],
  ),
  ForgeTopic(
    id: 81,
    language: 'c',
    level: 'advanced',
    title: 'C 081：环形缓冲区',
    standard: 'c17',
    concepts: <String>['环形缓冲', '读写下标', '取模'],
    objective: '实现一个固定容量的环形缓冲区。',
    prerequisites: <String>['C 064'],
    summary: '用取模下标实现先进先出队列。',
    explain:
        '环形缓冲区用固定数组加读、写两个下标，下标对容量取模实现循环。适用于日志缓冲、生产者消费者等场景，无需动态分配。关键是判断空和满：用 count 计数比用下标差更简单可靠。',
    code:
        '#include <stdio.h>\n'
        '\n'
        'typedef struct {\n'
        '    int data[4];\n'
        '    int head, tail, count;\n'
        '} Ring;\n'
        '\n'
        'void push(Ring *r, int v) {\n'
        '    if (r->count == 4) return;\n'
        '    r->data[r->tail] = v;\n'
        '    r->tail = (r->tail + 1) % 4;\n'
        '    r->count++;\n'
        '}\n'
        'int pop(Ring *r, int *out) {\n'
        '    if (r->count == 0) return 0;\n'
        '    *out = r->data[r->head];\n'
        '    r->head = (r->head + 1) % 4;\n'
        '    r->count--;\n'
        '    return 1;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    Ring r = {{0}, 0, 0, 0};\n'
        '    push(&r, 1); push(&r, 2); push(&r, 3);\n'
        '    int v;\n'
        '    while (pop(&r, &v)) printf("%d ", v);\n'
        '    printf("\\n");\n'
        '    return 0;\n'
        '}\n',
    output: '1 2 3 \n',
    pitfalls: <String>['满/空判断不清会覆盖未读数据或读到旧值。', '取模的模数必须与数组容量一致。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '让 push 在满时覆盖最旧元素（丢弃最旧）。',
        hint: '满时先 pop 再 push。',
        answer: 'if (r->count == 4) { int tmp; pop(r, &tmp); }',
      ),
    ],
  ),
  ForgeTopic(
    id: 82,
    language: 'c',
    level: 'advanced',
    title: 'C 082：通用容器与 void*',
    standard: 'c17',
    concepts: <String>['void *', '泛型', '字节拷贝', 'memcpy'],
    objective: '用 void* 写一个能存任意类型的容器。',
    prerequisites: <String>['C 052'],
    summary: '不知道类型也能搬运数据。',
    explain:
        'void* 可以指向任何类型，配合元素大小就能写通用容器：分配 n*size 字节，用 memcpy 按字节拷贝元素，用 char* 做「按字节移动」的指针算术。代价是丢失类型信息，读取时要自己转回正确类型。',
    code:
        '#include <stdio.h>\n'
        '#include <stdlib.h>\n'
        '#include <string.h>\n'
        '\n'
        'typedef struct {\n'
        '    void *data;\n'
        '    size_t elemSize;\n'
        '    size_t count;\n'
        '} Vector;\n'
        '\n'
        'void vectorInit(Vector *v, size_t elemSize) {\n'
        '    v->elemSize = elemSize;\n'
        '    v->count = 0;\n'
        '    v->data = malloc(elemSize * 4);\n'
        '}\n'
        'void vectorPush(Vector *v, const void *elem) {\n'
        '    memcpy((char *)v->data + v->count * v->elemSize, elem, v->elemSize);\n'
        '    v->count++;\n'
        '}\n'
        'void *vectorAt(Vector *v, size_t i) {\n'
        '    return (char *)v->data + i * v->elemSize;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    Vector v;\n'
        '    vectorInit(&v, sizeof(int));\n'
        '    for (int i = 1; i <= 3; i++) vectorPush(&v, &i);\n'
        '    for (size_t i = 0; i < v.count; i++) printf("%d ", *(int *)vectorAt(&v, i));\n'
        '    printf("\\n");\n'
        '    free(v.data);\n'
        '    return 0;\n'
        '}\n',
    output: '1 2 3 \n',
    pitfalls: <String>[
      'void* 上的指针算术不是标准 C，要先转成 char*。',
      '忘记记录 elemSize 就无法正确移动元素。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用同一个 Vector 存 double。',
        hint: 'elemSize 换成 sizeof(double)。',
        answer:
            'Vector v; vectorInit(&v, sizeof(double));\ndouble x = 2.5; vectorPush(&v, &x);',
      ),
    ],
  ),
  ForgeTopic(
    id: 83,
    language: 'c',
    level: 'advanced',
    title: 'C 083：函数式风格与映射/过滤',
    standard: 'c17',
    concepts: <String>['map', 'filter', 'reduce', '函数指针'],
    objective: '用函数指针实现映射、过滤、归约。',
    prerequisites: <String>['C 051'],
    summary: '把「做什么」和「怎么遍历」分开。',
    explain:
        '映射把每个元素变成新值，过滤保留满足条件的元素，归约把整个数组折成一个值。它们的遍历框架固定，具体操作由函数指针提供。这种把逻辑与遍历分离的风格让代码更易复用和测试。',
    code:
        '#include <stdio.h>\n'
        '\n'
        'void map(int *dst, const int *src, int n, int (*f)(int)) {\n'
        '    for (int i = 0; i < n; i++) dst[i] = f(src[i]);\n'
        '}\n'
        'int filter(int *dst, const int *src, int n, int (*keep)(int)) {\n'
        '    int m = 0;\n'
        '    for (int i = 0; i < n; i++) if (keep(src[i])) dst[m++] = src[i];\n'
        '    return m;\n'
        '}\n'
        'int reduce(const int *a, int n, int init, int (*op)(int, int)) {\n'
        '    int acc = init;\n'
        '    for (int i = 0; i < n; i++) acc = op(acc, a[i]);\n'
        '    return acc;\n'
        '}\n'
        '\n'
        'int dbl(int x) { return x * 2; }\n'
        'int isEven(int x) { return x % 2 == 0; }\n'
        'int add(int a, int b) { return a + b; }\n'
        '\n'
        'int main(void) {\n'
        '    int src[6] = {1, 2, 3, 4, 5, 6};\n'
        '    int dst[6];\n'
        '    map(dst, src, 6, dbl);\n'
        '    printf("mapped=%d\\n", dst[5]);\n'
        '    int evens[6];\n'
        '    int m = filter(evens, src, 6, isEven);\n'
        '    printf("evens=%d sum=%d\\n", m, reduce(evens, m, 0, add));\n'
        '    return 0;\n'
        '}\n',
    output: 'mapped=12\nevens=3 sum=12\n',
    pitfalls: <String>['map 的目标数组必须与源数组一样大或更大。', 'filter 返回的是新长度，遍历要用它而不是原长度。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个过滤奇数的回调并统计个数。',
        hint: 'keep 回调返回 x % 2 != 0。',
        answer:
            'int isOdd(int x) { return x % 2 != 0; }\nint m = filter(dst, src, 6, isOdd);',
      ),
    ],
  ),
  ForgeTopic(
    id: 84,
    language: 'c',
    level: 'advanced',
    title: 'C 084：性能测量与优化',
    standard: 'c17',
    concepts: <String>['clock', '基准测试', '复杂度', '过早优化'],
    objective: '用 clock 测量函数耗时并做有依据的优化。',
    prerequisites: <String>['C 061'],
    summary: '先测量，再优化。',
    explain:
        '优化前必须先测量。clock() 返回进程使用的 CPU 时间（CLOCKS_PER_SEC 为一秒的刻度），可以给一段代码计时；WASI 通过标准 SDK 以墙上时间模拟，不能把它当作纯 CPU 时间。比较不同算法时看的是随规模增长的趋势，而不是绝对毫秒。long 在部分目标上只有 32 位，本例使用至少 64 位的 long long 避免求和溢出。牢记：过早优化是万恶之源。',
    code:
        '#include <stdio.h>\n'
        '#include <time.h>\n'
        '\n'
        'long long sumFast(int n) { return (long long)n * (n + 1) / 2; }\n'
        '\n'
        'int main(void) {\n'
        '    clock_t start = clock();\n'
        '    long long r = sumFast(100000000);\n'
        '    clock_t end = clock();\n'
        '    double seconds = (double)(end - start) / CLOCKS_PER_SEC;\n'
        '    printf("result=%lld\\n", r);\n'
        '    printf("fast=%d\\n", seconds < 1.0);\n'
        '    return 0;\n'
        '}\n',
    output: 'result=5000000050000000\nfast=1\n',
    pitfalls: <String>['绝对耗时依赖机器，别把具体毫秒写进断言。', '编译器优化可能把循环消掉，测量要防止被优化。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个 O(n) 的循环版本求同样结果并比较。',
        hint: '循环累加 1..n。',
        answer:
            'long long sumLoop(int n) { long long s = 0; for (int i = 1; i <= n; i++) s += i; return s; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 85,
    language: 'c',
    level: 'advanced',
    title: 'C 085：位字段',
    standard: 'c17',
    concepts: <String>['bit-field', 'struct', '紧凑存储'],
    objective: '用位字段把多个小字段压进一个整数。',
    prerequisites: <String>['C 048'],
    summary: '在结构体里声明「占几位」。',
    explain:
        '结构体成员可以声明占多少位，如 unsigned flag : 1;。位字段把多个小值压进极小的空间，适合硬件寄存器映射和紧凑标志。但位字段的内存布局是实现定义的，跨平台/跨编译器不保证一致。',
    code:
        '#include <stdio.h>\n'
        '\n'
        'struct Flags {\n'
        '    unsigned ready : 1;\n'
        '    unsigned mode : 2;\n'
        '    unsigned level : 3;\n'
        '};\n'
        '\n'
        'int main(void) {\n'
        '    struct Flags f = {0, 0, 0};\n'
        '    f.ready = 1;\n'
        '    f.mode = 3;\n'
        '    f.level = 5;\n'
        '    printf("ready=%u mode=%u level=%u\\n", f.ready, f.mode, f.level);\n'
        '    printf("size=%zu\\n", sizeof(struct Flags));\n'
        '    return 0;\n'
        '}\n',
    output: 'ready=1 mode=3 level=5\nsize=4\n',
    pitfalls: <String>['位字段布局是实现定义的，不要据此假设二进制格式。', '给位字段赋值超出位数会被截断。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 Flags 加一个占 4 位的 code 字段。',
        hint: 'unsigned code : 4;。',
        answer:
            'struct Flags { unsigned ready : 1; unsigned mode : 2; unsigned level : 3; unsigned code : 4; };',
      ),
    ],
  ),
  ForgeTopic(
    id: 86,
    language: 'c',
    level: 'advanced',
    title: 'C 086：setjmp/longjmp 错误跳转',
    standard: 'c17',
    concepts: <String>['setjmp', 'longjmp', '非本地跳转', '清理'],
    objective: '理解 longjmp 如何跨函数跳转。',
    prerequisites: <String>['C 067'],
    summary: '从深层调用直接跳回调用点。',
    explain:
        'setjmp 记录当前执行点，longjmp 跳回该点，常用于「深层嵌套里出错直接返回顶层」。它绕过正常的函数返回，所以必须自己保证资源清理（释放内存、关闭文件），否则会泄漏。现代 C 一般优先用返回错误码。',
    code:
        '#include <stdio.h>\n'
        '#include <setjmp.h>\n'
        '\n'
        'static jmp_buf jb;\n'
        '\n'
        'void deep(int x) {\n'
        '    if (x < 0) longjmp(jb, 1);\n'
        '    printf("deep ok x=%d\\n", x);\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    if (setjmp(jb) == 0) {\n'
        '        deep(5);\n'
        '        deep(-1);\n'
        '        printf("unreachable\\n");\n'
        '    } else {\n'
        '        printf("recovered from error\\n");\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: 'deep ok x=5\nrecovered from error\n',
    pitfalls: <String>[
      'longjmp 跳过的函数不会执行清理，容易泄漏资源。',
      'setjmp 所在函数的局部变量在 longjmp 后可能不可靠。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '说明为什么用 longjmp 时要格外小心已分配的资源。',
        hint: '跳转会跳过中间的清理代码。',
        answer: 'longjmp 不展开调用栈，中间函数里的 free/fclose 不会执行，必须手动清理。',
      ),
    ],
  ),
  ForgeTopic(
    id: 87,
    language: 'c',
    level: 'advanced',
    title: 'C 087：命令行工具设计',
    standard: 'c17',
    concepts: <String>['argv 解析', '选项', '用法提示', '退出码'],
    objective: '写一个带选项和用法提示的命令行工具。',
    prerequisites: <String>['C 033'],
    summary: '解析参数、校验、给用法、设退出码。',
    explain:
        '命令行工具读取 argv，识别选项（如 -n），参数不合法时打印用法到 stderr 并返回非 0 退出码。退出码是脚本判断成功与否的接口：0 表示成功，非 0 表示各类失败。示例硬编码一组参数以便运行。',
    code:
        '#include <stdio.h>\n'
        '#include <string.h>\n'
        '\n'
        'int main(void) {\n'
        '    int argc = 4;\n'
        '    char *argv[] = {"app", "-n", "3", "name"};\n'
        '    int count = 1;\n'
        '    const char *label = NULL;\n'
        '    for (int i = 1; i < argc; i++) {\n'
        '        if (strcmp(argv[i], "-n") == 0 && i + 1 < argc) {\n'
        '            count = argv[i + 1][0] - \'0\';\n'
        '            i++;\n'
        '        } else {\n'
        '            label = argv[i];\n'
        '        }\n'
        '    }\n'
        '    if (label == NULL) {\n'
        '        fprintf(stderr, "usage: app [-n count] label\\n");\n'
        '        return 2;\n'
        '    }\n'
        '    for (int i = 0; i < count; i++) printf("%s\\n", label);\n'
        '    return 0;\n'
        '}\n',
    output: 'name\nname\nname\n',
    pitfalls: <String>[
      '读取 -n 后面的值前要确认 i+1 < argc。',
      '错误信息走 stderr，正常输出走 stdout。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '增加 -q（quiet）选项，安静模式下不打印。',
        hint: '解析到 -q 时设一个 quiet 标志。',
        answer:
            'int quiet = 0;\nif (strcmp(argv[i], "-q") == 0) { quiet = 1; continue; }\n// 打印前 if (!quiet) ...',
      ),
    ],
  ),
];
