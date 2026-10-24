import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/text/normalization.dart';
import '../../data/repositories/vocab_repository.dart';
import '../../domain/models/vocab.dart';
import '../../services/storage/storage_service.dart';

/// The complete bundled dictionary followed by the user's own words.
List<Vocab> get allWords => [
  ...const BundledVocabRepository().getAll(),
  ...Store.custom.value,
];

// --- HSK / FILTER HELPERS ---

String levelLabel(int l) => l == 0
    ? 'Của tôi'
    : l >= 7
    ? 'HSK 7–9'
    : 'HSK $l';

MaterialColor tierColor(int l) => l == 0
    ? Colors.teal
    : l <= 3
    ? Colors.green
    : l <= 6
    ? Colors.orange
    : Colors.deepPurple;

/// Filter value: -1 = all, 0 = personal words, 1..9 = HSK group/level.
bool inScope(Vocab v, int f) =>
    f < 0 ||
    (f == 0
        ? Store.isPersonal(v)
        : f >= 7
        ? v.level >= 7
        : v.level == f);

final filterItems = <(int, String)>[
  (-1, 'Tất cả'),
  (0, 'Của tôi'),
  for (var l = 1; l <= AppConstants.hskLevelCount; l++) (l, levelLabel(l)),
];

final formLevels = <(int, String)>[
  (0, 'Không'),
  for (var l = 1; l <= AppConstants.hskLevelCount; l++) (l, levelLabel(l)),
];

// --- SEARCH ---

/// Relevance score (0 = no match). Exact > prefix > substring > example text.
int matchScore(Vocab v, String raw) {
  final q = norm(raw), h = raw.trim();
  if (q.isEmpty) return 1;
  final checks = <(bool, int)>[
    (v.hanzi == h, 100),
    (v.traditional == h, 100),
    (v.nPinyin == q, 95),
    (v.nMeaning == q, 90),
    (h.isNotEmpty && (v.hanzi.contains(h) || v.traditional.contains(h)), 80),
    (
      h.length > 1 && h.contains(v.hanzi),
      60,
    ), // pasted sentence containing the word
    (v.nPinyin.startsWith(q), 70),
    (v.nMeaning.startsWith(q), 65),
    (v.nPinyin.contains(q), 50),
    (v.nMeaning.contains(q), 45),
    (v.nExample.contains(q), 20),
  ];
  return checks.where((e) => e.$1).fold(0, (m, e) => max(m, e.$2));
}

bool matchesTypingAnswer(Vocab word, String answer) {
  final typed = answer.trim().replaceAll(RegExp(r'\s+'), '');
  if (typed.isEmpty) return false;
  final accepted = [
    word.hanzi,
    ...word.traditional.split('/'),
  ].map((form) => form.trim().replaceAll(RegExp(r'\s+'), ''));
  return accepted.any((form) => form.isNotEmpty && form == typed);
}
