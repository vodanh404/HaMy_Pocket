import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../data/models/listening_exam.dart';
import '../data/models/study_material.dart';
import '../data/services/listening_exam_repository.dart';
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

  Future<void> _importDirectory() async {
    setState(() => _importing = true);
    try {
      final directoryPath = await FilePicker.getDirectoryPath();
      if (directoryPath == null || !mounted) return;
      final count = await _library.importDirectory(directoryPath);
      if (!mounted) return;
      final message = count == 0
          ? 'Không tìm thấy tệp PDF hoặc MP3 trong thư mục đã chọn.'
          : 'Đã tự động quét và nhập $count tệp.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on PlatformException catch (error) {
      _showImportError(error.message ?? error.code);
    } on FileSystemException catch (error) {
      _showImportError(error.message);
    } on StateError catch (error) {
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
              tooltip: 'Quét thư mục học liệu',
              onPressed: _importing ? null : _importDirectory,
              icon: const Icon(Icons.folder_open_outlined),
            ),
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
  ExamSection _section = ExamSection.listening;
  late final Future<ExamSectionPages?> _sectionPagesFuture;

  @override
  void initState() {
    super.initState();
    final exercise = StudyMaterialLibrary.instance.exerciseFor(widget.material);
    _sectionPagesFuture = exercise == null
        ? Future.value(null)
        : ListeningExamRepository.instance.sectionPagesFor(exercise);
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
    final hasWritingSection = (widget.material.level ?? 0) >= 3;
    final progressId =
        '${widget.material.type}:${widget.material.fileName.toLowerCase()}';
    return Scaffold(
      appBar: AppBar(title: Text(widget.material.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SegmentedButton<ExamSection>(
              segments: [
                const ButtonSegment(
                  value: ExamSection.listening,
                  icon: Icon(Icons.headphones),
                  label: Text('Nghe'),
                ),
                const ButtonSegment(
                  value: ExamSection.reading,
                  icon: Icon(Icons.menu_book),
                  label: Text('Đọc'),
                ),
                if (hasWritingSection)
                  const ButtonSegment(
                    value: ExamSection.writing,
                    icon: Icon(Icons.edit_note),
                    label: Text('Viết'),
                  ),
              ],
              selected: {_section},
              onSelectionChanged: (selection) =>
                  setState(() => _section = selection.first),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(switch (_section) {
                          ExamSection.listening => 'Phần nghe',
                          ExamSection.reading => 'Phần đọc hiểu',
                          ExamSection.writing => 'Phần viết',
                        }, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                Card(
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
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
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
                                              : _duration.inMilliseconds
                                                    .toDouble(),
                                          onChanged: _duration == Duration.zero
                                              ? null
                                              : (value) => _player.seek(
                                                  Duration(
                                                    milliseconds: value.round(),
                                                  ),
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
                                            _playing
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ValueListenableBuilder<Set<String>>(
                                          valueListenable:
                                              Store.completedMaterials,
                                          builder: (context, completedMaterials, _) {
                                            final isCompleted =
                                                completedMaterials.contains(
                                                  progressId,
                                                );
                                            return OutlinedButton.icon(
                                              onPressed: () =>
                                                  Store.setMaterialCompleted(
                                                    progressId,
                                                    !isCompleted,
                                                  ),
                                              icon: Icon(
                                                isCompleted
                                                    ? Icons.check_circle
                                                    : Icons
                                                          .check_circle_outline,
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
                                ListeningAnswerForm(
                                  material: widget.material,
                                  section: _section,
                                ),
                              ],
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
                        Text(switch (_section) {
                          ExamSection.listening => 'Đề nghe',
                          ExamSection.reading => 'Bài đọc và đáp án',
                          ExamSection.writing => 'Bài viết và đáp án',
                        }, style: Theme.of(context).textTheme.titleLarge),
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
                              : FutureBuilder<ExamSectionPages?>(
                                  future: _sectionPagesFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text(
                                          'Không thể xác định trang đề: ${snapshot.error}',
                                        ),
                                      );
                                    }
                                    if (snapshot.connectionState !=
                                        ConnectionState.done) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    final pages = snapshot.data;
                                    final initialPage =
                                        pages?.pageFor(_section) ??
                                        switch (_section) {
                                          ExamSection.listening => 2,
                                          ExamSection.reading => 7,
                                          ExamSection.writing => 7,
                                        };
                                    return exercise.localPath != null
                                        ? PdfViewer.file(
                                            exercise.localPath!,
                                            key: ValueKey(
                                              '${exercise.id}-$_section',
                                            ),
                                            initialPageNumber: initialPage,
                                          )
                                        : PdfViewer.asset(
                                            'assets/${exercise.source}',
                                            key: ValueKey(
                                              '${exercise.id}-$_section',
                                            ),
                                            initialPageNumber: initialPage,
                                          );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ListeningAnswerForm extends StatefulWidget {
  const ListeningAnswerForm({
    super.key,
    required this.material,
    this.readingMode = false,
    this.section,
  });

  final StudyMaterial material;
  final bool readingMode;
  final ExamSection? section;

  @override
  State<ListeningAnswerForm> createState() => _ListeningAnswerFormState();
}

class _ListeningAnswerFormState extends State<ListeningAnswerForm> {
  late final Future<ListeningExam?> _examFuture;
  final Map<String, String> _userAnswers = {};
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _examFuture = ListeningExamRepository.instance.loadForAudio(
      widget.material,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ListeningExam?>(
    future: _examFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return _message('Không thể tải đáp án: ${snapshot.error}');
      }
      final exam = snapshot.data;
      if (exam == null ||
          exam.audio.toLowerCase() != widget.material.fileName.toLowerCase()) {
        return _message(
          'Chưa đọc được đáp án. Hãy ghép MP3 với PDF cùng mã đề có trang '
          'đáp án; ứng dụng sẽ tự tạo JSON để chấm điểm.',
        );
      }
      return _answerForm(
        exam,
        widget.section ??
            (widget.readingMode ? ExamSection.reading : ExamSection.listening),
      );
    },
  );

  Widget _message(String message) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  Widget _answerForm(ListeningExam exam, ExamSection section) {
    final questionNumbers = exam.questionNumbersFor(section);
    final sectionAnswers = exam.answersForSection(section);
    final listeningAnswers = exam.answersForSection(ExamSection.listening);
    final readingAnswers = exam.answersForSection(ExamSection.reading);
    final writingAnswers = exam.answersForSection(ExamSection.writing);
    final sectionTitle = switch (section) {
      ExamSection.listening => 'Phần nghe',
      ExamSection.reading => 'Phần đọc hiểu',
      ExamSection.writing => 'Phần viết',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(sectionTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_submitted)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Nghe: '
                      '${_countCorrectAnswers(listeningAnswers)}'
                      '/${exam.listeningQuestionCount} · Đọc: '
                      '${_countCorrectAnswers(readingAnswers)}'
                      '/${exam.readingQuestionCount}'
                      '${exam.writingQuestionCount > 0 ? ' · Viết: ${_countCorrectAnswers(writingAnswers)}/${exam.writingQuestionCount}' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Tổng: '
                      '${_countCorrectAnswers(exam.answers)}'
                      '/${exam.questionCount}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (questionNumbers.length > sectionAnswers.length)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Không có đáp án chấm tự động cho '
                        '${questionNumbers.length - sectionAnswers.length} câu trong phần này.',
                      ),
                    ),
                ],
              )
            else if (questionNumbers.length > sectionAnswers.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${questionNumbers.length - sectionAnswers.length} câu không có đáp án chấm tự động.',
                ),
              ),
            for (final questionNumber in questionNumbers)
              _question(exam, questionNumber, section),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submitted
                  ? null
                  : () => setState(() => _submitted = true),
              child: const Text('Nộp bài'),
            ),
          ],
        ),
      ),
    );
  }

  int _countCorrectAnswers(Map<String, String> expectedAnswers) =>
      expectedAnswers.entries.where((entry) {
        final userAnswer = ListeningExam.normalizeFreeResponse(
          _userAnswers[entry.key] ?? '',
        );
        return entry.value
            .split(RegExp(r'\s*[/／]\s*'))
            .map(ListeningExam.normalizeFreeResponse)
            .contains(userAnswer);
      }).length;

  Widget _question(
    ListeningExam exam,
    String questionNumber,
    ExamSection section,
  ) {
    final correctAnswer = exam.answers[questionNumber];
    final options = _optionsFor(
      questionNumber,
      correctAnswer,
      extendedExam: exam.questionCount > 40,
    );
    final textResponse =
        section == ExamSection.writing &&
            (correctAnswer == null ||
                ListeningExam.isFreeResponseAnswer(correctAnswer)) ||
        correctAnswer != null &&
            ListeningExam.isFreeResponseAnswer(correctAnswer);
    final normalizedUserAnswer = ListeningExam.normalizeFreeResponse(
      _userAnswers[questionNumber] ?? '',
    );
    final isCorrect =
        correctAnswer != null &&
        correctAnswer
            .split(RegExp(r'\s*[/／]\s*'))
            .map(ListeningExam.normalizeFreeResponse)
            .contains(normalizedUserAnswer);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Câu $questionNumber'),
          const SizedBox(height: 4),
          if (textResponse)
            TextField(
              key: ValueKey('answer-$questionNumber'),
              enabled: !_submitted,
              onChanged: (value) =>
                  setState(() => _userAnswers[questionNumber] = value),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Nhập câu trả lời',
                helperText: _submitted
                    ? correctAnswer == null
                          ? 'Tự đối chiếu với PDF; câu này không có đáp án mẫu.'
                          : isCorrect
                          ? 'Chính xác'
                          : 'Đáp án: $correctAnswer'
                    : null,
                helperStyle: TextStyle(
                  color: isCorrect
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                ),
              ),
            )
          else
            Wrap(
              spacing: 4,
              children: [
                for (final option in options)
                  ChoiceChip(
                    label: Text(option),
                    selected: _userAnswers[questionNumber] == option,
                    onSelected: _submitted
                        ? null
                        : (selected) {
                            if (selected) {
                              setState(
                                () => _userAnswers[questionNumber] = option,
                              );
                            }
                          },
                    selectedColor: !_submitted || correctAnswer == null
                        ? null
                        : option.toLowerCase() == correctAnswer.toLowerCase()
                        ? Colors.green.shade300
                        : Colors.red.shade200,
                  ),
              ],
            ),
          if (_submitted && correctAnswer != null && !textResponse)
            Text(
              'Đáp án: $correctAnswer',
              style: TextStyle(color: Colors.green.shade800),
            ),
          if (_submitted && correctAnswer == null && !textResponse)
            const Text('Không có đáp án chấm tự động trong JSON.'),
        ],
      ),
    );
  }

  List<String> _optionsFor(
    String questionNumber,
    String? correctAnswer, {
    required bool extendedExam,
  }) {
    final question = int.parse(questionNumber);
    final answerValue = correctAnswer;
    final answer = answerValue?.toLowerCase();
    if (answer == 'đúng' || answer == 'sai') {
      return const ['Đúng', 'Sai'];
    }
    if (extendedExam) {
      return const ['A', 'B', 'C', 'D', 'E', 'F'];
    }
    final options = question <= 5 || (question >= 21 && question <= 25)
        ? ['Đúng', 'Sai']
        : question <= 10
        ? ['A', 'B', 'C']
        : question <= 15
        ? ['A', 'B', 'C', 'D', 'E', 'F']
        : question <= 20
        ? ['A', 'B', 'C']
        : ['A', 'B', 'C', 'D', 'E', 'F'];
    if (answer != null &&
        !options.any((option) => option.toLowerCase() == answer)) {
      options.add(answerValue!);
    }
    return options;
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
