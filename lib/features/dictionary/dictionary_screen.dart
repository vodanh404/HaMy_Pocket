import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'translation_screen.dart';
import '../../shared/study.dart';

// --- SCREEN 4: DICTIONARY (accent-insensitive search, HSK filter, user's own words) ---
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _c = TextEditingController();
  int _filter = -1;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  List<Vocab> _results() {
    final scored =
        allWords
            .where((v) => inScope(v, _filter))
            .map((v) => (v, matchScore(v, _c.text)))
            .where((e) => e.$2 > 0)
            .toList()
          ..sort(
            (a, b) => b.$2 != a.$2
                ? b.$2.compareTo(a.$2)
                : a.$1.level.compareTo(b.$1.level),
          );
    return scored.map((e) => e.$1).toList();
  }

  void _addFromQuery() {
    final q = _c.text.trim();
    final cjk = RegExp(r'[\u4e00-\u9fff]').hasMatch(q);
    showWordForm(
      context,
      hanzi: cjk ? q : '',
      meaning: cjk ? '' : q,
      level: max(_filter, 0),
    );
  }

  void _translateQuery() {
    final query = _c.text.trim();
    if (query.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TranslationScreen(initialText: query),
      ),
    );
  }

  Future<void> _export() async {
    final list = Store.personalWords;
    await Clipboard.setData(
      ClipboardData(text: jsonEncode(list.map((v) => v.toJson()).toList())),
    );
    if (mounted) {
      showAppToast(context, 'Đã sao chép ${list.length} từ vào clipboard');
    }
  }

  Future<void> _import() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    try {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final incoming = (jsonDecode(text) as List).indexed.map(
        (e) => Vocab.fromJson({
          ...(e.$2 as Map<String, dynamic>),
          'id': 'c${stamp}_${e.$1}',
        }),
      );
      final have = Store.personalWords
          .map((v) => '${v.hanzi}|${v.meaning}')
          .toSet();
      final fresh = incoming
          .where((v) => !have.contains('${v.hanzi}|${v.meaning}'))
          .toList();
      await Store.setCustom([...Store.custom.value, ...fresh]);
      if (mounted) {
        showAppToast(context, 'Đã nhập ${fresh.length} từ mới');
      }
    } catch (_) {
      if (mounted) {
        showAppToast(context, 'Clipboard không chứa dữ liệu từ điển hợp lệ');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Từ Điển'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (s) => s == 'x' ? _export() : _import(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'x',
                child: Text('Sao chép từ điển của tôi'),
              ),
              PopupMenuItem(value: 'i', child: Text('Nhập từ clipboard')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Thêm từ'),
        onPressed: () => showWordForm(context, level: max(_filter, 0)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _c,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Hán tự, pinyin (ni hao) hoặc nghĩa (xin chao)…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _c.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_c.clear),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (_c.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _translateQuery,
                  icon: const Icon(Icons.translate),
                  label: const Text('Dịch bằng Opus Trung–Việt'),
                ),
              ),
            ),
          ChipRow(
            items: filterItems,
            selected: _filter,
            scroll: true,
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedBuilder(
              animation: storeChanges,
              builder: (context, _) {
                final results = _results();
                if (results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Không tìm thấy kết quả.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add),
                          label: Text(
                            _c.text.trim().isEmpty
                                ? 'Thêm từ mới'
                                : 'Thêm “${_c.text.trim()}” vào từ điển',
                          ),
                          onPressed: _addFromQuery,
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: results.length + 1,
                  itemBuilder: (context, index) => index == 0
                      ? Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            '${results.length} từ',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        )
                      : wordTile(context, results[index - 1]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
