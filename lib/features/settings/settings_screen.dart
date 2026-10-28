import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/services/listening_exam_repository.dart';
import '../../data/services/study_material_library.dart';
import 'download_center_screen.dart';
import '../../services/speech/sherpa_chinese_voice_service.dart';
import '../../services/storage/app_preferences.dart';
import '../../shared/study.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _voicePackReady = false;
  bool _downloadingVoice = false;

  @override
  void initState() {
    super.initState();
    _refreshVoicePackStatus();
  }

  Future<void> _refreshVoicePackStatus() async {
    final installed = await SherpaChineseVoiceService.instance.isInstalled;
    if (mounted) setState(() => _voicePackReady = installed);
  }

  Future<void> _downloadVoicePack() async {
    setState(() => _downloadingVoice = true);
    try {
      await SherpaChineseVoiceService.instance.downloadVoicePack();
      if (!mounted) return;
      setState(() => _voicePackReady = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tải mô hình ba giọng đọc Sherpa ONNX.'),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được mô hình giọng đọc: $error')),
      );
    } finally {
      if (mounted) setState(() => _downloadingVoice = false);
    }
  }

  Future<void> _setDarkMode(bool enabled) async {
    try {
      await AppPreferences.setDarkMode(enabled);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lưu được giao diện: $error')),
      );
    }
  }

  Future<void> _setVoiceSpeaker(int? speaker) async {
    if (speaker == null) return;
    try {
      await AppPreferences.setVoiceSpeaker(speaker);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lưu được giọng đọc: $error')),
      );
    }
  }

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
          'Thao tác này xóa tiến độ, từ cá nhân, tài liệu đã nhập và đáp án tự tạo. '
          'Học liệu có sẵn trong ứng dụng sẽ được giữ lại. Không thể hoàn tác.',
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
    await ListeningExamRepository.clearGeneratedDatabase();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã xóa dữ liệu đã nhập; học liệu có sẵn trong ứng dụng được giữ lại.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cài đặt')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsSection(
          title: 'Âm thanh',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: ValueListenableBuilder<int>(
                valueListenable: AppPreferences.voiceSpeaker,
                builder: (context, speaker, _) => DropdownButtonFormField<int>(
                  initialValue: speaker,
                  decoration: const InputDecoration(
                    labelText: 'Giọng Sherpa tiếng Trung',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Giọng đọc 1')),
                    DropdownMenuItem(value: 1, child: Text('Giọng đọc 2')),
                    DropdownMenuItem(value: 2, child: Text('Giọng đọc 3')),
                  ],
                  onChanged: _setVoiceSpeaker,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(
                _voicePackReady
                    ? 'Đã cài mô hình giọng đọc ngoại tuyến'
                    : 'Mô hình giọng đọc ngoại tuyến (~40 MB)',
              ),
              subtitle: Text(
                _downloadingVoice ? 'Đang tải...' : 'Tải lần đầu để dùng ba giọng Sherpa ngay cả khi ngoại tuyến',
              ),
              trailing: _downloadingVoice
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: _voicePackReady
                          ? 'Tải lại mô hình'
                          : 'Tải mô hình',
                      onPressed: _downloadVoicePack,
                      icon: Icon(
                        _voicePackReady ? Icons.check_circle : Icons.download,
                      ),
                    ),
            ),
            _SpeechTestTile(),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'Dữ liệu học tập',
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('Dữ liệu và AI tải thêm'),
              subtitle: const Text(
                'Quản lý audio, PDF và các mô hình chạy ngoại tuyến',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DownloadCenterScreen(),
                ),
              ),
            ),
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
                'Xóa tiến độ, từ cá nhân và tài liệu đã nhập; giữ học liệu có sẵn',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _confirmDeleteData,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'Ứng dụng',
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: AppPreferences.darkMode,
              builder: (context, enabled, _) => SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Giao diện tối'),
                subtitle: const Text('Áp dụng cho toàn bộ ứng dụng'),
                value: enabled,
                onChanged: _setDarkMode,
              ),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('HaMy_Pocket'),
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
