import 'package:flutter/material.dart';

import 'conversation_topics_screen.dart';
import 'tone_practice_screen.dart';

class SpeakingScreen extends StatelessWidget {
  const SpeakingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Luyện nói')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Luyện nói tiếng Trung',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Luyện thanh điệu hoặc thực hành hội thoại với AI theo chủ đề.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.graphic_eq,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Luyện thanh điệu',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nghe từng thanh, ghi âm tối đa 6 giây và nhận phản hồi theo đường cao độ.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const TonePracticeScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.mic),
                  label: const Text('Bắt đầu luyện'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Luyện nói và chat theo chủ đề',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thực hành giới thiệu bản thân, gọi món, du lịch, mua sắm '
                  'và sinh hoạt hằng ngày với Qwen chạy trên thiết bị.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ConversationTopicsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.chat),
                  label: const Text('Chọn chủ đề'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.record_voice_over),
            title: Text('Giọng đọc mẫu Sherpa ONNX'),
            subtitle: Text(
              'Chọn một trong ba speaker tiếng Phổ thông tại Cài đặt. '
              'Mô hình được tải một lần và dùng ngoại tuyến.',
            ),
          ),
        ),
      ],
    ),
  );
}
