import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/models/progress.dart';
import '../../domain/models/vocab.dart';
import '../../domain/services/learning_engine.dart';
import '../../services/speech/speech_service.dart';
import '../../services/storage/storage_service.dart';
import '../../features/writing/handwriting_practice_screen.dart';

Color _statusColor(Srs? s) => s == null
    ? Colors.grey
    : s.interval >= 21
    ? Colors.green
    : Colors.orange;

void showAppToast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<void> _togglePersonalWord(BuildContext context, Vocab v) async {
  final wasPersonal = Store.isPersonal(v);
  try {
    await Store.togglePersonal(v);
    if (context.mounted) {
      showAppToast(
        context,
        wasPersonal
            ? 'Đã xóa “${v.hanzi}” khỏi từ điển cá nhân'
            : 'Đã thêm “${v.hanzi}” vào từ điển cá nhân',
      );
    }
  } catch (error) {
    debugPrint('Updating personal dictionary failed: $error');
    if (context.mounted) {
      showAppToast(context, 'Không thể cập nhật từ điển cá nhân. Thử lại sau.');
    }
  }
}

// --- SHARED WIDGETS ---

class FlipCard extends StatelessWidget {
  final bool flipped;
  final VoidCallback onTap;
  final Widget front, back;

  const FlipCard({
    super.key,
    required this.flipped,
    required this.onTap,
    required this.front,
    required this.back,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: flipped ? 180 : 0),
        duration: const Duration(milliseconds: 400),
        builder: (context, value, _) {
          final isBack = value >= 90;
          final colors = Theme.of(context).colorScheme;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(value * pi / 180),
            child: isBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _shell(context, colors.secondaryContainer, back),
                  )
                : _shell(context, colors.surface, front),
          );
        },
      ),
    );
  }

  Widget _shell(BuildContext context, Color color, Widget child) => Container(
    width: double.infinity,
    height: 400,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Theme.of(context).colorScheme.outlineVariant,
        width: 2,
      ),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 8)),
      ],
    ),
    child: child,
  );
}

/// Horizontal chip row (scrolling filter bar or wrapping picker).
class ChipRow extends StatelessWidget {
  final List<(int, String)> items;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool scroll;

  const ChipRow({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.scroll = false,
  });

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final (value, label) in items)
        ChoiceChip(
          label: Text(label),
          selected: value == selected,
          onSelected: (_) => onChanged(value),
        ),
    ];
    return scroll
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final c in chips)
                  Padding(padding: const EdgeInsets.only(right: 8), child: c),
              ],
            ),
          )
        : Wrap(spacing: 8, runSpacing: 4, children: chips);
  }
}

Widget _levelChip(BuildContext context, int l) {
  final levelColor = tierColor(l);
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: dark ? levelColor.shade900 : levelColor.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      levelLabel(l),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: dark ? levelColor.shade100 : levelColor.shade800,
      ),
    ),
  );
}

Widget _visual(Vocab v) {
  final emoji = Text(v.emoji, style: const TextStyle(fontSize: 64));
  return v.imageUrl.isEmpty
      ? emoji
      : ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            v.imageUrl,
            height: 100,
            errorBuilder: (_, _, _) => emoji,
          ),
        );
}

Widget speakerButton(BuildContext context, String text, {double size = 30}) =>
    IconButton(
      icon: const Icon(Icons.volume_up),
      iconSize: size,
      color: Theme.of(context).colorScheme.primary,
      onPressed: () => speak(text),
    );

Widget _exampleBox(BuildContext context, Vocab v) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              v.example,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            Text(
              v.examplePinyin,
              style: TextStyle(fontSize: 14, color: Colors.red.shade400),
            ),
            Text(
              v.exampleMeaning,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      speakerButton(context, v.example, size: 26),
    ],
  ),
);

Widget cardFront(BuildContext context, Vocab v) => Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    _levelChip(context, v.level),
    const SizedBox(height: 12),
    _visual(v),
    const SizedBox(height: 8),
    FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        v.hanzi,
        style: TextStyle(
          fontSize: 72,
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    speakerButton(context, v.hanzi, size: 36),
    Text(
      'Chạm để xem nghĩa',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  ],
);

Widget cardBack(BuildContext context, Vocab v) => Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            v.pinyin,
            style: TextStyle(
              fontSize: 32,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        speakerButton(context, v.hanzi),
      ],
    ),
    Text(
      v.meaning,
      maxLines: 6,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 24,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      textAlign: TextAlign.center,
    ),
    if (v.example.isNotEmpty) ...[
      const Divider(height: 28),
      _exampleBox(context, v),
    ],
  ],
);

/// One dictionary / word-list row: emoji, hanzi + pinyin, meaning, level, status dot, audio.
Widget wordTile(BuildContext context, Vocab v) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Material(
    color: Theme.of(context).colorScheme.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: InkWell(
      onTap: () => showWordSheet(context, v),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(
          children: [
            Text(v.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: v.hanzi,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (v.traditional.isNotEmpty &&
                            v.traditional != v.hanzi)
                          TextSpan(
                            text: '  ${v.traditional}',
                            style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        TextSpan(
                          text: '  ${v.pinyin}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    v.meaning,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.circle,
              size: 10,
              color: _statusColor(Store.srs.value[v.id]),
            ),
            const SizedBox(width: 6),
            _levelChip(context, v.level),
            speakerButton(context, v.hanzi, size: 24),
            IconButton(
              tooltip: Store.isPersonal(v)
                  ? 'Xóa khỏi từ điển cá nhân'
                  : 'Thêm vào từ điển cá nhân',
              color: Store.isPersonal(v) ? Colors.teal.shade700 : null,
              icon: Icon(
                Store.isPersonal(v) ? Icons.check_circle : Icons.add_circle,
              ),
              onPressed: () => _togglePersonalWord(context, v),
            ),
          ],
        ),
      ),
    ),
  ),
);

