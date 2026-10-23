import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../data/models/study_material.dart';
import '../data/services/study_material_library.dart';
import '../services/storage/storage_service.dart';

class StudyMaterialScreen extends StatefulWidget {
  const StudyMaterialScreen({
    super.key,
    required this.title,
    required this.materialTypes,
  });

  final String title;
  final Set<String> materialTypes;

  @override
  State<StudyMaterialScreen> createState() => _StudyMaterialScreenState();
}

class _StudyMaterialScreenState extends State<StudyMaterialScreen> {
  final _library = StudyMaterialLibrary.instance;
  final _searchController = TextEditingController();
  int? _selectedLevel;
  String _selectedCategory = 'all';
  bool _importing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importMaterials() async {
    setState(() => _importing = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'mp3', 'jpg', 'jpeg', 'png'],
      );
      if (files.isEmpty || !mounted) return;
      final count = await _library.importFiles(files);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã nhập $count tệp tài liệu.')));
    } on PlatformException catch (error) {
      _showImportError(error.message ?? error.code);
    } on FileSystemException catch (error) {
      _showImportError(error.message);
    } on StateError catch (error) {
      _showImportError(error.message);
    } on FormatException catch (error) {
      _showImportError(error.message);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showImportError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không thể nhập tài liệu: $message')),
    );
  }

  List<StudyMaterial> _visibleMaterials() {
    final query = _searchController.text.trim().toLowerCase();
    return _library.materials
        .where((material) => widget.materialTypes.contains(material.type))
        .where(
          (material) =>
              _selectedLevel == null || material.level == _selectedLevel,
        )
        .where(
          (material) =>
              _selectedCategory == 'all' ||
              material.category == _selectedCategory,
        )
        .where(
          (material) =>
              query.isEmpty ||
              material.title.toLowerCase().contains(query) ||
              material.fileName.toLowerCase().contains(query),
        )
        .toList()
      ..sort(_compareMaterials);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _library,
    builder: (context, _) {
      final materials = _visibleMaterials();
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              tooltip: 'Nhập tài liệu',
              onPressed: _importing ? null : _importMaterials,
              icon: _importing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_upload_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Tìm theo tên tài liệu',
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            _filters(),
            Expanded(
              child: materials.isEmpty
                  ? const Center(
                      child: Text('Không tìm thấy tài liệu phù hợp.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: materials.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _materialTile(context, materials[index]),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _importing ? null : _importMaterials,
          icon: const Icon(Icons.add_to_drive_outlined),
          label: const Text('Nhập tài liệu'),
        ),
      );
    },
  );

  Widget _filters() => SizedBox(
    height: 48,
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      children: [
        ChoiceChip(
          label: const Text('Tất cả'),
          selected: _selectedCategory == 'all',
          onSelected: (_) => setState(() => _selectedCategory = 'all'),
        ),
        const SizedBox(width: 8),
        for (final (category, label) in const [
          ('listening', 'Nghe'),
          ('exam', 'Đề thi'),
          ('theory', 'Ngữ pháp'),
          ('course', 'Giáo trình'),
          ('speaking', 'HSKK'),
        ])
          if (category == 'listening'
              ? widget.materialTypes.contains('audio')
              : widget.materialTypes.any((type) => type != 'audio'))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: _selectedCategory == category,
                onSelected: (_) => setState(() => _selectedCategory = category),
              ),
            ),
        for (var level = 1; level <= 6; level++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('HSK $level'),
              selected: _selectedLevel == level,
              onSelected: (_) => setState(
                () => _selectedLevel = _selectedLevel == level ? null : level,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _materialTile(BuildContext context, StudyMaterial material) {
    final color = material.isAvailable
        ? Colors.green.shade700
        : Colors.blueGrey.shade500;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          foregroundColor: color,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(_iconFor(material)),
        ),
        title: Text(
          material.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_details(material)}\n${material.fileName}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Icon(
          material.isBundledAudio && !material.isImported
              ? Icons.play_circle_outline
              : material.isAvailable
              ? Icons.check_circle
              : Icons.download_outlined,
          color: color,
        ),
        onTap: material.isAvailable
            ? () => _openMaterial(context, material)
            : _importMaterials,
      ),
    );
  }

  String _details(StudyMaterial material) {
    final level = material.level == null ? null : 'HSK ${material.level}';
    final category = switch (material.category) {
      'listening' => 'Nghe',
      'exam' => 'Đề thi',
      'theory' => 'Ngữ pháp',
      'course' => 'Giáo trình',
      'speaking' => 'HSKK',
      _ => 'Tài liệu',
    };
    final type = switch (material.type) {
      'audio' => 'Âm thanh',
      'image' => 'Ảnh',
      _ => 'PDF',
    };
    return [?level, category, type].join(' · ');
  }

  IconData _iconFor(StudyMaterial material) => switch (material.type) {
    'audio' => Icons.headphones,
    'image' => Icons.image_outlined,
    _ => Icons.picture_as_pdf_outlined,
  };

  void _openMaterial(BuildContext context, StudyMaterial material) {
    if (!material.isAvailable) return;
    final page = switch (material.type) {
      'audio' => AudioMaterialPlayer(material: material),
      'image' => ImageMaterialReader(material: material),
      _ => PdfMaterialReader(material: material),
    };
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }
}

