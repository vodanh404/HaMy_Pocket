import '../../core/text/normalization.dart';

// --- DATA MODELS ---

class Vocab {
  final String id, hanzi, pinyin, meaning, emoji;
  final String traditional;
  final String example, examplePinyin, exampleMeaning;
  final String
  imageUrl; // optional: any image URL, falls back to emoji on error
  final int level; // 1..6 = individual HSK level, 7 = grouped HSK 7-9.
  final bool custom;

  // Pre-normalized search fields (computed once per word).
  late final String nPinyin = norm(pinyin);
  late final String nMeaning = norm(meaning);
  late final String nExample = norm('$example $exampleMeaning');

  Vocab({
    required this.id,
    required this.hanzi,
    required this.pinyin,
    required this.meaning,
    required this.level,
    this.traditional = '',
    this.emoji = '📝',
    this.example = '',
    this.examplePinyin = '',
    this.exampleMeaning = '',
    this.imageUrl = '',
    this.custom = false,
  });

  factory Vocab.fromJson(Map<String, dynamic> j, {bool custom = true}) {
    String requiredString(String key) {
      final value = j[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException(
          'Vocabulary field "$key" must be a non-empty string.',
        );
      }
      return value;
    }

    String optionalString(String key, [String fallback = '']) {
      final value = j[key];
      if (value == null) return fallback;
      if (value is! String) {
        throw FormatException('Vocabulary field "$key" must be a string.');
      }
      return value;
    }

    final level = j['l'] ?? 0;
    if (level is! int || level < 0 || level > 9) {
      throw const FormatException('Vocabulary level must be between 0 and 9.');
    }

    return Vocab(
      id: requiredString('id'),
      hanzi: requiredString('h'),
      pinyin: requiredString('p'),
      meaning: requiredString('m'),
      emoji: optionalString('e', '📝'),
      level: level,
      traditional: optionalString('t'),
      example: optionalString('x'),
      examplePinyin: optionalString('xp'),
      exampleMeaning: optionalString('xm'),
      imageUrl: optionalString('iu'),
      custom: custom,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'h': hanzi,
    't': traditional,
    'p': pinyin,
    'm': meaning,
    'e': emoji,
    'l': level,
    'x': example,
    'xp': examplePinyin,
    'xm': exampleMeaning,
    'iu': imageUrl,
  };
}
