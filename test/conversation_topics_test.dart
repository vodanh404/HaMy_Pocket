import 'package:flutter_test/flutter_test.dart';
import 'package:hamy_poket/features/speaking/conversation_topics.dart';

void main() {
  test('conversation topics provide a Chinese opener and learner guidance', () {
    expect(conversationTopics, hasLength(5));

    for (final topic in conversationTopics) {
      expect(topic.title, isNotEmpty);
      expect(topic.description, isNotEmpty);
      expect(topic.systemPrompt, contains(topic.title));
      expect(topic.systemPrompt, contains('拼音'));
      expect(topic.openingMessage.split('\n'), hasLength(3));
      expect(topic.openingMessage, contains('中文:'));
      expect(topic.openingMessage, contains('Tiếng Việt:'));
    }
  });
}
