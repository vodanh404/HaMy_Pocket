import 'package:flutter/material.dart';

import '../../services/ai/qwen_chat_service.dart';
import 'conversation_chat_screen.dart';
import 'conversation_topics.dart';

class ConversationTopicsScreen extends StatefulWidget {
  const ConversationTopicsScreen({super.key});

  @override
  State<ConversationTopicsScreen> createState() =>
      _ConversationTopicsScreenState();
}

class _ConversationTopicsScreenState extends State<ConversationTopicsScreen> {
  final QwenChatService _qwen = QwenChatService.instance;
  String? _openingTopic;
  bool? _modelDownloaded;

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  Future<void> _checkModel() async {
    final downloaded = await _qwen.isModelDownloaded;
    if (mounted) setState(() => _modelDownloaded = downloaded);
  }

  Future<void> _openTopic(ConversationTopic topic) async {
    setState(() => _openingTopic = topic.title);
    try {
      await _qwen.ensureModelReady();
      if (!mounted) return;
      setState(() => _modelDownloaded = true);
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ConversationChatScreen(topic: topic),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không khởi động được mô hình Qwen: $error')),
      );
      _checkModel();
    } finally {
      if (mounted) setState(() => _openingTopic = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hội thoại theo chủ đề')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qwen2.5-0.5B-Instruct',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                ValueListenableBuilder<String?>(
                  valueListenable: _qwen.downloadStatus,
                  builder: (context, status, _) => Text(
                    _openingTopic != null
                        ? (status ?? 'Đang khởi động mô hình...')
                        : _modelDownloaded == true
                        ? 'Đã tải mô hình về thiết bị. Hội thoại AI chạy ngoại tuyến.'
                        : 'Tải mô hình GGUF Q4_K_M (~491 MB) lần đầu. '
                              'Sau đó có thể chat ngoại tuyến.',
                  ),
                ),
                ValueListenableBuilder<double?>(
                  valueListenable: _qwen.downloadProgress,
                  builder: (context, progress, _) =>
                      progress == null || _openingTopic == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(value: progress),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final topic in conversationTopics)
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              enabled: _openingTopic == null,
              leading: Text(topic.icon, style: const TextStyle(fontSize: 28)),
              title: Text(topic.title),
              subtitle: Text(topic.description),
              trailing: _openingTopic == topic.title
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () => _openTopic(topic),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Luyện nói dùng nhận dạng tiếng Trung của hệ điều hành; dịch vụ nhận '
          'dạng có thể cần mạng. Chỉ phần văn bản sau khi nhận dạng được gửi '
          'đến mô hình Qwen chạy trên thiết bị.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
