import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/services/opus_model_download_service.dart';
import '../../data/services/study_material_download_service.dart';
import '../../data/services/study_material_library.dart';
import '../../services/ai/qwen_chat_service.dart';

class DownloadCenterScreen extends StatefulWidget {
  const DownloadCenterScreen({super.key});

  @override
  State<DownloadCenterScreen> createState() => _DownloadCenterScreenState();
}

class _DownloadCenterScreenState extends State<DownloadCenterScreen> {
  final _studyMaterials = StudyMaterialDownloadService.instance;
  final _translationModel = OpusModelDownloadService.instance;
  final _qwen = QwenChatService.instance;
  bool _studyMaterialsReady = false;
  bool _translationModelReady = false;
  bool _qwenReady = false;
  bool _checking = true;
  String? _downloadingPackage;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    try {
      final results = await Future.wait([
        _studyMaterials.isInstalled,
        _translationModel.isInstalled,
        _qwen.isModelDownloaded,
      ]);
      if (!mounted) return;
      setState(() {
        _studyMaterialsReady = results[0];
        _translationModelReady = results[1];
        _qwenReady = results[2];
        _checking = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _checking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không kiểm tra được gói dữ liệu: $error')),
      );
    }
  }

  Future<void> _download({
    required String package,
    required Future<void> Function() action,
  }) async {
    setState(() => _downloadingPackage = package);
    try {
      await action();
      if (package == 'study') {
        await StudyMaterialLibrary.instance.refresh();
      }
      await _refreshStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã tải xong gói dữ liệu.')));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được gói dữ liệu: $error')),
      );
    } finally {
      if (mounted) setState(() => _downloadingPackage = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dữ liệu và AI')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Từ điển và chỉ mục đề thi cơ bản luôn có sẵn ngoại tuyến. '
              'Tải riêng các gói bên dưới khi cần để giữ bộ cài gọn nhẹ. '
              'Các gói lớn cần kết nối Internet và dung lượng lưu trữ trống.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _packageCard(
          context: context,
          title: 'Audio và PDF bài nghe/đề thi',
          description: 'Khoảng 635 MB · HSK 1–6',
          ready: _studyMaterialsReady,
          checking: _checking,
          active: _downloadingPackage == 'study',
          status: _studyMaterials.downloadStatus,
          progress: _studyMaterials.downloadProgress,
          onDownload: () => _download(
            package: 'study',
            action: _studyMaterials.downloadStudyMaterials,
          ),
        ),
        _packageCard(
          context: context,
          title: 'Mô hình dịch Trung–Việt',
          description: 'Khoảng 230 MB · chạy ngoại tuyến',
          ready: _translationModelReady,
          checking: _checking,
          active: _downloadingPackage == 'translation',
          status: _translationModel.downloadStatus,
          progress: _translationModel.downloadProgress,
          onDownload: () => _download(
            package: 'translation',
            action: _translationModel.downloadModel,
          ),
        ),
        _packageCard(
          context: context,
          title: 'AI hội thoại Qwen2.5-0.5B-Instruct',
          description: 'Khoảng 491 MB · chạy ngoại tuyến',
          ready: _qwenReady,
          checking: _checking,
          active: _downloadingPackage == 'qwen',
          status: _qwen.downloadStatus,
          progress: _qwen.downloadProgress,
          onDownload: () =>
              _download(package: 'qwen', action: _qwen.downloadModel),
        ),
      ],
    ),
  );

  Widget _packageCard({
    required BuildContext context,
    required String title,
    required String description,
    required bool ready,
    required bool checking,
    required bool active,
    required ValueListenable<String?> status,
    required ValueListenable<double?> progress,
    required VoidCallback onDownload,
  }) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.check_circle : Icons.cloud_download_outlined,
                color: ready ? Colors.green : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ready ? 'Đã tải, có thể sử dụng ngoại tuyến.' : description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (active) ...[
            const SizedBox(height: 12),
            ValueListenableBuilder<String?>(
              valueListenable: status,
              builder: (context, message, _) => Text(message ?? 'Đang tải...'),
            ),
            const SizedBox(height: 6),
            ValueListenableBuilder<double?>(
              valueListenable: progress,
              builder: (context, value, _) =>
                  LinearProgressIndicator(value: value),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: ready || checking || _downloadingPackage != null
                  ? null
                  : onDownload,
              icon: active
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(ready ? Icons.check : Icons.download),
              label: Text(
                checking
                    ? 'Đang kiểm tra'
                    : ready
                    ? 'Đã sẵn sàng'
                    : active
                    ? 'Đang tải'
                    : 'Tải xuống',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
