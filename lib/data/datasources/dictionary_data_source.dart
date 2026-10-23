import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/vocab.dart';

// --- CURATED DETAILS USED TO ENRICH MATCHING DICTIONARY ENTRIES ---

Vocab _w(
  int level,
  String hanzi,
  String pinyin,
  String meaning,
  String emoji, [
  String ex = '',
  String exPinyin = '',
  String exMeaning = '',
]) => Vocab(
  id: hanzi,
  hanzi: hanzi,
  pinyin: pinyin,
  meaning: meaning,
  emoji: emoji,
  level: level,
  example: ex,
  examplePinyin: exPinyin,
  exampleMeaning: exMeaning,
);

final List<Vocab> _sampleWords = [
  // HSK 1
  _w(
    1,
    '你好',
    'nǐ hǎo',
    'Xin chào',
    '😊',
    '你好，我叫小明。',
    'nǐ hǎo, wǒ jiào Xiǎo Míng.',
    'Xin chào, tôi tên là Tiểu Minh.',
  ),
  _w(
    1,
    '谢谢',
    'xièxie',
    'Cảm ơn',
    '🙏',
    '谢谢你的帮助。',
    'xièxie nǐ de bāngzhù.',
    'Cảm ơn sự giúp đỡ của bạn.',
  ),
  _w(
    1,
    '再见',
    'zàijiàn',
    'Tạm biệt',
    '👋',
    '明天见，再见！',
    'míngtiān jiàn, zàijiàn!',
    'Mai gặp nhé, tạm biệt!',
  ),
  _w(
    1,
    '对不起',
    'duìbuqǐ',
    'Xin lỗi',
    '😔',
    '对不起，我迟到了。',
    'duìbuqǐ, wǒ chídào le.',
    'Xin lỗi, tôi đến muộn.',
  ),
  _w(
    1,
    '没关系',
    'méi guānxi',
    'Không sao đâu',
    '🤝',
    '没关系，别担心。',
    'méi guānxi, bié dānxīn.',
    'Không sao đâu, đừng lo.',
  ),
  _w(
    1,
    '学习',
    'xuéxí',
    'Học tập',
    '📚',
    '我每天学习汉语。',
    'wǒ měitiān xuéxí Hànyǔ.',
    'Mỗi ngày tôi học tiếng Trung.',
  ),
  _w(
    1,
    '朋友',
    'péngyou',
    'Bạn bè',
    '🧑‍🤝‍🧑',
    '他是我的好朋友。',
    'tā shì wǒ de hǎo péngyou.',
    'Anh ấy là bạn tốt của tôi.',
  ),
  _w(
    1,
    '电脑',
    'diànnǎo',
    'Máy tính',
    '💻',
    '我的电脑坏了。',
    'wǒ de diànnǎo huài le.',
    'Máy tính của tôi hỏng rồi.',
  ),
  _w(
    1,
    '手机',
    'shǒujī',
    'Điện thoại',
    '📱',
    '我的手机在桌子上。',
    'wǒ de shǒujī zài zhuōzi shàng.',
    'Điện thoại của tôi ở trên bàn.',
  ),
  _w(
    1,
    '吃饭',
    'chī fàn',
    'Ăn cơm',
    '🍚',
    '我们去吃饭吧。',
    'wǒmen qù chī fàn ba.',
    'Chúng ta đi ăn cơm nhé.',
  ),
  _w(
    1,
    '爸爸',
    'bàba',
    'Bố',
    '👨',
    '我爸爸是老师。',
    'wǒ bàba shì lǎoshī.',
    'Bố tôi là giáo viên.',
  ),
  _w(
    1,
    '妈妈',
    'māma',
    'Mẹ',
    '👩',
    '妈妈做的饭很好吃。',
    'māma zuò de fàn hěn hǎochī.',
    'Cơm mẹ nấu rất ngon.',
  ),
  _w(
    1,
    '哥哥',
    'gēge',
    'Anh trai',
    '👦',
    '我哥哥比我高。',
    'wǒ gēge bǐ wǒ gāo.',
    'Anh trai tôi cao hơn tôi.',
  ),
  _w(
    1,
    '妹妹',
    'mèimei',
    'Em gái',
    '👧',
    '我妹妹很可爱。',
    "wǒ mèimei hěn kě'ài.",
    'Em gái tôi rất đáng yêu.',
  ),
  _w(1, '水', 'shuǐ', 'Nước', '💧'),
  _w(1, '喝', 'hē', 'Uống', '🥤'),
  _w(1, '爱', 'ài', 'Yêu', '❤️'),
  // HSK 2
  _w(2, '工作', 'gōngzuò', 'Công việc', '💼'),
  _w(2, '旅游', 'lǚyóu', 'Du lịch', '✈️'),
  _w(2, '便宜', 'piányi', 'Rẻ', '💰'),
  _w(2, '面包', 'miànbāo', 'Bánh mì', '🍞'),
  _w(2, '健康', 'jiànkāng', 'Sức khỏe', '💪'),
  _w(2, '帮助', 'bāngzhù', 'Giúp đỡ', '🤝'),
  // HSK 3
  _w(3, '环境', 'huánjìng', 'Môi trường', '🌳'),
  _w(3, '经验', 'jīngyàn', 'Kinh nghiệm', '🎓'),
  _w(3, '担心', 'dānxīn', 'Lo lắng', '😟'),
  _w(3, '重要', 'zhòngyào', 'Quan trọng', '⭐'),
  _w(3, '习惯', 'xíguàn', 'Thói quen', '🔁'),
  _w(3, '注意', 'zhùyì', 'Chú ý', '⚠️'),
  // HSK 4
  _w(4, '文化', 'wénhuà', 'Văn hóa', '🏮'),
  _w(4, '成功', 'chénggōng', 'Thành công', '🏆'),
  _w(4, '影响', 'yǐngxiǎng', 'Ảnh hưởng', '🌊'),
  _w(4, '竞争', 'jìngzhēng', 'Cạnh tranh', '🥇'),
  _w(4, '报告', 'bàogào', 'Báo cáo', '📄'),
  _w(4, '解决', 'jiějué', 'Giải quyết', '🔧'),
  // HSK 5
  _w(5, '传统', 'chuántǒng', 'Truyền thống', '🎎'),
  _w(5, '挑战', 'tiǎozhàn', 'Thách thức', '🧗'),
  _w(5, '观念', 'guānniàn', 'Quan niệm', '💭'),
  _w(5, '趋势', 'qūshì', 'Xu hướng', '📈'),
  _w(5, '维护', 'wéihù', 'Bảo vệ, duy trì', '🛡️'),
  _w(5, '创造', 'chuàngzào', 'Sáng tạo', '🎨'),
  // HSK 6
  _w(6, '战略', 'zhànlüè', 'Chiến lược', '♟️'),
  _w(6, '繁荣', 'fánróng', 'Thịnh vượng', '🌆'),
  _w(6, '谨慎', 'jǐnshèn', 'Thận trọng', '🧐'),
  _w(6, '弥补', 'míbǔ', 'Bù đắp', '🩹'),
  _w(6, '遵循', 'zūnxún', 'Tuân theo', '📏'),
  _w(6, '妥协', 'tuǒxié', 'Thỏa hiệp', '🕊️'),
  // HSK 7
  _w(7, '辩证', 'biànzhèng', 'Biện chứng', '⚖️'),
  _w(7, '范畴', 'fànchóu', 'Phạm trù', '🗂️'),
  _w(7, '渗透', 'shèntòu', 'Thấm, thâm nhập', '💧'),
  _w(7, '颠覆', 'diānfù', 'Lật đổ', '🔄'),
  _w(7, '契机', 'qìjī', 'Thời cơ then chốt', '🔑'),
  _w(7, '凝聚', 'níngjù', 'Ngưng tụ, gắn kết', '🧲'),
  // HSK 8
  _w(8, '蕴含', 'yùnhán', 'Hàm chứa', '🎁'),
  _w(8, '严峻', 'yánjùn', 'Nghiêm trọng, khắc nghiệt', '🌪️'),
  _w(8, '变迁', 'biànqiān', 'Biến đổi theo thời gian', '⏳'),
  _w(8, '深邃', 'shēnsuì', 'Sâu sắc, thăm thẳm', '🌌'),
  _w(8, '倡导', 'chàngdǎo', 'Đề xướng', '📢'),
  _w(8, '衍生', 'yǎnshēng', 'Phái sinh', '🌿'),
  // HSK 9
  _w(9, '底蕴', 'dǐyùn', 'Nền tảng sâu dày', '🏛️'),
  _w(9, '钻研', 'zuānyán', 'Nghiên cứu sâu', '🔬'),
  _w(9, '魄力', 'pòlì', 'Khí phách, bản lĩnh', '🦁'),
  _w(9, '恪守', 'kèshǒu', 'Tuân thủ nghiêm ngặt', '📜'),
  _w(9, '洞察', 'dòngchá', 'Thấu hiểu, nhìn thấu', '👁️'),
  _w(9, '斟酌', 'zhēnzhuó', 'Cân nhắc kỹ', '🤔'),
];

