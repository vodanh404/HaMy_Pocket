import '../../domain/models/vocab.dart';
import '../datasources/dictionary_data_source.dart';

abstract interface class VocabRepository {
  List<Vocab> getAll();
}

class BundledVocabRepository implements VocabRepository {
  const BundledVocabRepository();

  @override
  List<Vocab> getAll() => builtIn;
}