class AudioMaterialPlayer extends StatefulWidget {
  const AudioMaterialPlayer({super.key, required this.material});

  final StudyMaterial material;

  @override
  State<AudioMaterialPlayer> createState() => _AudioMaterialPlayerState();
}

class _AudioMaterialPlayerState extends State<AudioMaterialPlayer> {
  final _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    try {
      if (_playing) {
        await _player.pause();
        if (mounted) setState(() => _playing = false);
        return;
      }
      if (!_started) {
        final localPath = widget.material.localPath;
        final assetPath = widget.material.source;
        if (localPath != null) {
          await _player.setSourceDeviceFile(localPath);
        } else if (assetPath != null) {
          await _player.setSourceAsset(assetPath);
        } else {
          throw StateError('Không tìm thấy nguồn tệp âm thanh.');
        }
        _started = true;
      }
      await _player.resume();
      if (mounted) setState(() => _playing = true);
    } on AudioPlayerException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể phát tệp âm thanh: $error')),
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không thể phát tệp âm thanh: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể phát tệp âm thanh: $error')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final exercise = StudyMaterialLibrary.instance.exerciseFor(widget.material);
    final progressId =
        '${widget.material.type}:${widget.material.fileName.toLowerCase()}';
    return Scaffold(
      appBar: AppBar(title: Text(widget.material.title)),
      body: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'File nghe',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.headphones,
                                size: 48,
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.material.title,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.material.fileName,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Slider(
                                value: _position.inMilliseconds
                                    .clamp(
                                      0,
                                      _duration.inMilliseconds == 0
                                          ? 1
                                          : _duration.inMilliseconds,
                                    )
                                    .toDouble(),
                                max: _duration.inMilliseconds == 0
                                    ? 1
                                    : _duration.inMilliseconds.toDouble(),
                                onChanged: _duration == Duration.zero
                                    ? null
                                    : (value) => _player.seek(
                                        Duration(milliseconds: value.round()),
                                      ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(_position)),
                                  Text(_formatDuration(_duration)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              IconButton.filled(
                                iconSize: 36,
                                onPressed: _togglePlayback,
                                icon: Icon(
                                  _playing ? Icons.pause : Icons.play_arrow,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ValueListenableBuilder<Set<String>>(
                                valueListenable: Store.completedMaterials,
                                builder: (context, completedMaterials, _) {
                                  final isCompleted = completedMaterials
                                      .contains(progressId);
                                  return OutlinedButton.icon(
                                    onPressed: () => Store.setMaterialCompleted(
                                      progressId,
                                      !isCompleted,
                                    ),
                                    icon: Icon(
                                      isCompleted
                                          ? Icons.check_circle
                                          : Icons.check_circle_outline,
                                    ),
                                    label: Text(
                                      isCompleted
                                          ? 'Đã hoàn thành'
                                          : 'Đánh dấu hoàn thành',
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'File PDF',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (exercise != null) ...[
                    Text(
                      exercise.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: exercise == null
                        ? const Center(
                            child: Text(
                              'Chưa tìm thấy PDF tương ứng.\nNhập PDF có cùng mã bài nghe.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : exercise.localPath != null
                        ? PdfViewer.file(exercise.localPath!)
                        : PdfViewer.asset('assets/${exercise.source}'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PdfMaterialReader extends StatelessWidget {
  const PdfMaterialReader({super.key, required this.material});

  final StudyMaterial material;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(material.title, overflow: TextOverflow.ellipsis),
    ),
    body: material.localPath != null
        ? PdfViewer.file(material.localPath!)
        : PdfViewer.asset('assets/${material.source}'),
  );
}

class ImageMaterialReader extends StatelessWidget {
  const ImageMaterialReader({super.key, required this.material});

  final StudyMaterial material;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(material.title, overflow: TextOverflow.ellipsis),
    ),
    body: InteractiveViewer(
      minScale: 0.5,
      maxScale: 5,
      child: Center(
        child: Image.file(
          File(material.localPath!),
          errorBuilder: (context, error, stackTrace) =>
              const Center(child: Text('Không thể mở ảnh tài liệu này.')),
        ),
      ),
    ),
  );
}

int _compareMaterials(StudyMaterial left, StudyMaterial right) {
  final levelOrder = (left.level ?? 99).compareTo(right.level ?? 99);
  if (levelOrder != 0) return levelOrder;
  final categoryOrder = left.category.compareTo(right.category);
  if (categoryOrder != 0) return categoryOrder;
  return left.title.toLowerCase().compareTo(right.title.toLowerCase());
}