late final List<Vocab> builtIn;

int? _dictionaryLevel(List<dynamic> tags, String prefix) {
  for (final tag in tags.cast<String>()) {
    if (tag.startsWith('$prefix-')) {
      return int.tryParse(tag.substring(prefix.length + 1));
    }
  }
  return null;
}

Future<void> loadDictionary() async {
  final records = jsonDecode(
    await rootBundle.loadString(AppConstants.dictionaryAsset),
  ) as List<dynamic>;
  final samples = {for (final word in _sampleWords) word.hanzi: word};
  builtIn = [
    for (final raw in records)
      _dictionaryWord(raw as Map<String, dynamic>, samples),
  ];
}

Vocab _dictionaryWord(Map<String, dynamic> record, Map<String, Vocab> samples) {
  final tags = record['level'] as List<dynamic>;
  final level =
      _dictionaryLevel(tags, 'newest') ??
      _dictionaryLevel(tags, 'new') ??
      _dictionaryLevel(tags, 'old');
  if (level == null) {
    throw FormatException(
      'Dictionary entry has no HSK level: ${record['simplified']}',
    );
  }

  final forms = (record['forms'] as List<dynamic>).cast<Map<String, dynamic>>();
  final pinyin = <String>{};
  final meanings = <String>{};
  final traditional = <String>{};
  for (final form in forms) {
    final transcription = form['transcriptions'] as Map<String, dynamic>;
    final pronunciation = transcription['pinyin'] as String?;
    if (pronunciation != null && pronunciation.trim().isNotEmpty) {
      pinyin.add(pronunciation);
    }
    final spelling = form['traditional'] as String?;
    if (spelling != null && spelling.trim().isNotEmpty) {
      traditional.add(spelling);
    }
    for (final meaning
        in (form['meanings_vi'] as List<dynamic>).cast<String>()) {
      if (meaning.trim().isNotEmpty) meanings.add(meaning.trim());
    }
  }

  final hanzi = record['simplified'] as String;
  final sample = samples[hanzi];
  return Vocab(
    id: hanzi,
    hanzi: hanzi,
    traditional: traditional.join(' / '),
    pinyin: pinyin.join(' / '),
    meaning: meanings.join('; '),
    level: level,
    emoji: sample?.emoji ?? '📝',
    example: sample?.example ?? '',
    examplePinyin: sample?.examplePinyin ?? '',
    exampleMeaning: sample?.exampleMeaning ?? '',
  );
}
