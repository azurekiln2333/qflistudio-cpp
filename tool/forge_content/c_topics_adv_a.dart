import 'forge_topic.dart';

/// C curriculum — advanced / engineering track, part A (topics 65..74).
///
/// Files, error handling, opaque handles, callbacks/vtables, varargs,
/// preprocessor, tokenizing and CSV parsing.
const List<ForgeTopic> cTopicsAdvA = <ForgeTopic>[
  ForgeTopic(
    id: 65,
    language: 'c',
    level: 'advanced',
    title: 'C 065：文件读写——文本模式',
    standard: 'c17',
    concepts: <String>['fopen', 'fclose', 'fgets', 'fprintf', '逐行读取'],
    objective: '打开文件、逐行读取、写回并正确关闭。',
    prerequisites: <String>['C 041'],
    summary: '用 FILE* 读写文本文件。',
    explain:
        'fopen 返回 FILE*，失败返回 NULL，必须检查。fgets 逐行读取（带缓冲区大小），fprintf 写文本。用完必须 fclose，否则数据可能没落盘。读文件循环用 while (fgets(...)) 判断是否到文件尾。示例自建一个临时文件再读它，保证可重复运行。',
    code:
        '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    FILE *w = fopen("demo.txt", "w");\n'
        '    if (!w) { printf("open failed\\n"); return 1; }\n'
        '    fprintf(w, "alpha\\n");\n'
        '    fprintf(w, "beta\\n");\n'
        '    fclose(w);\n'
        '    FILE *r = fopen("demo.txt", "r");\n'
        '    char line[64];\n'
        '    int count = 0;\n'
        '    while (fgets(line, sizeof(line), r)) {\n'
        '        printf("line: %s", line);\n'
        '        count++;\n'
        '    }\n'
        '    fclose(r);\n'
        '    printf("count=%d\\n", count);\n'
        '    return 0;\n'
        '}\n',
    output: 'line: alpha\nline: beta\ncount=2\n',
    pitfalls: <String>[
      '不检查 fopen 的 NULL 返回会导致后续崩溃。',
      '忘记 fclose 会泄漏文件句柄、丢失缓冲数据。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个程序统计某文件的行数。',
        hint: '循环 fgets，每读到一行计数器加一。',
        answer: 'int lines = 0;\nwhile (fgets(line, sizeof(line), f)) lines++;',
      ),
    ],
  ),
  ForgeTopic(
    id: 66,
    language: 'c',
    level: 'advanced',
    title: 'C 066：二进制文件读写',
    standard: 'c17',
    concepts: <String>['fwrite', 'fread', 'fseek', '结构体序列化'],
    objective: '用 fwrite/fread 存取结构体数组。',
    prerequisites: <String>['C 065'],
    summary: '按字节读写数据结构。',
    explain:
        'fwrite 把内存中的一段字节写到文件，fread 反过来读回。把结构体数组整块写出去、整块读回来很常见。注意字节序和结构体填充会随平台变化，跨平台持久化要自己定义格式。fseek 可以定位到文件的任意位置。',
    code:
        '#include <stdio.h>\n'
        '\n'
        'typedef struct { int id; int score; } Record;\n'
        '\n'
        'int main(void) {\n'
        '    Record out[2] = {{1, 90}, {2, 85}};\n'
        '    FILE *f = fopen("data.bin", "wb");\n'
        '    fwrite(out, sizeof(Record), 2, f);\n'
        '    fclose(f);\n'
        '    Record in[2];\n'
        '    f = fopen("data.bin", "rb");\n'
        '    size_t n = fread(in, sizeof(Record), 2, f);\n'
        '    fclose(f);\n'
        '    printf("read=%zu\\n", n);\n'
        '    for (size_t i = 0; i < n; i++) printf("id=%d score=%d\\n", in[i].id, in[i].score);\n'
        '    return 0;\n'
        '}\n',
    output: 'read=2\nid=1 score=90\nid=2 score=85\n',
    pitfalls: <String>[
      'fread 的返回值是「读到了几个元素」，要用它判断是否读完。',
      '直接写结构体字节在不同平台/编译器下不兼容。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '用 fseek 读取第二个记录。',
        hint: 'fseek(f, sizeof(Record), SEEK_SET) 再 fread 一个。',
        answer:
            'fseek(f, (long)sizeof(Record), SEEK_SET);\nfread(&one, sizeof(Record), 1, f);',
      ),
    ],
  ),
  ForgeTopic(
    id: 67,
    language: 'c',
    level: 'advanced',
    title: 'C 067：errno 与错误处理',
    standard: 'c17',
    concepts: <String>['errno', 'perror', 'strerror', '错误传播'],
    objective: '用 errno 和 perror 报告系统调用失败原因。',
    prerequisites: <String>['C 065'],
    summary: '系统调用失败时问 errno 为什么。',
    explain:
        '很多标准库和系统调用失败时会设置当前线程的 errno。应立即保存它，再调用其他函数。perror 会打印「你给的说明: 系统错误信息」。strerror(errno) 返回对应的文字说明。错误码数值和文案依赖平台，应用应比较 ENOENT 等符号；Linux 的 ENOENT 为 2，WASI 为 44。错误处理的原则：能就地处理的就地处理，否则把错误往上返回，不要吞掉。',
    code:
        '#include <stdio.h>\n'
        '#include <errno.h>\n'
        '#include <string.h>\n'
        '\n'
        'int main(void) {\n'
        '    FILE *f = fopen("no_such_file_qfli.txt", "r");\n'
        '    if (f == NULL) {\n'
        '        const int error = errno;\n'
        '        printf("errno=%d\\n", error);\n'
        '        printf("message: %s\\n", strerror(error));\n'
        '    } else {\n'
        '        fclose(f);\n'
        '    }\n'
        '    printf("handled=%d\\n", f == NULL);\n'
        '    return 0;\n'
        '}\n',
    output: 'errno=2\nmessage: No such file or directory\nhandled=1\n',
    portableOutput: 'errno=44\nmessage: No such file or directory\nhandled=1\n',
    pitfalls: <String>[
      'errno 只反映最近一次失败，检查前不要调用可能改它的函数。',
      '成功调用不会清零 errno，不能靠它判断是否成功。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '在打开失败时用 perror 打印错误。',
        hint: 'perror("open demo") 会带上前缀。',
        answer: 'if (f == NULL) perror("open demo");',
      ),
    ],
  ),
  ForgeTopic(
    id: 68,
    language: 'c',
    level: 'advanced',
    title: 'C 068：不透明指针与句柄',
    standard: 'c17',
    concepts: <String>['opaque pointer', '封装', '句柄', 'ABI'],
    objective: '用不透明指针隐藏结构体实现细节。',
    prerequisites: <String>['C 052'],
    summary: '头文件只见句柄，实现藏在 .c 里。',
    explain:
        '不透明指针是「只暴露一个指针类型，不暴露结构体定义」的封装手法：调用方只能通过函数操作句柄，无法直接访问字段。这样修改内部结构不影响调用方，也便于保持二进制兼容。示例把结构体定义和操作函数放在一起，模拟这种模块边界。',
    code:
        '#include <stdio.h>\n'
        '#include <stdlib.h>\n'
        '\n'
        'typedef struct Counter Counter;\n'
        '\n'
        'Counter *counterCreate(int start);\n'
        'void counterAdd(Counter *c, int delta);\n'
        'int counterValue(const Counter *c);\n'
        'void counterDestroy(Counter *c);\n'
        '\n'
        'struct Counter { int value; };\n'
        '\n'
        'Counter *counterCreate(int start) {\n'
        '    Counter *c = (Counter *)malloc(sizeof(Counter));\n'
        '    if (c) c->value = start;\n'
        '    return c;\n'
        '}\n'
        'void counterAdd(Counter *c, int delta) { c->value += delta; }\n'
        'int counterValue(const Counter *c) { return c->value; }\n'
        'void counterDestroy(Counter *c) { free(c); }\n'
        '\n'
        'int main(void) {\n'
        '    Counter *c = counterCreate(10);\n'
        '    counterAdd(c, 32);\n'
        '    printf("value=%d\\n", counterValue(c));\n'
        '    counterDestroy(c);\n'
        '    return 0;\n'
        '}\n',
    output: 'value=42\n',
    pitfalls: <String>['调用方若能看到 struct 定义，封装就失效了。', '句柄的创建和销毁要配对，否则泄漏。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给句柄接口加一个 counterReset 函数。',
        hint: '把 value 设回 0。',
        answer: 'void counterReset(Counter *c) { c->value = 0; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 69,
    language: 'c',
    level: 'advanced',
    title: 'C 069：回调式接口与虚表',
    standard: 'c17',
    concepts: <String>['虚表', 'struct 函数指针', '多态'],
    objective: '用函数指针结构体模拟面向对象的多态。',
    prerequisites: <String>['C 051'],
    summary: '把一组函数指针放进结构体当接口。',
    explain:
        'C 没有类，但可以用「结构体里放函数指针」来模拟虚表。不同实现提供各自的函数，调用方通过统一的接口指针调用。标准库的 FILE 和很多驱动接口都是这个思路。示例定义一个简单的 Shape 接口和两种实现。',
    code:
        '#include <stdio.h>\n'
        '\n'
        'typedef struct Shape Shape;\n'
        'struct Shape {\n'
        '    const char *name;\n'
        '    double (*area)(const Shape *);\n'
        '};\n'
        '\n'
        'double rectArea(const Shape *s) { (void)s; return 3.0 * 4.0; }\n'
        'double circleArea(const Shape *s) { (void)s; return 3.14159 * 1.0 * 1.0; }\n'
        '\n'
        'int main(void) {\n'
        '    Shape r = {"rect", rectArea};\n'
        '    Shape c = {"circle", circleArea};\n'
        '    const Shape *shapes[2] = {&r, &c};\n'
        '    for (int i = 0; i < 2; i++) {\n'
        '        printf("%s area=%.2f\\n", shapes[i]->name, shapes[i]->area(shapes[i]));\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: 'rect area=12.00\ncircle area=3.14\n',
    pitfalls: <String>['函数指针要用 -> 或 (*p) 调用，别写成方法语法。', '每个实现都必须填充虚表里的所有函数指针。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 Shape 加一个求周长的函数指针和两种实现。',
        hint: '在 struct 里加 double (*perimeter)(const Shape *)。',
        answer:
            'struct Shape { const char *name; double (*area)(const Shape *); double (*perimeter)(const Shape *); };',
      ),
    ],
  ),
  ForgeTopic(
    id: 70,
    language: 'c',
    level: 'advanced',
    title: 'C 070：变参函数与 va_list',
    standard: 'c17',
    concepts: <String>['变参', 'va_list', 'va_start', 'va_arg'],
    objective: '实现一个参数个数可变的函数。',
    prerequisites: <String>['C 050'],
    summary: '像 printf 那样接收不确定个数的参数。',
    explain:
        '用 <stdarg.h> 的 va_list、va_start、va_arg、va_end 可以实现变参函数。因为无法自动得知参数个数，通常约定一个「参数个数」参数或一个哨兵值。printf 是靠格式串里的占位符个数来知道要取几个参数。',
    code:
        '#include <stdio.h>\n'
        '#include <stdarg.h>\n'
        '\n'
        'int sum(int count, ...) {\n'
        '    va_list args;\n'
        '    va_start(args, count);\n'
        '    int total = 0;\n'
        '    for (int i = 0; i < count; i++) total += va_arg(args, int);\n'
        '    va_end(args);\n'
        '    return total;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    printf("sum3=%d\\n", sum(3, 10, 20, 12));\n'
        '    printf("sum4=%d\\n", sum(4, 1, 2, 3, 4));\n'
        '    return 0;\n'
        '}\n',
    output: 'sum3=42\nsum4=10\n',
    pitfalls: <String>[
      'va_arg 的类型必须与传入实参的实际类型一致，否则未定义。',
      '忘记 va_end 可能在某些 ABI 上出问题。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个变参函数求最大值，用哨兵 0 结束。',
        hint: '循环 va_arg 直到遇到 0。',
        answer:
            'int maxSenti(int first, ...) { va_list a; va_start(a, first); int m = first, v; while ((v = va_arg(a, int)) != 0) if (v > m) m = v; va_end(a); return m; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 71,
    language: 'c',
    level: 'advanced',
    title: 'C 071：预处理器——宏与条件编译',
    standard: 'c17',
    concepts: <String>['#define', '带参数宏', '#ifdef', 'include guard'],
    objective: '用宏做常量、简单内联和条件编译。',
    prerequisites: <String>['C 028'],
    summary: '预处理在编译前做文本级替换。',
    explain:
        '预处理器在编译前工作：#define 定义常量或带参数宏，#ifdef/#ifndef 做条件编译，include guard 防止头文件被重复包含。带参数宏要整体加括号，避免运算符优先级问题。能用函数就别用宏，宏只是文本替换。',
    code:
        '#include <stdio.h>\n'
        '\n'
        '#define SQUARE(x) ((x) * (x))\n'
        '#define MAX(a, b) ((a) > (b) ? (a) : (b))\n'
        '#define FLAG 1\n'
        '\n'
        'int main(void) {\n'
        '    printf("square(3+1)=%d\\n", SQUARE(3 + 1));\n'
        '    printf("max=%d\\n", MAX(10, 7));\n'
        '#ifdef FLAG\n'
        '    printf("flag enabled\\n");\n'
        '#endif\n'
        '    return 0;\n'
        '}\n',
    output: 'square(3+1)=16\nmax=10\nflag enabled\n',
    pitfalls: <String>['宏参数不加括号会因优先级得到错误结果。', '带副作用的参数如 SQUARE(i++) 会被求值两次。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个带参数宏求三个数的最大值。',
        hint: '嵌套使用 MAX。',
        answer: '#define MAX3(a, b, c) MAX(MAX(a, b), c)',
      ),
    ],
  ),
  ForgeTopic(
    id: 72,
    language: 'c',
    level: 'advanced',
    title: 'C 072：条件编译与平台适配',
    standard: 'c17',
    concepts: <String>['#if', '#elif', '#else', '平台宏'],
    objective: '用条件编译针对不同平台/配置编译不同代码。',
    prerequisites: <String>['C 071'],
    summary: '同一份源码适配多种环境。',
    explain:
        '条件编译常用于平台差异和调试开关。编译器会预定义一些平台宏，如 _WIN32、__linux__、__APPLE__、__wasi__。宏描述编译目标环境，因此手机上的 WASI 程序识别为 wasi。用 #if defined(...) 组合判断。注意：被条件编译排除的代码不参与编译，所以语法错误也不会被发现。',
    code:
        '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '#if defined(_WIN32)\n'
        '    const char *os = "windows";\n'
        '#elif defined(__APPLE__)\n'
        '    const char *os = "macos";\n'
        '#elif defined(__linux__)\n'
        '    const char *os = "linux";\n'
        '#elif defined(__wasi__)\n'
        '    const char *os = "wasi";\n'
        '#else\n'
        '    const char *os = "unknown";\n'
        '#endif\n'
        '    printf("os=%s\\n", os);\n'
        '    return 0;\n'
        '}\n',
    output: 'os=linux\n',
    portableOutput: 'os=wasi\n',
    pitfalls: <String>['不同平台的输出不同，示例输出以 Linux 为准。', '条件编译块的括号/分号要成对，写错很难定位。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '增加一个 OS_NAME 宏，未定义时回退到 "unknown"。',
        hint: '先用 #ifndef OS_NAME 定义默认值。',
        answer: '#ifndef OS_NAME\n#define OS_NAME "unknown"\n#endif',
      ),
    ],
  ),
  ForgeTopic(
    id: 73,
    language: 'c',
    level: 'advanced',
    title: 'C 073：字符串解析——手写 tokenizer',
    standard: 'c17',
    concepts: <String>['词法分析', '状态机', '字符分类'],
    objective: '手写一个简单的表达式分词器。',
    prerequisites: <String>['C 048'],
    summary: '把 "12 + 34" 拆成数字和运算符。',
    explain:
        '分词是编译器和配置解析的第一步：扫描字符流，把连续的数字归成一个数，把运算符各归成一个记号。实现时用一个「当前位置」指针，遇到空白跳过，遇到数字就吃到不再是数字为止。这是自底向上解析文本的基本功。',
    code:
        '#include <stdio.h>\n'
        '#include <ctype.h>\n'
        '\n'
        'int main(void) {\n'
        '    const char *s = "12 + 34*5";\n'
        '    int i = 0;\n'
        '    while (s[i] != \'\\0\') {\n'
        '        if (isspace((unsigned char)s[i])) { i++; continue; }\n'
        '        if (isdigit((unsigned char)s[i])) {\n'
        '            int value = 0;\n'
        '            while (isdigit((unsigned char)s[i])) {\n'
        '                value = value * 10 + (s[i] - \'0\');\n'
        '                i++;\n'
        '            }\n'
        '            printf("number %d\\n", value);\n'
        '        } else {\n'
        '            printf("operator %c\\n", s[i]);\n'
        '            i++;\n'
        '        }\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: 'number 12\noperator +\nnumber 34\noperator *\nnumber 5\n',
    pitfalls: <String>[
      '传给 isdigit/isspace 前要转成 unsigned char，避免负值。',
      '数字解析忘记推进下标会死循环。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '让分词器跳过逗号。',
        hint: '遇到 s[i] == \',\' 就 i++ 继续。',
        answer: 'if (s[i] == \',\') { i++; continue; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 74,
    language: 'c',
    level: 'advanced',
    title: 'C 074：手写 CSV 解析',
    standard: 'c17',
    concepts: <String>['CSV', '字段拆分', '异常行'],
    objective: '按逗号拆分一行 CSV 并转换成数值。',
    prerequisites: <String>['C 073'],
    summary: '把一行数据解析成字段。',
    explain:
        'CSV 解析比 strtok 多几步：要处理引号包裹的字段、空字段和字段个数不一致的行。示例用逐字符扫描，遇到逗号就收一个字段。真实项目里还要处理带逗号的引号字段、转义和换行，这里演示核心流程。',
    code:
        '#include <stdio.h>\n'
        '#include <stdlib.h>\n'
        '\n'
        'int main(void) {\n'
        '    const char *row = "alice,30,engineer";\n'
        '    char field[32];\n'
        '    int fi = 0, fields = 0;\n'
        '    for (int i = 0; ; i++) {\n'
        '        char c = row[i];\n'
        '        if (c == \',\' || c == \'\\0\') {\n'
        '            field[fi] = \'\\0\';\n'
        '            printf("field[%d]=%s\\n", fields, field);\n'
        '            fields++;\n'
        '            fi = 0;\n'
        '            if (c == \'\\0\') break;\n'
        '        } else if (fi < (int)sizeof(field) - 1) {\n'
        '            field[fi++] = c;\n'
        '        }\n'
        '    }\n'
        '    printf("total=%d\\n", fields);\n'
        '    return 0;\n'
        '}\n',
    output: 'field[0]=alice\nfield[1]=30\nfield[2]=engineer\ntotal=3\n',
    pitfalls: <String>['字段缓冲区要防止溢出，fi 不能超过容量。', '最后一行末尾没有逗号，要靠 \\0 收尾。'],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把第二列转成整数年龄并打印。',
        hint: '对字段用 atoi。',
        answer: 'printf("age=%d\\n", age); // age = atoi(第二个字段)',
      ),
    ],
  ),
];
