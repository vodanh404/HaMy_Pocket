class ConversationTopic {
  const ConversationTopic({
    required this.title,
    required this.description,
    required this.icon,
    required this.openingMessage,
  });

  final String title;
  final String description;
  final String openingMessage;
  final String icon;

  String get systemPrompt =>
      'Bạn là gia sư tiếng Trung thân thiện, đang luyện hội thoại chủ đề "$title" '
      'với người học Việt Nam ở trình độ sơ cấp. Chỉ tập trung vào chủ đề này. '
      'Mỗi lượt trả lời ngắn gọn, dùng tiếng Trung giản thể tự nhiên và dễ hiểu. '
      'Luôn trình bày đúng ba dòng: "中文: [câu tiếng Trung]", '
      '"拼音: [pinyin có dấu thanh]", "Tiếng Việt: [nghĩa tiếng Việt]". '
      'Nếu người học viết sai tiếng Trung, hãy sửa nhẹ nhàng bằng một câu ngắn '
      'rồi tiếp tục hội thoại, không chê bai. Nếu họ trả lời bằng tiếng Việt, '
      'gợi ý cách nói tiếng Trung trước rồi hỏi tiếp. Mỗi lượt chỉ hỏi một câu.';
}

const conversationTopics = [
  ConversationTopic(
    title: 'Giới thiệu bản thân',
    description: 'Tên, quê quán, sở thích và công việc',
    icon: '👋',
    openingMessage:
        '中文: 你好！你叫什么名字？\n'
        '拼音: Nǐ hǎo! Nǐ jiào shénme míngzi?\n'
        'Tiếng Việt: Xin chào! Bạn tên là gì?',
  ),
  ConversationTopic(
    title: 'Gọi món ở nhà hàng',
    description: 'Chọn món ăn và gọi đồ uống',
    icon: '🍜',
    openingMessage:
        '中文: 欢迎光临！你想吃什么？\n'
        '拼音: Huānyíng guānglín! Nǐ xiǎng chī shénme?\n'
        'Tiếng Việt: Chào mừng bạn! Bạn muốn ăn gì?',
  ),
  ConversationTopic(
    title: 'Du lịch và hỏi đường',
    description: 'Hỏi đường, phương tiện và địa điểm',
    icon: '🧭',
    openingMessage:
        '中文: 你好，请问你想去哪儿？\n'
        '拼音: Nǐ hǎo, qǐngwèn nǐ xiǎng qù nǎr?\n'
        'Tiếng Việt: Xin chào, cho hỏi bạn muốn đi đâu?',
  ),
  ConversationTopic(
    title: 'Mua sắm',
    description: 'Hỏi giá, màu sắc và kích cỡ',
    icon: '🛍️',
    openingMessage:
        '中文: 你好！你想买什么？\n'
        '拼音: Nǐ hǎo! Nǐ xiǎng mǎi shénme?\n'
        'Tiếng Việt: Xin chào! Bạn muốn mua gì?',
  ),
  ConversationTopic(
    title: 'Sinh hoạt hằng ngày',
    description: 'Thói quen, thời gian và kế hoạch',
    icon: '☀️',
    openingMessage:
        '中文: 你今天几点起床？\n'
        '拼音: Nǐ jīntiān jǐ diǎn qǐchuáng?\n'
        'Tiếng Việt: Hôm nay bạn thức dậy lúc mấy giờ?',
  ),
];
