import 'forge_topic.dart';

/// C curriculum — beginner track (topics 1..34).
///
/// Every topic is a complete, runnable C11 program in `code`, with the exact
/// stdout it prints in `output`. Examples are self-contained; multi-file
/// structure is explained in prose, never by including a file the app lacks.
const List<ForgeTopic> cTopicsBeginner = <ForgeTopic>[
  ForgeTopic(
    id: 1,
    language: 'c',
    level: 'beginner',
    title: 'C 001：第一个程序与 printf',
    standard: 'c17',
    concepts: <String>['main 函数', 'printf', '#include <stdio.h>', 'return'],
    objective: '写出并理解一个最小 C 程序的构成：入口、头文件、输出与返回值。',
    prerequisites: <String>[],
    summary: '从 main 开始，用 printf 打印第一行文本。',
    explain:
        'C 程序从 int main(void) 开始执行。printf 声明在 <stdio.h> 里，负责把文本写到标准输出；\\n 是换行符，不写光标会停在行尾。main 返回 0 表示程序正常结束。花括号 { } 圈出函数体，每条语句以分号结尾。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    printf("Hello, C!\\n");\n'
        '    printf("QFLIForge C17\\n");\n'
        '    return 0;\n'
        '}\n',
    output: 'Hello, C!\nQFLIForge C17\n',
    pitfalls: <String>[
      '忘记 #include <stdio.h> 会让 printf 无法声明。',
      '语句末尾漏分号是最常见的编译错误。',
      '\\n 写成 n 只是普通字符，不会换行。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把第二行输出改成你的名字。',
        hint: '修改第二个 printf 引号里的字符串即可。',
        answer: 'printf("你好，我是小明！\\n");',
      ),
    ],
  ),
  ForgeTopic(
    id: 2,
    language: 'c',
    level: 'beginner',
    title: 'C 002：变量与基本类型',
    standard: 'c17',
    concepts: <String>['int', 'double', 'char', '声明与初始化'],
    objective: '用 int / double / char 存储整数、小数和单个字符。',
    prerequisites: <String>['C 001'],
    summary: '认识 C 的三种基础类型并打印它们的值。',
    explain:
        'C 是静态类型语言：变量先声明类型再使用。int 存整数，double 存带小数的数，char 存单个字符（用单引号）。声明时可以直接初始化，例如 int age = 18;。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int count = 7;\n'
        '    double price = 12.5;\n'
        '    char grade = \'B\';\n'
        '    printf("count=%d\\n", count);\n'
        '    printf("price=%.1f\\n", price);\n'
        '    printf("grade=%c\\n", grade);\n'
        '    return 0;\n'
        '}\n',
    output: 'count=7\nprice=12.5\ngrade=B\n',
    pitfalls: <String>[
      'char 用单引号 \'a\'，用双引号是字符串。',
      '未初始化的局部变量含垃圾值，打印前务必赋值。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '再加一个 double 变量 weight 并打印到两位小数。',
        hint: '格式占位符用 %.2f。',
        answer: 'double weight = 60.5;\nprintf("weight=%.2f\\n", weight);',
      ),
    ],
  ),
  ForgeTopic(
    id: 3,
    language: 'c',
    level: 'beginner',
    title: 'C 003：格式占位符与 printf 细节',
    standard: 'c17',
    concepts: <String>['%d', '%f', '%c', '%s', '宽度与精度'],
    objective: '掌握常用格式占位符和最小宽度/精度控制。',
    prerequisites: <String>['C 002'],
    summary: '用占位符对齐数字、控制小数位数。',
    explain:
        'printf 用 %d 打印整数、%f 打印浮点、%c 打印字符、%s 打印字符串。%5d 表示占 5 列右对齐，%-5d 左对齐，%.3f 表示保留三位小数。占位符个数和参数必须一一对应，类型也要匹配。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    printf("[%5d]\\n", 42);\n'
        '    printf("[%-5d]\\n", 42);\n'
        '    printf("[%05d]\\n", 42);\n'
        '    printf("[%.3f]\\n", 3.14159);\n'
        '    printf("%s 得分 %d\\n", "小明", 95);\n'
        '    return 0;\n'
        '}\n',
    output: '[   42]\n[42   ]\n[00042]\n[3.142]\n小明 得分 95\n',
    pitfalls: <String>[
      '用 %d 打印 double 会得到未定义结果。',
      '占位符与参数数量不一致会读错栈上的后续值。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 3.14159 打印成科学计数法并保留两位小数。',
        hint: '用 %e 或 %.2e。',
        answer: 'printf("%.2e\\n", 3.14159); // 3.14e+00',
      ),
    ],
  ),
  ForgeTopic(
    id: 4,
    language: 'c',
    level: 'beginner',
    title: 'C 004：算术运算与整数除法',
    standard: 'c17',
    concepts: <String>['+ - * /', '%', '整数除法', '类型提升'],
    objective: '理解整数相除会截断，以及如何得到小数结果。',
    prerequisites: <String>['C 002'],
    summary: '加减乘除、取余，以及整数除法的坑。',
    explain:
        '两个 int 相除结果仍是 int，小数部分被直接丢弃：7/2 等于 3 而不是 3.5。想得到小数，至少让一个操作数是 double，例如 7.0/2 或 (double)7/2。% 取余数，只能用于整数。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int a = 7, b = 2;\n'
        '    printf("%d/%d = %d\\n", a, b, a / b);\n'
        '    printf("%d.0/%d = %.2f\\n", a, b, a / (double)b);\n'
        '    printf("%d %% %d = %d\\n", a, b, a % b);\n'
        '    return 0;\n'
        '}\n',
    output: '7/2 = 3\n7.0/2 = 3.50\n7 % 2 = 1\n',
    pitfalls: <String>[
      'printf 里输出百分号要写成 %%。',
      '负数取余的结果符号依赖实现，尽量避免对负数取余。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 145 秒换算成「几分几秒」并打印。',
        hint: '分钟用 /60，秒用 %60。',
        answer: 'int total = 145;\nprintf("%d 分 %d 秒\\n", total / 60, total % 60);',
      ),
    ],
  ),
  ForgeTopic(
    id: 5,
    language: 'c',
    level: 'beginner',
    title: 'C 005：取余运算的实用场景',
    standard: 'c17',
    concepts: <String>['%', '整除判断', '循环取模'],
    objective: '用取余判断奇偶、整除和循环索引。',
    prerequisites: <String>['C 004'],
    summary: '用 % 判断奇偶、求数字各位。',
    explain:
        'n % 2 == 0 判断偶数，n % 10 取个位，n / 10 去掉个位。取余也常用在循环里把一个递增计数映射到固定范围，例如 i % 3 在 0、1、2 之间循环。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int n = 12345;\n'
        '    int digitSum = 0;\n'
        '    while (n > 0) {\n'
        '        digitSum += n % 10;\n'
        '        n /= 10;\n'
        '    }\n'
        '    printf("digitSum=%d\\n", digitSum);\n'
        '    printf("even? %d\\n", 8 % 2 == 0);\n'
        '    return 0;\n'
        '}\n',
    output: 'digitSum=15\neven? 1\n',
    pitfalls: <String>[
      '循环取各位时忘记更新 n，会死循环。',
      '对 0 取余 a % 0 是未定义行为，会崩溃。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '判断一个数能否同时被 3 和 5 整除。',
        hint: '用 n % 15 == 0。',
        answer: 'int n = 30;\nprintf("%d\\n", n % 15 == 0); // 1',
      ),
    ],
  ),
  ForgeTopic(
    id: 6,
    language: 'c',
    level: 'beginner',
    title: 'C 006：运算符优先级与括号',
    standard: 'c17',
    concepts: <String>['优先级', '括号', '复合赋值'],
    objective: '理解常见优先级并主动加括号避免歧义。',
    prerequisites: <String>['C 004'],
    summary: '乘除先于加减，括号最优先。',
    explain:
        '乘、除、取余的优先级高于加、减，赋值最低。表达式 a + b * c 先算 b*c。复合赋值 +=、-=、*=、/= 把运算和赋值合在一起，a += 3 等价于 a = a + 3。拿不准就加括号。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int a = 2 + 3 * 4;\n'
        '    int b = (2 + 3) * 4;\n'
        '    int c = 10;\n'
        '    c += 5;\n'
        '    c *= 2;\n'
        '    printf("a=%d b=%d c=%d\\n", a, b, c);\n'
        '    return 0;\n'
        '}\n',
    output: 'a=14 b=20 c=30\n',
    pitfalls: <String>[
      '误以为 a + b * c 是从左到右。',
      '复合赋值中间结果会被截断，整数除法要小心。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '计算 (10 - 2) / (3 + 1) 并打印。',
        hint: '先算两个括号里的值再相除。',
        answer: 'printf("%d\\n", (10 - 2) / (3 + 1)); // 2',
      ),
    ],
  ),
  ForgeTopic(
    id: 7,
    language: 'c',
    level: 'beginner',
    title: 'C 007：类型转换',
    standard: 'c17',
    concepts: <String>['隐式转换', '强制转换', '(double)', '截断'],
    objective: '在整数与小数之间安全地转换。',
    prerequisites: <String>['C 004'],
    summary: '自动提升与显式 (type) 强制转换。',
    explain:
        '混合类型运算时，较小的类型会自动提升为较大的，例如 int 和 double 混算会提升成 double。反过来把 double 赋值给 int 会截断小数。显式强制转换写成 (double)x，表明这是有意为之。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int total = 17, count = 5;\n'
        '    double avgImplicit = total / count;\n'
        '    double avgExplicit = (double)total / count;\n'
        '    int truncated = (int)3.9;\n'
        '    printf("implicit=%.2f\\n", avgImplicit);\n'
        '    printf("explicit=%.2f\\n", avgExplicit);\n'
        '    printf("truncated=%d\\n", truncated);\n'
        '    return 0;\n'
        '}\n',
    output: 'implicit=3.00\nexplicit=3.40\ntruncated=3\n',
    pitfalls: <String>[
      'total / count 已经是整数除法，先除再赋值给 double 也救不回来。',
      'double 转 int 是截断不是四舍五入。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 9 和 2 相除得到 4.50，验证强转的位置。',
        hint: '写 (double)9 / 2 或 9 / 2.0。',
        answer: 'printf("%.2f\\n", (double)9 / 2); // 4.50',
      ),
    ],
  ),
  ForgeTopic(
    id: 8,
    language: 'c',
    level: 'beginner',
    title: 'C 008：字符与 ASCII',
    standard: 'c17',
    concepts: <String>['char', 'ASCII', '字符运算'],
    objective: '理解字符本质是整数编码，可做算术。',
    prerequisites: <String>['C 002'],
    summary: '字符按 ASCII 码存储，可参与运算。',
    explain:
        'char 实际存的是字符的编码值。\'A\' 是 65，\'a\' 是 97。因此 \'a\' - \'A\' 等于 32，可以让小写字母减去 32 变大写。用 %c 打印字符，用 %d 打印它的编码。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    char lower = \'g\';\n'
        '    char upper = lower - 32;\n'
        '    printf("lower=%c code=%d\\n", lower, lower);\n'
        '    printf("upper=%c code=%d\\n", upper, upper);\n'
        '    printf("gap=%d\\n", \'a\' - \'A\');\n'
        '    return 0;\n'
        '}\n',
    output: 'lower=g code=103\nupper=G code=71\ngap=32\n',
    pitfalls: <String>[
      '只对 ASCII 字母成立，非字母不能这样转换。',
      'char 是否有符号依赖实现，做算术时注意范围。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把字符 \'5\' 转成它代表的整数 5。',
        hint: '字符数字的编码连续，用 \'5\' - \'0\'。',
        answer: 'printf("%d\\n", \'5\' - \'0\'); // 5',
      ),
    ],
  ),
  ForgeTopic(
    id: 9,
    language: 'c',
    level: 'beginner',
    title: 'C 009：布尔值与比较',
    standard: 'c17',
    concepts: <String>['比较运算符', '_Bool', 'stdbool.h', '真假'],
    objective: '用比较得到条件真假，认识 0 假非 0 真。',
    prerequisites: <String>['C 004'],
    summary: 'C 用 0 表示假，非 0 表示真。',
    explain:
        'C 没有内建 bool 关键字，比较表达式的结果是 int：0 表示假，非 0 表示真。包含 <stdbool.h> 后可以用 bool、true、false。比较运算符有 ==、!=、>、<、>=、<=。注意 = 是赋值，== 才是比较。',
    code: '#include <stdio.h>\n'
        '#include <stdbool.h>\n'
        '\n'
        'int main(void) {\n'
        '    int x = 10;\n'
        '    bool positive = x > 0;\n'
        '    bool even = x % 2 == 0;\n'
        '    printf("positive=%d even=%d\\n", positive, even);\n'
        '    printf("5 > 3 = %d\\n", 5 > 3);\n'
        '    printf("5 == 3 = %d\\n", 5 == 3);\n'
        '    return 0;\n'
        '}\n',
    output: 'positive=1 even=1\n5 > 3 = 1\n5 == 3 = 0\n',
    pitfalls: <String>[
      '把 if (x = 0) 写成赋值，条件永远为假。',
      '浮点数用 == 比较常常失败，应比较差值。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '判断 15 是否既大于 10 又小于 20。',
        hint: '用逻辑与 && 连接两个比较。',
        answer: 'printf("%d\\n", 15 > 10 && 15 < 20); // 1',
      ),
    ],
  ),
  ForgeTopic(
    id: 10,
    language: 'c',
    level: 'beginner',
    title: 'C 010：if 与 else',
    standard: 'c17',
    concepts: <String>['if', 'else', '条件分支'],
    objective: '用 if/else 让程序根据条件走不同分支。',
    prerequisites: <String>['C 009'],
    summary: '最基础的条件判断。',
    explain:
        'if (条件) 后面跟一段花括号代码，条件为真时执行；else 在条件为假时执行。条件可以是任意表达式，非 0 即为真。花括号即使只有一条语句也建议保留，避免后续增行时出错。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int temperature = 30;\n'
        '    if (temperature >= 28) {\n'
        '        printf("天气炎热\\n");\n'
        '    } else {\n'
        '        printf("天气舒适\\n");\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: '天气炎热\n',
    pitfalls: <String>[
      'else 会与最近的未配对 if 结合，缩进不能改变结合关系。',
      '条件后误加分号 if (x > 0); 会让分支体变空。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把温度改成 20，观察输出变化。',
        hint: '重新运行即可。',
        answer: '输出变成「天气舒适」',
      ),
    ],
  ),
  ForgeTopic(
    id: 11,
    language: 'c',
    level: 'beginner',
    title: 'C 011：else if 多分支',
    standard: 'c17',
    concepts: <String>['else if', '多分支', '区间判断'],
    objective: '用 else if 链处理多个互斥区间。',
    prerequisites: <String>['C 010'],
    summary: '成绩分档的经典写法。',
    explain:
        'else if 把多个条件串起来，从上到下依次判断，命中一个就跳过其余。条件的顺序很重要：如果先判断 >= 60 再判断 >= 90，高分会先被低档截住。一般从最严格的条件开始写。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int score = 85;\n'
        '    if (score >= 90) {\n'
        '        printf("优秀\\n");\n'
        '    } else if (score >= 75) {\n'
        '        printf("良好\\n");\n'
        '    } else if (score >= 60) {\n'
        '        printf("及格\\n");\n'
        '    } else {\n'
        '        printf("不及格\\n");\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: '良好\n',
    pitfalls: <String>[
      '条件顺序写反会让宽条件吞掉窄条件。',
      '区间左闭右开要统一，否则边界会漏判。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 score 改成 92，确认落到「优秀」。',
        hint: '>= 90 先命中。',
        answer: '输出变成「优秀」',
      ),
    ],
  ),
  ForgeTopic(
    id: 12,
    language: 'c',
    level: 'beginner',
    title: 'C 012：switch 分支',
    standard: 'c17',
    concepts: <String>['switch', 'case', 'break', 'default'],
    objective: '用 switch 处理离散取值的多分支。',
    prerequisites: <String>['C 011'],
    summary: '按整数或字符取值选择分支。',
    explain:
        'switch 把一个整数或字符表达式和多个 case 比较。每个 case 结束后通常写 break，否则会「贯穿」执行下一个 case。default 处理没有命中任何 case 的情况。switch 只能比较整型常量，不能比较区间。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    char op = \'*\';\n'
        '    int a = 6, b = 7;\n'
        '    switch (op) {\n'
        '        case \'+\': printf("%d\\n", a + b); break;\n'
        '        case \'-\': printf("%d\\n", a - b); break;\n'
        '        case \'*\': printf("%d\\n", a * b); break;\n'
        '        default: printf("unknown\\n"); break;\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: '42\n',
    pitfalls: <String>[
      '漏写 break 会让多个分支连续执行。',
      'case 标签必须是编译期常量，不能是变量。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '增加一个 case \'/\' 实现整除，并处理除零。',
        hint: '在 case \'/\' 里判断 b 是否为 0。',
        answer: "case '/': if (b != 0) printf(\"%d\\n\", a / b); else printf(\"div0\\n\"); break;",
      ),
    ],
  ),
  ForgeTopic(
    id: 13,
    language: 'c',
    level: 'beginner',
    title: 'C 013：for 循环',
    standard: 'c17',
    concepts: <String>['for', '循环变量', '累加'],
    objective: '用 for 在已知次数下重复执行。',
    prerequisites: <String>['C 009'],
    summary: '计数循环的标准形式。',
    explain:
        'for (初始化; 条件; 步进) 是最常见的循环写法。初始化只执行一次，每轮结束执行步进，每轮开始检查条件。循环体用花括号包住多条语句。累加是循环最典型的用法：先准备 sum = 0，每轮往里加。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int sum = 0;\n'
        '    for (int i = 1; i <= 100; i++) {\n'
        '        sum += i;\n'
        '    }\n'
        '    printf("1..100 sum=%d\\n", sum);\n'
        '    for (int i = 5; i >= 1; i--) {\n'
        '        printf("%d ", i);\n'
        '    }\n'
        '    printf("go!\\n");\n'
        '    return 0;\n'
        '}\n',
    output: '1..100 sum=5050\n5 4 3 2 1 go!\n',
    pitfalls: <String>[
      '把 i <= n 写成 i < n 会少算一次。',
      '循环变量在 for 头声明时作用域仅限循环体。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '求 1 到 100 之间所有偶数的和。',
        hint: '循环里加 if (i % 2 == 0) sum += i;。',
        answer: 'for (int i = 1; i <= 100; i++) if (i % 2 == 0) sum += i;\n// 结果 2550',
      ),
    ],
  ),
  ForgeTopic(
    id: 14,
    language: 'c',
    level: 'beginner',
    title: 'C 014：while 循环',
    standard: 'c17',
    concepts: <String>['while', '条件循环', '收敛'],
    objective: '用 while 在次数不确定时循环直到条件不成立。',
    prerequisites: <String>['C 013'],
    summary: '条件为真就一直做。',
    explain:
        'while (条件) 在每轮开始检查条件，适合次数事先不确定的场景，比如反复除以 2 直到变成 1。必须保证循环体内有让条件趋向结束的语句，否则会无限循环。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int n = 100;\n'
        '    int steps = 0;\n'
        '    while (n != 1) {\n'
        '        if (n % 2 == 0) n /= 2;\n'
        '        else n = 3 * n + 1;\n'
        '        steps++;\n'
        '    }\n'
        '    printf("steps=%d\\n", steps);\n'
        '    return 0;\n'
        '}\n',
    output: 'steps=25\n',
    pitfalls: <String>[
      '忘记在循环体内改变条件变量会死循环。',
      '条件写成赋值 while (n = 1) 永远是 1。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '统计 27 需要多少步到达 1。',
        hint: '只需把 n 改成 27 再运行。',
        answer: 'int n = 27; // steps=111',
      ),
    ],
  ),
  ForgeTopic(
    id: 15,
    language: 'c',
    level: 'beginner',
    title: 'C 015：do-while 至少执行一次',
    standard: 'c17',
    concepts: <String>['do-while', '后置条件', '输入校验'],
    objective: '用 do-while 保证循环体至少执行一次。',
    prerequisites: <String>['C 014'],
    summary: '先做后判断的循环。',
    explain:
        'do { ... } while (条件); 先执行循环体再检查条件，所以至少执行一次。适合「先执行、再决定要不要继续」的场景，例如菜单循环。注意 while 后面要有分号。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int values[] = {3, 0, 7, 0};\n'
        '    int i = 0;\n'
        '    do {\n'
        '        printf("value=%d\\n", values[i]);\n'
        '        i++;\n'
        '    } while (i < 4 && values[i] != 0);\n'
        '    return 0;\n'
        '}\n',
    output: 'value=3\n',
    pitfalls: <String>[
      'while 条件后漏分号是语法错误。',
      'do-while 至少执行一次循环体；条件在末尾判断。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '让循环打印 values 的前两个元素。',
        hint: '条件是 i < 2 时继续。',
        answer: 'do { printf("value=%d\\n", values[i]); i++; } while (i < 2);',
      ),
    ],
  ),
  ForgeTopic(
    id: 16,
    language: 'c',
    level: 'beginner',
    title: 'C 016：break 与 continue',
    standard: 'c17',
    concepts: <String>['break', 'continue', '循环控制'],
    objective: '用 break 提前结束、用 continue 跳过本轮。',
    prerequisites: <String>['C 013'],
    summary: '精确控制循环的进出。',
    explain:
        'break 立即结束整个循环，continue 跳过本轮剩余语句直接进入下一轮。它们只影响最内层循环。查找场景常用 break 命中即停，过滤场景常用 continue 跳过不关心的数据。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int sum = 0;\n'
        '    for (int i = 1; i <= 10; i++) {\n'
        '        if (i % 3 == 0) continue;\n'
        '        if (i > 8) break;\n'
        '        sum += i;\n'
        '    }\n'
        '    printf("sum=%d\\n", sum);\n'
        '    return 0;\n'
        '}\n',
    output: 'sum=27\n',
    pitfalls: <String>[
      '在 switch 里 break 只跳出 switch，不跳出外层循环。',
      'continue 在 while 循环里若跳过条件更新会造成死循环。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '在 1 到 100 中找第一个能被 7 和 5 同时整除的数。',
        hint: '用 for 加 if (i % 35 == 0) { print; break; }。',
        answer: 'for (int i = 1; i <= 100; i++) if (i % 35 == 0) { printf("%d\\n", i); break; } // 35',
      ),
    ],
  ),
  ForgeTopic(
    id: 17,
    language: 'c',
    level: 'beginner',
    title: 'C 017：嵌套循环',
    standard: 'c17',
    concepts: <String>['嵌套循环', '外层与内层', '乘法表'],
    objective: '用两层循环遍历二维结构。',
    prerequisites: <String>['C 013'],
    summary: '外面管行，里面管列。',
    explain:
        '嵌套循环里，外层每走一步，内层完整走一遍。打印乘法表时外层是行号，内层是列号。两层循环的总执行次数是两者次数相乘，层次越深代价越大。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    for (int row = 1; row <= 3; row++) {\n'
        '        for (int col = 1; col <= 3; col++) {\n'
        '            printf("%d*%d=%d ", row, col, row * col);\n'
        '        }\n'
        '        printf("\\n");\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: '1*1=1 1*2=2 1*3=3 \n2*1=2 2*2=4 2*3=6 \n3*1=3 3*2=6 3*3=9 \n',
    pitfalls: <String>[
      '内外层用同一个循环变量会互相干扰。',
      '换行写在内层会让每列都换行。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '打印一个 4 行的直角三角形。',
        hint: '外层 row 1..4，内层 col 1..row。',
        answer: 'for (int r = 1; r <= 4; r++) { for (int c = 1; c <= r; c++) printf("*"); printf("\\n"); }',
      ),
    ],
  ),
  ForgeTopic(
    id: 18,
    language: 'c',
    level: 'beginner',
    title: 'C 018：用循环打印图形',
    standard: 'c17',
    concepts: <String>['图形打印', '空格与星号', '行号关系'],
    objective: '通过控制空格与星号数量画出对称图形。',
    prerequisites: <String>['C 017'],
    summary: '金字塔图形，理解行列与空格的关系。',
    explain:
        '画对称图形要分别控制前导空格数和星号数。第 r 行的空格数是 n - r，星号数是 2*r - 1。把这两个数量算清楚，任何三角形或菱形都能拼出来。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int n = 4;\n'
        '    for (int r = 1; r <= n; r++) {\n'
        '        for (int s = 0; s < n - r; s++) printf(" ");\n'
        '        for (int c = 0; c < 2 * r - 1; c++) printf("*");\n'
        '        printf("\\n");\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: '   *\n  ***\n *****\n*******\n',
    pitfalls: <String>[
      '空格和星号的数量公式写错会让图形歪斜。',
      '金字塔的空格数是 n-r，不是 r 本身。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '在金字塔下面再画一个倒金字塔。',
        hint: '让 r 从 n 递减到 1，其他公式不变。',
        answer: 'for (int r = n; r >= 1; r--) { for (int s = 0; s < n - r; s++) printf(" "); for (int c = 0; c < 2*r-1; c++) printf("*"); printf("\\n"); }',
      ),
    ],
  ),
  ForgeTopic(
    id: 19,
    language: 'c',
    level: 'beginner',
    title: 'C 019：函数与原型',
    standard: 'c17',
    concepts: <String>['函数', '返回类型', '参数', '函数原型'],
    objective: '把逻辑封装成函数并在 main 前声明原型。',
    prerequisites: <String>['C 008'],
    summary: '定义函数，学习前置声明。',
    explain:
        '函数由返回类型、名字、参数表和函数体组成。如果函数定义写在 main 之后，必须在前面写一行原型（也叫声明），让编译器先知道它的样子。void 表示没有参数或没有返回值。',
    code: '#include <stdio.h>\n'
        '\n'
        'int square(int x);\n'
        'int cube(int x);\n'
        '\n'
        'int main(void) {\n'
        '    printf("square(5)=%d\\n", square(5));\n'
        '    printf("cube(3)=%d\\n", cube(3));\n'
        '    return 0;\n'
        '}\n'
        '\n'
        'int square(int x) { return x * x; }\n'
        'int cube(int x) { return x * x * x; }\n',
    output: 'square(5)=25\ncube(3)=27\n',
    pitfalls: <String>[
      '漏写原型会让编译器按旧式隐式声明推断，可能报警或出错。',
      '函数返回类型和 return 的值类型要一致。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个 pow2 函数返回 2 的 n 次方（n 用循环实现）。',
        hint: '从 1 开始乘 n 次 2。',
        answer: 'int pow2(int n) { int r = 1; for (int i = 0; i < n; i++) r *= 2; return r; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 20,
    language: 'c',
    level: 'beginner',
    title: 'C 020：函数的参数与返回值',
    standard: 'c17',
    concepts: <String>['值传递', '多参数', '返回多个值?'],
    objective: '理解参数按值传递，函数内部改动不影响调用方。',
    prerequisites: <String>['C 019'],
    summary: '参数是拷贝，返回值带回结果。',
    explain:
        'C 的参数默认按值传递：函数拿到的是实参的副本，在函数内修改参数不会影响调用方。想带回多个结果，通常是把结果算好后通过返回值返回一个，或者（中级课）用指针。函数的返回类型决定它能不能被用在表达式里。',
    code: '#include <stdio.h>\n'
        '\n'
        'int add(int a, int b) { return a + b; }\n'
        'void bump(int x) { x = x + 1; }\n'
        '\n'
        'int main(void) {\n'
        '    int v = 10;\n'
        '    bump(v);\n'
        '    printf("after bump v=%d\\n", v);\n'
        '    printf("add(20,22)=%d\\n", add(20, 22));\n'
        '    return 0;\n'
        '}\n',
    output: 'after bump v=10\nadd(20,22)=42\n',
    pitfalls: <String>[
      '误以为 bump 能改变 v，其实改的是副本。',
      'void 函数不能用在需要值的表达式里。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写一个函数 maxOf 返回两个整数中较大的一个。',
        hint: '用三元运算符 a > b ? a : b。',
        answer: 'int maxOf(int a, int b) { return a > b ? a : b; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 21,
    language: 'c',
    level: 'beginner',
    title: 'C 021：作用域与生命周期',
    standard: 'c17',
    concepts: <String>['局部变量', '全局变量', '块作用域'],
    objective: '分清局部与全局变量的可见范围。',
    prerequisites: <String>['C 020'],
    summary: '变量在哪里可见、活多久。',
    explain:
        '在花括号里声明的变量是局部的，出了这对花括号就不可见。在每个函数外声明的是全局变量，整个文件可见。局部变量遮蔽同名全局变量时，函数内看到的是局部那个。尽量少用全局变量。',
    code: '#include <stdio.h>\n'
        '\n'
        'int counter = 0;\n'
        '\n'
        'void tick(void) {\n'
        '    int local = 100;\n'
        '    counter++;\n'
        '    printf("local=%d counter=%d\\n", local, counter);\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    tick();\n'
        '    tick();\n'
        '    printf("final counter=%d\\n", counter);\n'
        '    return 0;\n'
        '}\n',
    output: 'local=100 counter=1\nlocal=100 counter=2\nfinal counter=2\n',
    pitfalls: <String>[
      '在函数里访问另一个函数的局部变量会编译失败。',
      '全局变量让函数间产生隐藏依赖，调试变难。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '在 main 里再声明一个局部 counter 并演示遮蔽。',
        hint: 'main 内 int counter = 5; 打印它看结果。',
        answer: 'int counter = 5;\nprintf("shadow=%d\\n", counter); // 5',
      ),
    ],
  ),
  ForgeTopic(
    id: 22,
    language: 'c',
    level: 'beginner',
    title: 'C 022：数组基础',
    standard: 'c17',
    concepts: <String>['数组', '下标', '越界', '初始化'],
    objective: '声明数组、按索引读写并安全遍历。',
    prerequisites: <String>['C 013'],
    summary: '一次存一组同类型数据。',
    explain:
        '数组把同类型元素连续存放，下标从 0 开始。长度 5 的数组合法下标是 0 到 4。C 不检查越界，写超范围会破坏别的内存。用 for 循环配合下标遍历是最常见的用法，长度可以先算出来存进变量。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int scores[5] = {88, 92, 79, 95, 67};\n'
        '    int n = 5;\n'
        '    scores[0] = 90;\n'
        '    for (int i = 0; i < n; i++) {\n'
        '        printf("scores[%d]=%d\\n", i, scores[i]);\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output:
        'scores[0]=90\nscores[1]=92\nscores[2]=79\nscores[3]=95\nscores[4]=67\n',
    pitfalls: <String>[
      '下标从 0 开始，访问 scores[5] 已越界。',
      '数组名不能整体赋值，scores = ... 是语法错误。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把数组最后一个元素改成 100 并打印整个数组。',
        hint: '用 scores[4] = 100;（长度 5 的最后一个下标是 4）。',
        answer: 'scores[n - 1] = 100;\nfor (int i = 0; i < n; i++) printf("%d ", scores[i]);',
      ),
    ],
  ),
  ForgeTopic(
    id: 23,
    language: 'c',
    level: 'beginner',
    title: 'C 023：数组求和、平均与极值',
    standard: 'c17',
    concepts: <String>['遍历', '累加', '最大值', '最小值'],
    objective: '用一次遍历同时求总和、平均、最大和最小。',
    prerequisites: <String>['C 022'],
    summary: '数组统计四件套。',
    explain:
        '遍历数组时用一个 sum 累加、一个 max 和一个 min 跟踪极值。max/min 的初值应取第一个元素，而不是 0——否则全负数数组会得到错误的最大值 0。平均要转成 double 再除。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int data[6] = {-3, 8, -1, 5, 12, 4};\n'
        '    int n = 6, sum = 0, max = data[0], min = data[0];\n'
        '    for (int i = 0; i < n; i++) {\n'
        '        sum += data[i];\n'
        '        if (data[i] > max) max = data[i];\n'
        '        if (data[i] < min) min = data[i];\n'
        '    }\n'
        '    printf("sum=%d\\n", sum);\n'
        '    printf("avg=%.2f\\n", (double)sum / n);\n'
        '    printf("max=%d min=%d\\n", max, min);\n'
        '    return 0;\n'
        '}\n',
    output: 'sum=25\navg=4.17\nmax=12 min=-3\n',
    pitfalls: <String>[
      'max 初值设 0 会让全负数组判定错误。',
      '平均用整数除法会丢掉小数。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '额外统计数组里正数和负数的个数。',
        hint: '用两个计数器在循环里按符号加一。',
        answer: 'int pos = 0, neg = 0;\nfor (int i = 0; i < n; i++) { if (data[i] > 0) pos++; else if (data[i] < 0) neg++; }',
      ),
    ],
  ),
  ForgeTopic(
    id: 24,
    language: 'c',
    level: 'beginner',
    title: 'C 024：字符串是字符数组',
    standard: 'c17',
    concepts: <String>['char 数组', '字符串', '\\0 结尾'],
    objective: '理解字符串以 \\0 结尾，能手动遍历字符。',
    prerequisites: <String>['C 022'],
    summary: 'C 字符串的本质。',
    explain:
        'C 没有独立的字符串类型，字符串就是一个以 \\0（空字符）结尾的 char 数组。字面量 "abc" 实际占 4 个字节：a、b、c、\\0。遍历到 \\0 之前不能越界，printf 的 %s 也靠 \\0 判断结束。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    char word[] = "code";\n'
        '    int len = 0;\n'
        '    while (word[len] != \'\\0\') {\n'
        '        len++;\n'
        '    }\n'
        '    printf("word=%s len=%d\\n", word, len);\n'
        '    printf("first=%c last=%c\\n", word[0], word[len - 1]);\n'
        '    return 0;\n'
        '}\n',
    output: 'word=code len=4\nfirst=c last=e\n',
    pitfalls: <String>[
      '手动构造字符串忘记补 \\0，%s 会一直读到越界。',
      '数组长度要比可见字符多 1 才放得下 \\0。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把字符串 "code" 倒序打印。',
        hint: '从 len-1 倒着循环到 0。',
        answer: 'for (int i = len - 1; i >= 0; i--) printf("%c", word[i]); // edoc',
      ),
    ],
  ),
  ForgeTopic(
    id: 25,
    language: 'c',
    level: 'beginner',
    title: 'C 025：string.h 常用函数',
    standard: 'c17',
    concepts: <String>['strlen', 'strcmp', 'strcpy', 'strcat'],
    objective: '用标准库处理字符串长度、比较和拼接。',
    prerequisites: <String>['C 024'],
    summary: '不要手写 strlen，用标准库。',
    explain:
        '<string.h> 提供 strlen（长度）、strcmp（比较，返回 0 表示相等）、strcpy（复制）、strcat（拼接）。strcmp 按字典序返回负数、0 或正数，不能只用 == 比较字符串内容。复制和拼接的目标缓冲区必须足够大。',
    code: '#include <stdio.h>\n'
        '#include <string.h>\n'
        '\n'
        'int main(void) {\n'
        '    char a[32] = "hello";\n'
        '    char b[] = "world";\n'
        '    printf("len=%zu\\n", strlen(a));\n'
        '    printf("cmp=%d\\n", strcmp(a, b) < 0);\n'
        '    strcat(a, " ");\n'
        '    strcat(a, b);\n'
        '    printf("joined=%s\\n", a);\n'
        '    return 0;\n'
        '}\n',
    output: 'len=5\ncmp=1\njoined=hello world\n',
    pitfalls: <String>[
      '用 == 比较两个字符串比较的是地址，不是内容。',
      'strcat 前目标数组必须有足够空间，否则缓冲区溢出。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 "QFLI" 和 "Forge" 拼成 "QFLI-Forge"。',
        hint: '先 strcpy 再 strcat 中间的 "-"。',
        answer: 'char s[32];\nstrcpy(s, "QFLI");\nstrcat(s, "-");\nstrcat(s, "Forge");',
      ),
    ],
  ),
  ForgeTopic(
    id: 26,
    language: 'c',
    level: 'beginner',
    title: 'C 026：用 scanf 读取输入',
    standard: 'c17',
    concepts: <String>['scanf', 'input.txt', '& 取地址', '返回值'],
    objective: '从标准输入读取整数并计算。',
    prerequisites: <String>['C 004'],
    summary: 'scanf 与 printf 互为镜像。',
    explain:
        '本 App 的运行模型是「先把输入准备好、再一次性跑完」，所以标准输入写在项目根目录的 input.txt 里。scanf 的用法和 printf 反过来：它按格式把读到的值写进变量的地址，所以变量前要加 &。scanf 返回成功读取的项数，可用于判断输入是否足够。',
    input: '17 5\n',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int a, b;\n'
        '    if (scanf("%d %d", &a, &b) != 2) {\n'
        '        printf("need two integers\\n");\n'
        '        return 1;\n'
        '    }\n'
        '    printf("%d + %d = %d\\n", a, b, a + b);\n'
        '    printf("%d * %d = %d\\n", a, b, a * b);\n'
        '    return 0;\n'
        '}\n',
    output: '17 + 5 = 22\n17 * 5 = 85\n',
    pitfalls: <String>[
      '忘记变量前的 & 会写入错误地址，程序可能崩溃。',
      '%d 读整数，读小数要用 %lf 且目标是 double 的地址。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '再读一个整数 c，输出三个数的和。',
        hint: 'scanf 改成 "%d %d %d"，input.txt 补一个数。',
        answer: 'int c;\nscanf("%d %d %d", &a, &b, &c);\nprintf("sum=%d\\n", a + b + c);',
      ),
    ],
  ),
  ForgeTopic(
    id: 27,
    language: 'c',
    level: 'beginner',
    title: 'C 027：getchar 与 putchar',
    standard: 'c17',
    concepts: <String>['getchar', 'putchar', 'EOF', '字符流'],
    objective: '逐字符读写标准输入输出。',
    prerequisites: <String>['C 026'],
    summary: '按字符处理输入，理解 EOF。',
    explain:
        'getchar 每次读一个字符，读到输入末尾返回 EOF（通常是 -1）。putchar 输出一个字符。它们常用来做逐字符统计，比如数一数输入里有多少个字母。用 int 接收 getchar 的返回值才能正确判断 EOF。',
    input: 'hello world\n',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int ch;\n'
        '    int letters = 0;\n'
        '    while ((ch = getchar()) != EOF) {\n'
        '        if ((ch >= \'a\' && ch <= \'z\') || (ch >= \'A\' && ch <= \'Z\')) {\n'
        '            letters++;\n'
        '        }\n'
        '    }\n'
        '    printf("letters=%d\\n", letters);\n'
        '    return 0;\n'
        '}\n',
    output: 'letters=10\n',
    pitfalls: <String>[
      '用 char 接收 getchar 返回值会无法区分 EOF 和有效字符。',
      '把赋值写成 while ((ch = getchar()) != EOF) 才正确。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '统计输入里的空格数量。',
        hint: '在循环里判断 ch == \' \'。',
        answer: 'int spaces = 0;\nwhile ((ch = getchar()) != EOF) if (ch == \' \') spaces++;',
      ),
    ],
  ),
  ForgeTopic(
    id: 28,
    language: 'c',
    level: 'beginner',
    title: 'C 028：const 与 #define',
    standard: 'c17',
    concepts: <String>['const', '#define', '符号常量', '只读变量'],
    objective: '用 const 和宏定义常量，避免魔法数字。',
    prerequisites: <String>['C 002'],
    summary: '给常量起名字，代码更清晰。',
    explain:
        'const 修饰的变量只读，编译器会检查你不能改写它，适合有类型的常量。宏 #define 在预处理阶段做文本替换，没有类型。一般优先用 const，宏多用于包含头文件、条件编译和简单配置。常量名习惯全大写。',
    code: '#include <stdio.h>\n'
        '\n'
        '#define PI 3.14159\n'
        '\n'
        'int main(void) {\n'
        '    const int maxCount = 100;\n'
        '    double r = 2.0;\n'
        '    printf("area=%.4f\\n", PI * r * r);\n'
        '    printf("maxCount=%d\\n", maxCount);\n'
        '    return 0;\n'
        '}\n',
    output: 'area=12.5664\nmaxCount=100\n',
    pitfalls: <String>[
      'const 变量在初始化后赋值会编译错误。',
      '宏定义后不加分号，否则分号会被一起替换进去。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '定义一个 const double 表示折扣率 0.8，并计算 100 元折后价。',
        hint: 'const double discount = 0.8;。',
        answer: 'const double discount = 0.8;\nprintf("%.2f\\n", 100 * discount); // 80.00',
      ),
    ],
  ),
  ForgeTopic(
    id: 29,
    language: 'c',
    level: 'beginner',
    title: 'C 029：注释与代码风格',
    standard: 'c17',
    concepts: <String>['//', '/* */', '命名', '可读性'],
    objective: '用注释解释「为什么」，用命名表达「是什么」。',
    prerequisites: <String>['C 001'],
    summary: '让代码自己会说话，注释补充原因。',
    explain:
        '// 注释到行尾，/* */ 可跨多行。注释应解释意图和原因，而不是重复代码。变量和函数用能表达含义的名字，例如 totalSeconds 而不是 t。统一的缩进（每层 4 个空格）能大幅提升可读性。',
    code: '#include <stdio.h>\n'
        '\n'
        '/* 把秒数换算成「分:秒」格式。\n'
        '   用 -1 表示无效输入，避免返回一个看似合理的 0。 */\n'
        'void printClock(int seconds) {\n'
        '    if (seconds < 0) {\n'
        '        printf("invalid\\n"); // 负秒数没有意义\n'
        '        return;\n'
        '    }\n'
        '    printf("%d:%02d\\n", seconds / 60, seconds % 60);\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    printClock(125);\n'
        '    printClock(-5);\n'
        '    return 0;\n'
        '}\n',
    output: '2:05\ninvalid\n',
    pitfalls: <String>[
      '过期的注释比没有注释更糟，改代码要同步改注释。',
      '嵌套 /* */ 注释不合法，内层 */ 会提前结束外层。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 printClock 增加一行注释说明 %02d 的作用。',
        hint: '%02d 表示至少两位、不足补零。',
        answer: 'printf("%d:%02d\\n", seconds / 60, seconds % 60); // %02d: 秒数补零对齐',
      ),
    ],
  ),
  ForgeTopic(
    id: 30,
    language: 'c',
    level: 'beginner',
    title: 'C 030：用 printf 调试',
    standard: 'c17',
    concepts: <String>['调试', '打印变量', '定位'],
    objective: '用临时打印快速定位逻辑错误。',
    prerequisites: <String>['C 028'],
    summary: '最土也最有效的调试手段。',
    explain:
        '在可疑位置打印变量的值，观察程序实际走的路径和中间结果，是排查逻辑错误最快的办法。打印时带上标签（如 i=、sum=）便于区分。定位后应删除或收敛这些调试打印，不要留在最终代码里。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    int values[] = {4, 9, 2, 7};\n'
        '    int n = 4, max = values[0];\n'
        '    for (int i = 1; i < n; i++) {\n'
        '        printf("i=%d candidate=%d max=%d\\n", i, values[i], max);\n'
        '        if (values[i] > max) max = values[i];\n'
        '    }\n'
        '    printf("final max=%d\\n", max);\n'
        '    return 0;\n'
        '}\n',
    output:
        'i=1 candidate=9 max=4\ni=2 candidate=2 max=9\ni=3 candidate=7 max=9\nfinal max=9\n',
    pitfalls: <String>[
      '调试打印太多会淹没关键信息，聚焦可疑区间。',
      '忘记删除调试打印会污染程序的正常输出。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '在求和循环里加打印，确认每次累加后的 sum。',
        hint: '在 sum += x 后打印 sum。',
        answer: 'sum += x;\nprintf("sum=%d\\n", sum);',
      ),
    ],
  ),
  ForgeTopic(
    id: 31,
    language: 'c',
    level: 'beginner',
    title: 'C 031：编译与链接是怎么回事',
    standard: 'c17',
    concepts: <String>['编译', '链接', '目标文件', '可执行文件'],
    objective: '理解从源码到可执行文件的两大阶段。',
    prerequisites: <String>['C 019'],
    summary: '编译生成目标文件，链接拼成程序。',
    explain:
        '编译器先把每个 .c 文件单独编译成目标文件，这一步只检查单个文件的语法和声明；链接器再把所有目标文件和库拼成可执行文件，这一步才检查函数是否真的存在。所以「找不到某个函数」通常是链接错误，而不是编译错误。App 的桌面后端会自动完成这两步。',
    code: '#include <stdio.h>\n'
        '\n'
        'int helper(void);\n'
        '\n'
        'int main(void) {\n'
        '    printf("helper=%d\\n", helper());\n'
        '    return 0;\n'
        '}\n'
        '\n'
        'int helper(void) { return 42; }\n',
    output: 'helper=42\n',
    pitfalls: <String>[
      '只声明没定义会在链接阶段报 undefined reference。',
      '把函数定义放进头文件并被多个 .c 包含会导致重复定义。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '说出「undefined reference」属于编译阶段还是链接阶段。',
        hint: '它和函数的存在性有关。',
        answer: '链接阶段——编译期只知道声明，链接期才去找定义。',
      ),
    ],
  ),
  ForgeTopic(
    id: 32,
    language: 'c',
    level: 'beginner',
    title: 'C 032：头文件与多文件结构',
    standard: 'c17',
    concepts: <String>['头文件', '声明与定义', '模块化', 'include'],
    objective: '理解头文件放声明、源文件放定义的分工。',
    prerequisites: <String>['C 031'],
    summary: '为什么要把声明和实现分开。',
    explain:
        '多文件项目里，习惯把函数的声明放进 .h 头文件，把定义放进 .c 源文件，其他文件通过 #include "name.h" 使用。头文件用 include guard（#ifndef / #define / #endif）防止被重复包含。本 App 的教程示例是单文件自包含的，这里用注释描述真实项目里的文件划分方式。',
    code: '#include <stdio.h>\n'
        '\n'
        '/* 真实项目会拆成：\n'
        '     mathutils.h  : int add(int, int); int mul(int, int);\n'
        '     mathutils.c  : 两个函数的定义\n'
        '     main.c       : #include "mathutils.h" 后调用\n'
        '   这里把三者合并成单文件，效果一致。 */\n'
        '\n'
        'int add(int a, int b) { return a + b; }\n'
        'int mul(int a, int b) { return a * b; }\n'
        '\n'
        'int main(void) {\n'
        '    printf("add=%d mul=%d\\n", add(20, 22), mul(6, 7));\n'
        '    return 0;\n'
        '}\n',
    output: 'add=42 mul=42\n',
    pitfalls: <String>[
      '头文件里写函数定义被多处包含会重复定义。',
      '缺少 include guard 会导致重复声明甚至递归包含。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '写出 mathutils.h 应当包含的内容。',
        hint: '只要声明，不要定义。',
        answer: '#ifndef MATHUTILS_H\n#define MATHUTILS_H\nint add(int, int);\nint mul(int, int);\n#endif',
      ),
    ],
  ),
  ForgeTopic(
    id: 33,
    language: 'c',
    level: 'beginner',
    title: 'C 033：命令行参数入门',
    standard: 'c17',
    concepts: <String>['argc', 'argv', '程序参数'],
    objective: '理解 main(argc, argv) 如何接收运行参数。',
    prerequisites: <String>['C 031'],
    summary: '程序也能接收启动参数。',
    explain:
        'main 的完整形式是 int main(int argc, char *argv[])。argc 是参数个数（包含程序名），argv 是参数字符串数组，argv[0] 是程序名。本 App 运行时通常没有额外参数，但理解这个签名能看懂很多真实代码。示例用注释说明真实运行时 argv[0] 是程序自身的路径。',
    code: '#include <stdio.h>\n'
        '\n'
        'int main(void) {\n'
        '    /* 真实签名是 int main(int argc, char *argv[])。\n'
        '       运行示例程序时 argc=1，argv[0] 是可执行文件的路径。\n'
        '       这里用固定值演示参数计数与遍历的思路。 */\n'
        '    int argc = 3;\n'
        '    char *argv[] = {"program", "--verbose", "input.txt"};\n'
        '    printf("argc=%d\\n", argc);\n'
        '    for (int i = 0; i < argc; i++) {\n'
        '        printf("argv[%d]=%s\\n", i, argv[i]);\n'
        '    }\n'
        '    return 0;\n'
        '}\n',
    output: 'argc=3\nargv[0]=program\nargv[1]=--verbose\nargv[2]=input.txt\n',
    pitfalls: <String>[
      'argv[0] 是程序名，真正的用户参数从 argv[1] 开始。',
      '读取 argv[i] 前要先确认 i < argc。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '说明为什么遍历 argv 前要检查 i < argc。',
        hint: '越界访问 argv 会读到无效指针。',
        answer: 'argv 只有 argc 个有效元素，i >= argc 时是越界访问。',
      ),
    ],
  ),
  ForgeTopic(
    id: 34,
    language: 'c',
    level: 'beginner',
    title: 'C 034：阶段小结——温度统计',
    standard: 'c17',
    concepts: <String>['综合', '数组', '循环', '函数', '条件'],
    objective: '把变量、数组、循环、函数、条件组合成一个小程序。',
    prerequisites: <String>['C 023', 'C 029'],
    summary: '用前面所学完成一个温度统计器。',
    explain:
        '这个小结把数组、遍历、函数拆分、条件判断串起来：读入一组温度，算出平均值，统计高于平均的天数。把「求平均」和「计数」拆成独立函数，是保持 main 清爽的好习惯。下面的示例把输入写死在数组里，真实程序会用 scanf 从 input.txt 读取。',
    code: '#include <stdio.h>\n'
        '\n'
        'double average(const int *values, int n) {\n'
        '    int sum = 0;\n'
        '    for (int i = 0; i < n; i++) sum += values[i];\n'
        '    return (double)sum / n;\n'
        '}\n'
        '\n'
        'int countAbove(const int *values, int n, double threshold) {\n'
        '    int count = 0;\n'
        '    for (int i = 0; i < n; i++) {\n'
        '        if (values[i] > threshold) count++;\n'
        '    }\n'
        '    return count;\n'
        '}\n'
        '\n'
        'int main(void) {\n'
        '    int temps[7] = {21, 24, 19, 26, 23, 25, 20};\n'
        '    double avg = average(temps, 7);\n'
        '    printf("avg=%.2f\\n", avg);\n'
        '    printf("above=%d\\n", countAbove(temps, 7, avg));\n'
        '    return 0;\n'
        '}\n',
    output: 'avg=22.57\nabove=4\n',
    pitfalls: <String>[
      'average 里若用整数除法会得到错误的平均值。',
      '阈值和数组元素比较时注意是「高于」还是「高于等于」。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '再统计低于平均温度的天数。',
        hint: '仿照 countAbove 写 countBelow，判断改为 <。',
        answer: 'int countBelow(const int *v, int n, double t) {\n    int c = 0;\n    for (int i = 0; i < n; i++) if (v[i] < t) c++;\n    return c;\n}',
      ),
    ],
  ),
];
