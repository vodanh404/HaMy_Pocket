import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/services/study_material_library.dart';
import '../../shared/study.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _showSyncDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: Store.createSyncCode());
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Mã đồng bộ dữ liệu học'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sao chép mã này hoặc dán mã từ thiết bị khác để khôi phục.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Mã đồng bộ',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: controller.text));
                if (dialogContext.mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Đã sao chép mã đồng bộ.')),
                  );
                }
              },
              child: const Text('Sao chép'),
            ),
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: dialogContext,
                  builder: (confirmationContext) => AlertDialog(
                    title: const Text('Khôi phục dữ liệu?'),
                    content: const Text(
                      'Dữ liệu học hiện tại sẽ được thay bằng dữ liệu trong mã.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(confirmationContext, false),
                        child: const Text('Hủy'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(confirmationContext, true),
                        child: const Text('Khôi phục'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !dialogContext.mounted) return;
                try {
                  await Store.restoreSyncCode(controller.text);
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Đã khôi phục dữ liệu học.')),
                  );
                } on FormatException catch (error) {
                  if (!dialogContext.mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text(error.message)),
                  );
                } on StateError catch (error) {
                  if (!dialogContext.mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Không thể lưu dữ liệu: $error')),
                  );
                }
              },
              child: const Text('Khôi phục'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _confirmDeleteData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa toàn bộ dữ liệu người dùng?'),
        content: const Text(
          'Thao tác này xóa tiến độ, từ cá nhân và tài liệu đã nhập. Không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa dữ liệu'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await Store.clearAll();
    await StudyMaterialLibrary.instance.clearImported();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa toàn bộ dữ liệu người dùng.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cài đặt')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SettingsSection(
          title: 'Âm thanh',
          children: [
            ListTile(
              leading: Icon(Icons.record_voice_over),
              title: Text('Giọng đọc tiếng Trung'),
              subtitle: Text('Dùng giọng zh-CN có sẵn trên thiết bị'),
            ),
            _SpeechTestTile(),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'Dữ liệu học tập',
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('Từ điển ngoại tuyến'),
              subtitle: Text('${allWords.length} mục từ có sẵn trên thiết bị'),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('Từ đã lưu'),
              subtitle: Text(
                '${Store.personalWords.length} từ trong từ điển cá nhân',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Tạo mã đồng bộ'),
              subtitle: const Text('Sao chép hoặc khôi phục tiến độ học tập'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showSyncDialog,
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Xóa toàn bộ dữ liệu người dùng'),
              subtitle: const Text(
                'Xóa tiến độ, từ cá nhân và tài liệu đã nhập',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _confirmDeleteData,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SettingsSection(
          title: 'Ứng dụng',
          children: [
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Học Tiếng Trung'),
              subtitle: Text('Từ vựng, ôn tập và luyện tập theo HSK'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ...children,
      ],
    ),
  );
}

class _SpeechTestTile extends StatelessWidget {
  const _SpeechTestTile();

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.volume_up),
    title: const Text('Thử giọng đọc'),
    subtitle: const Text('Phát câu “你好，很高兴认识你。”'),
    trailing: const Icon(Icons.play_circle_outline),
    onTap: () => speak('你好，很高兴认识你。'),
  );
}