// --- WORD DETAIL SHEET ---

void showWordSheet(BuildContext context, Vocab v) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (ctx) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _levelChip(ctx, v.level),
          const SizedBox(height: 8),
          Text(v.emoji, style: const TextStyle(fontSize: 48)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              v.hanzi,
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w500),
            ),
          ),
          if (v.traditional.isNotEmpty && v.traditional != v.hanzi)
            Text(
              'Phồn thể: ${v.traditional}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  v.pinyin,
                  style: TextStyle(
                    fontSize: 24,
                    color: Theme.of(ctx).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              speakerButton(ctx, v.hanzi),
            ],
          ),
          Text(
            v.meaning,
            style: const TextStyle(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          if (v.example.isNotEmpty) ...[
            const Divider(height: 28),
            _exampleBox(ctx, v),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.draw_outlined),
              label: const Text('Luyện viết tay chữ Hán'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => HandwritingPracticeScreen(word: v),
                  ),
                );
              },
            ),
          ),
          if (v.custom) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Sửa'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      showWordForm(context, edit: v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                    label: const Text('Xóa'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await Store.remove(v.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã xóa “${v.hanzi}”'),
                            action: SnackBarAction(
                              label: 'Hoàn tác',
                              onPressed: () async {
                                try {
                                  await Store.upsert(v);
                                } catch (error) {
                                  debugPrint('Restoring word failed: $error');
                                  if (context.mounted) {
                                    showAppToast(
                                      context,
                                      'Không thể khôi phục từ này. Thử lại sau.',
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      } catch (error) {
                        debugPrint('Removing word failed: $error');
                        if (context.mounted) {
                          showAppToast(
                            context,
                            'Không thể xóa từ này. Thử lại sau.',
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  ),
);

// --- ADD / EDIT WORD FORM ---

Future<void> showWordForm(
  BuildContext context, {
  Vocab? edit,
  int level = 0,
  String hanzi = '',
  String meaning = '',
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      WordForm(edit: edit, level: level, hanzi: hanzi, meaning: meaning),
);

class WordForm extends StatefulWidget {
  final Vocab? edit;
  final int level;
  final String hanzi, meaning;
  const WordForm({
    super.key,
    this.edit,
    this.level = 0,
    this.hanzi = '',
    this.meaning = '',
  });

  @override
  State<WordForm> createState() => _WordFormState();
}

class _WordFormState extends State<WordForm> {
  final _key = GlobalKey<FormState>();
  late final _hanzi = TextEditingController(
    text: widget.edit?.hanzi ?? widget.hanzi,
  );
  late final _pinyin = TextEditingController(text: widget.edit?.pinyin ?? '');
  late final _meaning = TextEditingController(
    text: widget.edit?.meaning ?? widget.meaning,
  );
  late final _example = TextEditingController(text: widget.edit?.example ?? '');
  late final _exPinyin = TextEditingController(
    text: widget.edit?.examplePinyin ?? '',
  );
  late final _exMeaning = TextEditingController(
    text: widget.edit?.exampleMeaning ?? '',
  );
  late final _emoji = TextEditingController(text: widget.edit?.emoji ?? '');
  late int _level = widget.edit?.level ?? widget.level;

  @override
  void dispose() {
    for (final c in [
      _hanzi,
      _pinyin,
      _meaning,
      _example,
      _exPinyin,
      _exMeaning,
      _emoji,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    String t(TextEditingController c) => c.text.trim();
    try {
      await Store.upsert(
        Vocab(
          id: widget.edit?.id ?? 'c${DateTime.now().microsecondsSinceEpoch}',
          hanzi: t(_hanzi),
          pinyin: t(_pinyin),
          meaning: t(_meaning),
          emoji: t(_emoji).isEmpty ? '📝' : t(_emoji),
          level: _level,
          example: t(_example),
          examplePinyin: t(_exPinyin),
          exampleMeaning: t(_exMeaning),
          custom: true,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      debugPrint('Saving word failed: $error');
      if (mounted) {
        showAppToast(context, 'Không thể lưu từ này. Thử lại sau.');
      }
    }
  }

  Widget _f(
    TextEditingController c,
    String label, {
    bool req = false,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: req ? '$label *' : label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: req
          ? (s) => (s ?? '').trim().isEmpty ? 'Bắt buộc' : null
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final hasExtra =
        widget.edit != null &&
        (widget.edit!.example.isNotEmpty || widget.edit!.emoji != '📝');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Form(
          key: _key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.edit == null ? 'Thêm từ mới' : 'Sửa từ',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _f(_hanzi, 'Hán tự', req: true, hint: '你好'),
              _f(_pinyin, 'Pinyin', req: true, hint: 'nǐ hǎo'),
              _f(_meaning, 'Nghĩa tiếng Việt', req: true, hint: 'Xin chào'),
              const Text(
                'Bậc HSK (tuỳ chọn)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ChipRow(
                items: formLevels,
                selected: _level,
                onChanged: (l) => setState(() => _level = l),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: hasExtra,
                title: const Text('Ví dụ & biểu tượng (tuỳ chọn)'),
                childrenPadding: const EdgeInsets.only(top: 8),
                children: [
                  _f(_example, 'Câu ví dụ'),
                  _f(_exPinyin, 'Pinyin câu ví dụ'),
                  _f(_exMeaning, 'Nghĩa câu ví dụ'),
                  _f(_emoji, 'Emoji minh họa', hint: '📝'),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.check),
                label: const Text('Lưu từ', style: TextStyle(fontSize: 16)),
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
