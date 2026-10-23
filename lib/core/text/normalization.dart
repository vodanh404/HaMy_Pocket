// --- TEXT NORMALIZATION (for diacritic-insensitive search) ---

const _foldGroups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵāǎ',
  'e': 'èéẹẻẽêềếệểễēě',
  'i': 'ìíịỉĩīǐ',
  'o': 'òóọỏõôồốộổỗơờớợởỡōǒ',
  'u': 'ùúụủũưừứựửữūǔǖǘǚǜü',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<String, String> _foldMap = {
  for (final e in _foldGroups.entries)
    for (final c in e.value.split('')) c: e.key,
};

/// Lowercase, strip Vietnamese diacritics + pinyin tone marks, drop spaces/punctuation.
String norm(String s) => s
    .toLowerCase()
    .split('')
    .map((c) => _foldMap[c] ?? c)
    .join()
    .replaceAll(RegExp(r"[\s'’\-,.]"), '');
