import 'package:flutter/material.dart';

import '../vocabulary/vocabulary_screens.dart';
import '../../shared/study.dart';

// --- SCREEN 1: HOME (HSK 1-9 roadmap) ---
class HomeScreen extends StatelessWidget {
  final VoidCallback onReview;
  final VoidCallback onListening;
  final VoidCallback onSpeaking;
  final VoidCallback onReading;
  final VoidCallback onWriting;
  final VoidCallback onSettings;

  const HomeScreen({
    super.key,
    required this.onReview,
    required this.onListening,
    required this.onSpeaking,
    required this.onReading,
    required this.onWriting,
    required this.onSettings,
  });

  static const _tiers = [('Sơ cấp', 1, 3), ('Trung cấp', 4, 6)];

  Widget _summary(int pending, int learned, int total) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.red.shade700, Colors.deepOrange.shade400],
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '你好! 👋',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          pending > 0
              ? 'Hôm nay có $pending thẻ đang chờ bạn.'
              : 'Bạn đã ôn xong hôm nay! 🎉',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        Text(
          'Đã học $learned / $total từ',
          style: const TextStyle(color: Colors.white70),
        ),
        if (pending > 0) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red.shade700,
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Ôn ngay'),
            onPressed: onReview,
          ),
        ],
      ],
    ),
  );

  Widget _levelTile(
    BuildContext context,
    int l,
    List<Vocab> words,
    Map<String, Srs> m,
  ) {
    final inLevel = words
        .where((v) => l >= 7 ? v.level >= 7 : v.level == l)
        .toList();
    final learned = inLevel.where((v) => (m[v.id]?.reps ?? 0) > 0).length;
    final c = tierColor(l);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: c.shade50,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WordListScreen(title: levelLabel(l), level: l),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Column(
              children: [
                Text(
                  levelLabel(l),
                  style: TextStyle(
                    fontSize: l == 7 ? 22 : 26,
                    color: c.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$learned/${inLevel.length} từ',
                  style: TextStyle(fontSize: 12, color: c.shade900),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: inLevel.isEmpty ? 0 : learned / inLevel.length,
                    minHeight: 6,
                    color: c.shade600,
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _skillTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('HaMy_Pocket'),
      actions: [
        IconButton(
          tooltip: 'Cài đặt',
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: storeChanges,
      builder: (context, _) {
        final words = allWords, m = Store.srs.value;
        final pending = buildQueue(words, m, DateTime.now()).length;
        final learned = words.where((v) => (m[v.id]?.reps ?? 0) > 0).length;
        final mine = Store.personalWords.length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _summary(pending, learned, words.length),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Chọn kỹ năng luyện tập',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _skillTile(
              icon: Icons.headphones,
              title: 'Luyện nghe',
              subtitle: 'Nghe từ và câu tiếng Trung',
              color: Colors.blue,
              onTap: onListening,
            ),
            _skillTile(
              icon: Icons.record_voice_over,
              title: 'Luyện nói',
              subtitle: 'Luyện thanh điệu và giao tiếp',
              color: Colors.deepOrange,
              onTap: onSpeaking,
            ),
            _skillTile(
              icon: Icons.newspaper,
              title: 'Đọc báo',
              subtitle: 'Chọn bài báo tiếng Trung từ nhiều nguồn tin',
              color: Colors.teal,
              onTap: onReading,
            ),
            _skillTile(
              icon: Icons.keyboard,
              title: 'Luyện gõ',
              subtitle: 'Nhập chữ Hán theo nghĩa tiếng Việt',
              color: Colors.deepPurple,
              onTap: onWriting,
            ),
            const SizedBox(height: 16),
            for (final (name, start, end) in _tiers) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '$name · HSK $start–$end',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                children: [
                  for (var l = start; l <= end; l++)
                    Expanded(child: _levelTile(context, l, words, m)),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                'Cao cấp · HSK 7–9',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Row(children: [Expanded(child: _levelTile(context, 7, words, m))]),
            const SizedBox(height: 16),
            Material(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Icon(
                  Icons.bookmarks,
                  color: Colors.teal.shade700,
                  size: 32,
                ),
                title: const Text(
                  'Từ điển của tôi',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('$mine từ đã lưu'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WordListScreen(
                      title: 'Từ điển của tôi',
                      level: 0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
