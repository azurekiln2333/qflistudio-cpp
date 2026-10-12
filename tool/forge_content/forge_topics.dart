import 'c_topics_adv_a.dart';
import 'c_topics_adv_b.dart';
import 'c_topics_adv_c.dart';
import 'c_topics_beginner.dart';
import 'c_topics_intermediate.dart';
import 'cpp_topics_advanced1.dart';
import 'cpp_topics_advanced2.dart';
import 'cpp_topics_advanced3.dart';
import 'cpp_topics_advanced4.dart';
import 'cpp_topics_beginner1.dart';
import 'cpp_topics_beginner2.dart';
import 'cpp_topics_beginner3.dart';
import 'cpp_topics_beginner4.dart';
import 'cpp_topics_intermediate1.dart';
import 'cpp_topics_intermediate2.dart';
import 'cpp_topics_intermediate3.dart';
import 'cpp_topics_intermediate4.dart';
import 'cpp_topics_intermediate5.dart';
import 'cpp_topics_intermediate6.dart';
import 'forge_topic.dart';

/// Authored C track (100 topics), owned by the C worker.
List<ForgeTopic> get cForgeTopics => <ForgeTopic>[
  ...cTopicsBeginner,
  ...cTopicsIntermediate,
  ...cTopicsAdvA,
  ...cTopicsAdvB,
  ...cTopicsAdvC,
];

/// Authored C++ track (100 topics), owned by the C++ worker.
List<ForgeTopic> get cppForgeTopics => <ForgeTopic>[
  ...cppTopicsBeginner1,
  ...cppTopicsBeginner2,
  ...cppTopicsBeginner3,
  ...cppTopicsBeginner4,
  ...cppTopicsIntermediate1,
  ...cppTopicsIntermediate2,
  ...cppTopicsIntermediate3,
  ...cppTopicsIntermediate4,
  ...cppTopicsIntermediate5,
  ...cppTopicsIntermediate6,
  ...cppTopicsAdvanced1,
  ...cppTopicsAdvanced2,
  ...cppTopicsAdvanced3,
  ...cppTopicsAdvanced4,
];

/// The full authored C + C++ curriculum consumed by the generator/verifier.
List<ForgeTopic> get forgeTopics => <ForgeTopic>[
  ...cForgeTopics,
  ...cppForgeTopics,
];
