import 'forge_topic.dart';

/// C++ advanced track, part 3 of 4: topics 90..96.
const List<ForgeTopic> cppTopicsAdvanced3 = <ForgeTopic>[
  ForgeTopic(
    id: 90,
    language: 'cpp',
    level: 'advanced',
    title: 'std::thread 与 join',
    summary: '用 std::thread 启动并发任务，用 join 等待其结束。',
    concepts: <String>['std::thread', 'join', '并发', '确定性输出'],
    objective: '启动线程处理独立任务并正确 join。',
    prerequisites: <String>['三路比较运算符 <=>'],
    standard: 'c++20',
    explain:
        'std::thread 构造时启动一个新线程执行可调用对象。'
        '主线程必须 join（等待）或 detach 线程，否则析构时若仍可 join 会 terminate。'
        '本课让每个线程把结果写入自己的槽位，最后主线程汇总，从而输出确定。',
    code: '#include <iostream>\n#include <thread>\n#include <vector>\n\n'
        'int main() {\n'
        '    const int n = 4;\n'
        '    std::vector<int> results(n, 0);\n'
        '    std::vector<std::thread> workers;\n'
        '    for (int i = 0; i < n; ++i) {\n'
        '        workers.emplace_back([i, &results] { results[i] = (i + 1) * (i + 1); });\n'
        '    }\n'
        '    for (auto& t : workers) t.join();\n'
        '    int sum = 0;\n'
        '    for (int x : results) sum += x;\n'
        '    std::cout << "sum=" << sum << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'sum=30\n',
    pitfalls: <String>[
      '忘记 join/detach 会在析构时 terminate。',
      '多个线程写同一变量要同步，否则数据竞争是未定义行为。',
      '本课用“每个线程写自己的下标”避免竞争，得到确定结果。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 n 改成 5，观察 sum。',
        hint: 'sum = 1²+2²+3²+4²+5²。',
        answer: 'sum=55。',
      ),
    ],
  ),
  ForgeTopic(
    id: 91,
    language: 'cpp',
    level: 'advanced',
    title: '互斥量与条件变量',
    summary: '用 mutex 保护共享数据，用 condition_variable 协调线程节奏。',
    concepts: <String>['mutex', 'lock_guard', 'condition_variable', '生产者消费者'],
    objective: '用锁保护共享计数器，用条件变量等待条件成立。',
    prerequisites: <String>['std::thread 与 join'],
    standard: 'c++20',
    explain:
        'std::mutex 保证同一时刻只有一个线程进入临界区；lock_guard/unique_lock 用 RAII '
        '自动加解锁。condition_variable 让线程在条件不满足时休眠、条件满足时被唤醒，'
        '是生产者-消费者模型的基础。',
    code: '#include <condition_variable>\n#include <iostream>\n#include <mutex>\n'
        '#include <queue>\n#include <thread>\n\n'
        'int main() {\n'
        '    std::mutex m;\n'
        '    std::condition_variable cv;\n'
        '    std::queue<int> q;\n'
        '    bool done = false;\n'
        '    int total = 0;\n\n'
        '    std::thread producer([&] {\n'
        '        for (int i = 1; i <= 5; ++i) {\n'
        '            {\n'
        '                std::lock_guard<std::mutex> lock(m);\n'
        '                q.push(i);\n'
        '            }\n'
        '            cv.notify_one();\n'
        '        }\n'
        '        {\n'
        '            std::lock_guard<std::mutex> lock(m);\n'
        '            done = true;\n'
        '        }\n'
        '        cv.notify_one();\n'
        '    });\n\n'
        '    std::thread consumer([&] {\n'
        '        while (true) {\n'
        '            std::unique_lock<std::mutex> lock(m);\n'
        '            cv.wait(lock, [&] { return !q.empty() || done; });\n'
        '            if (q.empty() && done) break;\n'
        '            total += q.front();\n'
        '            q.pop();\n'
        '        }\n'
        '    });\n\n'
        '    producer.join();\n'
        '    consumer.join();\n'
        '    std::cout << "total=" << total << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'total=15\n',
    pitfalls: <String>[
      '条件变量的 wait 必须带谓词，避免虚假唤醒。',
      'notify 时不必持锁（可以持，但通常在临界区外）。',
      '忘记在 done 后也 notify 会让消费者永久等待。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把生产者的范围改成 1..10，观察 total。',
        hint: 'sum(1..10)=55。',
        answer: 'total=55。',
      ),
    ],
  ),
  ForgeTopic(
    id: 92,
    language: 'cpp',
    level: 'advanced',
    title: '原子操作与内存序',
    summary: '用 std::atomic 做无数据竞争的计数，理解常见内存序。',
    concepts: <String>['std::atomic', 'memory_order', '无锁', '数据竞争'],
    objective: '用 atomic 实现线程安全计数并解释 relaxed 的用途。',
    prerequisites: <String>['互斥量与条件变量'],
    standard: 'c++20',
    explain:
        'std::atomic<T> 提供原子读写，避免数据竞争。fetch_add 是原子的读改写。'
        'memory_order_relaxed 只保证原子性、不规定顺序，适合独立计数；'
        '默认 seq_cst 最强也最慢。正确选择内存序需要理解 happens-before。',
    code: '#include <atomic>\n#include <iostream>\n#include <thread>\n#include <vector>\n\n'
        'int main() {\n'
        '    std::atomic<int> counter{0};\n'
        '    std::vector<std::thread> workers;\n'
        '    for (int t = 0; t < 4; ++t) {\n'
        '        workers.emplace_back([&counter] {\n'
        '            for (int i = 0; i < 1000; ++i)\n'
        '                counter.fetch_add(1, std::memory_order_relaxed);\n'
        '        });\n'
        '    }\n'
        '    for (auto& w : workers) w.join();\n'
        '    std::cout << "counter=" << counter.load() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'counter=4000\n',
    pitfalls: <String>[
      'atomic 只保护它自己的读写，组合操作仍需锁或 CAS。',
      'relaxed 不提供同步，别用它保护有依赖关系的数据。',
      '用普通 int 让多线程自增是数据竞争，结果不可预期。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把 relaxed 改成 memory_order_seq_cst，观察结果是否仍为 4000。',
        hint: '更强的内存序同样保证正确计数，只是更慢。',
        answer: '结果仍为 4000。',
      ),
    ],
  ),
  ForgeTopic(
    id: 93,
    language: 'cpp',
    level: 'advanced',
    title: '内存模型与数据竞争',
    summary: '理解 C++ 内存模型中的 happens-before 与数据竞争定义。',
    concepts: <String>['内存模型', 'happens-before', '数据竞争', '同步'],
    objective: '解释什么构成数据竞争，以及如何用同步建立顺序。',
    prerequisites: <String>['原子操作与内存序'],
    standard: 'c++20',
    explain:
        '只要两个线程并发访问同一内存、至少一个是写、且没有同步建立 happens-before，'
        '就是数据竞争，属于未定义行为。锁、原子、join 都能建立 happens-before。'
        '本课用累加并 join 的方式演示“有顺序则结果确定”。',
    code: '#include <iostream>\n#include <thread>\n\n'
        'int main() {\n'
        '    int data = 0;\n'
        '    std::thread writer([&data] { data = 42; });\n'
        '    writer.join();  // join 建立 happens-before：写发生在读之前\n'
        '    std::cout << "data=" << data << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'data=42\n',
    pitfalls: <String>[
      '没有同步的并发读写是未定义行为，可能“看起来正常”却出错。',
      'join 保证线程的写对 join 之后的读可见。',
      'volatile 不是同步手段。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '去掉 join 直接读 data，说明为什么危险。',
        hint: '线程可能尚未写完就读，且无 happens-before。',
        answer: '构成数据竞争，结果不可预期，且可能崩溃。',
      ),
    ],
  ),
  ForgeTopic(
    id: 94,
    language: 'cpp',
    level: 'advanced',
    title: '异常安全保证',
    summary: '区分基本/强/不抛异常保证，用 RAII 与 copy-and-swap 实现强保证。',
    concepts: <String>['异常安全', '基本保证', '强保证', 'copy-and-swap'],
    objective: '用 copy-and-swap 让赋值具备强异常安全。',
    prerequisites: <String>['RAII 与作用域守卫'],
    standard: 'c++20',
    explain:
        '异常安全分三级：不抛异常（noexcept）、强保证（失败则回滚到原状态）、'
        '基本保证（无泄漏但状态可能改变）。copy-and-swap 先做出副本，'
        '成功后再原子地交换，从而得到强保证。',
    code: '#include <iostream>\n#include <string>\n#include <utility>\n\n'
        'class Config {\n'
        'public:\n'
        '    explicit Config(std::string name) : name_(std::move(name)) {}\n'
        '    Config& operator=(Config other) {  // 传值：先拷贝\n'
        '        swap(other);                   // 交换：不抛\n'
        '        return *this;\n'
        '    }\n'
        '    void swap(Config& other) noexcept { std::swap(name_, other.name_); }\n'
        '    const std::string& name() const { return name_; }\n'
        'private:\n'
        '    std::string name_;\n'
        '};\n\n'
        'int main() {\n'
        '    Config a("first");\n'
        '    Config b("second");\n'
        '    a = b;\n'
        '    std::cout << a.name() << " " << b.name() << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'second second\n',
    pitfalls: <String>[
      'copy-and-swap 的形参按值接收，依赖拷贝构造的成功。',
      'swap 要标 noexcept，否则强保证打折扣。',
      '所有资源都应交给 RAII 对象，才能避免泄漏。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 Config 加一个 noexcept 的移动构造。',
        hint: 'Config(Config&&) noexcept = default;',
        answer: '移动被标记 noexcept 后容器扩容会优先移动。',
      ),
    ],
  ),
  ForgeTopic(
    id: 95,
    language: 'cpp',
    level: 'advanced',
    title: 'noexcept 与移动特征',
    summary: '用 noexcept 表达不抛保证，影响容器是否优先移动元素。',
    concepts: <String>['noexcept', 'move_if_noexcept', '类型特征', '扩容'],
    objective: '解释 noexcept 如何影响 vector 扩容时的拷贝/移动选择。',
    prerequisites: <String>['异常安全保证'],
    standard: 'c++20',
    explain:
        'vector 扩容需要把旧元素搬到新内存。若元素的移动构造是 noexcept，'
        '就用移动；否则为强异常安全会退回拷贝（move_if_noexcept）。'
        '给移动操作标 noexcept 能让容器扩容更高效。',
    code: '#include <iostream>\n#include <type_traits>\n#include <utility>\n\n'
        'struct Safe {\n'
        '    Safe() = default;\n'
        '    Safe(Safe&&) noexcept {}\n'
        '};\n'
        'struct Unsafe {\n'
        '    Unsafe() = default;\n'
        '    Unsafe(Unsafe&&) {}  // 未标 noexcept\n'
        '};\n\n'
        'int main() {\n'
        '    std::cout << std::is_nothrow_move_constructible_v<Safe> << "\\n";\n'
        '    std::cout << std::is_nothrow_move_constructible_v<Unsafe> << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: '1\n0\n',
    pitfalls: <String>[
      '析构函数默认是 noexcept 的，不要在里面抛异常。',
      'noexcept 一旦承诺，违反会直接 terminate。',
      '移动构造/赋值/swap 都应尽量 noexcept。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '给 Unsafe 的移动构造加上 noexcept，观察输出。',
        hint: '加 noexcept 后特征变为 1。',
        answer: 'is_nothrow_move_constructible_v<Unsafe> 变为 1。',
      ),
    ],
  ),
  ForgeTopic(
    id: 96,
    language: 'cpp',
    level: 'advanced',
    title: '基准测试与性能测量',
    summary: '用 std::chrono 测量代码耗时，建立可比较的基准。',
    concepts: <String>['chrono', '基准测试', 'steady_clock', '测量'],
    objective: '用 steady_clock 测量一段计算的耗时并打印。',
    prerequisites: <String>['noexcept 与移动特征'],
    standard: 'c++20',
    explain:
        '性能优化前先测量。std::chrono::steady_clock 是单调时钟，适合测耗时。'
        '测量应重复多次、注意编译器优化（用 volatile 或累计结果避免被优化掉）。'
        '本课测一段求和循环的耗时，输出只断言“大于等于 0”，避免依赖机器速度。',
    code: '#include <chrono>\n#include <cstdint>\n#include <iostream>\n\n'
        'int main() {\n'
        '    using clock = std::chrono::steady_clock;\n'
        '    const auto start = clock::now();\n'
        '    std::uint64_t sum = 0;\n'
        '    for (int i = 0; i < 1000000; ++i) sum += static_cast<std::uint64_t>(i);\n'
        '    const auto end = clock::now();\n'
        '    const auto micros =\n'
        '        std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();\n'
        '    std::cout << "sum=" << sum << "\\n";\n'
        '    std::cout << "measured=" << (micros >= 0) << "\\n";\n'
        '    return 0;\n'
        '}\n',
    output: 'sum=499999500000\nmeasured=1\n',
    pitfalls: <String>[
      '高精度计时用 steady_clock，不要用 system_clock（可能被调整）。',
      '不要把耗时数值写进断言，机器不同结果不同。',
      '编译器可能优化掉无用的计算，累加结果要用起来。',
    ],
    tasks: <ForgeTask>[
      ForgeTask(
        prompt: '把循环次数改成 2000000，观察 sum 与测量结果。',
        hint: 'sum(0..1999999)。',
        answer: 'sum 相应增大，measured=1 保持成立。',
      ),
    ],
  ),
];
