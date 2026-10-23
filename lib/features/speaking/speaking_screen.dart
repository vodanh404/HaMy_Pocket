import 'package:flutter/material.dart';

import '../../shared/widgets/feature_preview_screen.dart';

class SpeakingScreen extends StatelessWidget {
  const SpeakingScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePreviewScreen(
    title: 'Luyện nói',
    subtitle: 'Làm quen thanh điệu và tự tin nói tiếng Trung.',
    icon: Icons.record_voice_over,
    color: Colors.deepOrange,
    activities: [
      PreviewActivity(
        icon: Icons.graphic_eq,
        title: 'Luyện thanh điệu',
        description: 'Phân biệt bốn thanh điệu và thanh nhẹ.',
      ),
      PreviewActivity(
        icon: Icons.mic,
        title: 'Nói theo mẫu',
        description: 'Nghe câu mẫu rồi thực hành phát âm.',
      ),
      PreviewActivity(
        icon: Icons.chat_bubble_outline,
        title: 'Hội thoại ngắn',
        description: 'Thực hành các tình huống giao tiếp quen thuộc.',
      ),
    ],
  );
}
