import '../domain/models/vocab.dart';
import '../services/storage/storage_service.dart';
import 'study.dart';

class NewsWordMatch {
  const NewsWordMatch({
    required this.text,
    required this.vocab,
    required this.start,
    required this.end,
  });

  final String text;
  final Vocab vocab;
  final int start;
  final int end;
}

List<Vocab>? _indexedCustomWords;
Map<String, Vocab> _vocabularyForms = {};
Map<String, List<String>> _vocabularyByFirstCharacter = {};

List<NewsWordMatch> findNewsWords(String text) {
  if (!identical(_indexedCustomWords, Store.custom.value)) {
    final forms = <String, Vocab>{};
    for (final word in allWords) {
      if (word.hanzi.isNotEmpty) forms.putIfAbsent(word.hanzi, () => word);
      if (word.traditional.isNotEmpty) {
        forms.putIfAbsent(word.traditional, () => word);
      }
    }
    final byFirstCharacter = <String, List<String>>{};
    for (final form in forms.keys) {
      byFirstCharacter.putIfAbsent(form[0], () => []).add(form);
    }
    for (final candidates in byFirstCharacter.values) {
      candidates.sort((left, right) => right.length.compareTo(left.length));
    }
    _vocabularyForms = forms;
    _vocabularyByFirstCharacter = byFirstCharacter;
    _indexedCustomWords = Store.custom.value;
  }

  final matches = <NewsWordMatch>[];
  var index = 0;
  while (index < text.length) {
    final candidates = _vocabularyByFirstCharacter[text[index]];
    String? matchedForm;
    if (candidates != null) {
      for (final candidate in candidates) {
        if (text.startsWith(candidate, index)) {
          matchedForm = candidate;
          break;
        }
      }
    }
    if (matchedForm == null) {
      index++;
      continue;
    }
    matches.add(
      NewsWordMatch(
        text: matchedForm,
        vocab: _vocabularyForms[matchedForm]!,
        start: index,
        end: index + matchedForm.length,
      ),
    );
    index += matchedForm.length;
  }
  return matches;
}
