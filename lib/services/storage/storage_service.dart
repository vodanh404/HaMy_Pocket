import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/progress.dart';
import '../../domain/models/vocab.dart';

// --- PERSISTENT STORE (SRS progress + personal dictionary) ---

class Store {
  static const _srsKey = 'srs_v1', _customKey = 'custom_v1';
  static const _savedKey = 'saved_v1';
  static const _completedKey = 'completed_materials_v1';
  static final srs = ValueNotifier<Map<String, Srs>>({});
  static final custom = ValueNotifier<List<Vocab>>([]);
  static final saved = ValueNotifier<List<Vocab>>([]);
  static final completedMaterials = ValueNotifier<Set<String>>({});
  static late SharedPreferences _p;

  static Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final storedSrs = _p.getString(_srsKey);
    final storedCustom = _p.getString(_customKey);
    final storedSaved = _p.getString(_savedKey);
    final storedCompleted = _p.getString(_completedKey);
    srs.value = _readSrs(storedSrs);
    custom.value = _readWords(storedCustom, _customKey, custom: true);
    saved.value = _readWords(
      storedSaved,
      _savedKey,
      custom: false,
    ).where((word) => !custom.value.any((item) => item.id == word.id)).toList();
    completedMaterials.value = _readCompleted(storedCompleted);
    if (storedSrs != null) await _writeSrs();
    if (storedCustom != null) await _writeCustom();
    if (storedSaved != null) await _writeSaved();
  }

  static Map<String, Srs> _readSrs(String? raw) {
    if (raw == null) return {};
    final decoded = _decode(raw, _srsKey);
    if (decoded is! Map) {
      debugPrint('Ignoring invalid stored schedule: expected an object.');
      return {};
    }
    final result = <String, Srs>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String || entry.value is! Map) {
        debugPrint('Ignoring invalid stored schedule entry.');
        continue;
      }
      try {
        result[entry.key as String] = Srs.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      } on FormatException catch (error) {
        debugPrint('Ignoring invalid schedule for "${entry.key}": $error');
      }
    }
    return result;
  }

  static List<Vocab> _readWords(
    String? raw,
    String key, {
    required bool custom,
  }) {
    if (raw == null) return [];
    final decoded = _decode(raw, key);
    if (decoded is! List) {
      debugPrint('Ignoring invalid stored words in "$key": expected a list.');
      return [];
    }
    final unique = <String, Vocab>{};
    for (final item in decoded) {
      if (item is! Map) {
        debugPrint('Ignoring invalid word in "$key": expected an object.');
        continue;
      }
      try {
        final word = Vocab.fromJson(
          Map<String, dynamic>.from(item),
          custom: custom,
        );
        if (unique.containsKey(word.id)) {
          debugPrint('Replacing duplicate word ID "${word.id}" in "$key".');
        }
        unique[word.id] = word;
      } on FormatException catch (error) {
        debugPrint('Ignoring invalid word in "$key": $error');
      }
    }
    return unique.values.toList();
  }

  static dynamic _decode(String raw, String key) {
    try {
      return jsonDecode(raw);
    } on FormatException catch (error) {
      debugPrint('Ignoring malformed stored data in "$key": $error');
      return null;
    }
  }

  static Set<String> _readCompleted(String? raw) {
    if (raw == null) return {};
    final decoded = _decode(raw, _completedKey);
    if (decoded is! List) return {};
    return decoded.whereType<String>().toSet();
  }

  static String createSyncCode() {
    final payload = {
      'version': 1,
      'srs': srs.value.map((key, value) => MapEntry(key, value.toJson())),
      'custom': custom.value.map((word) => word.toJson()).toList(),
      'saved': saved.value.map((word) => word.toJson()).toList(),
      'completed_materials': completedMaterials.value.toList(),
    };
    final encoded = base64Url.encode(utf8.encode(jsonEncode(payload)));
    return 'HMY1.${encoded.replaceAll('=', '')}';
  }

  static Future<void> restoreSyncCode(String code) async {
    final trimmed = code.trim();
    if (!trimmed.startsWith('HMY1.')) {
      throw const FormatException('Mã đồng bộ không hợp lệ.');
    }
    final encoded = trimmed.substring(5);
    final dynamic decoded;
    try {
      decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
      );
    } on FormatException {
      throw const FormatException('Mã đồng bộ bị sai hoặc không đầy đủ.');
    }
    if (decoded is! Map || decoded['version'] != 1) {
      throw const FormatException('Phiên bản mã đồng bộ không được hỗ trợ.');
    }

    final rawSrs = decoded['srs'];
    final rawCustom = decoded['custom'];
    final rawSaved = decoded['saved'];
    final rawCompleted = decoded['completed_materials'];
    if (rawSrs is! Map ||
        rawCustom is! List ||
        rawSaved is! List ||
        rawCompleted is! List) {
      throw const FormatException('Mã không chứa đủ dữ liệu học tập.');
    }

    final restoredSrs = <String, Srs>{};
    for (final entry in rawSrs.entries) {
      if (entry.key is! String || entry.value is! Map) {
        throw const FormatException('Dữ liệu ôn tập trong mã không hợp lệ.');
      }
      restoredSrs[entry.key as String] = Srs.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    List<Vocab> readWords(List<dynamic> values, {required bool customWords}) =>
        values.map((item) {
          if (item is! Map) {
            throw const FormatException('Từ vựng trong mã không hợp lệ.');
          }
          return Vocab.fromJson(
            Map<String, dynamic>.from(item),
            custom: customWords,
          );
        }).toList();
    final restoredCustom = readWords(rawCustom, customWords: true);
    final customIds = restoredCustom.map((word) => word.id).toSet();
    final restoredSaved = readWords(
      rawSaved,
      customWords: false,
    ).where((word) => !customIds.contains(word.id)).toList();
    if (rawCompleted.any((item) => item is! String)) {
      throw const FormatException('Tiến độ hoàn thành trong mã không hợp lệ.');
    }
    final restoredCompleted = rawCompleted.cast<String>().toSet();

    await _save(
      _srsKey,
      jsonEncode(
        restoredSrs.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
    await _save(
      _customKey,
      jsonEncode(restoredCustom.map((word) => word.toJson()).toList()),
    );
    await _save(
      _savedKey,
      jsonEncode(restoredSaved.map((word) => word.toJson()).toList()),
    );
    await _save(_completedKey, jsonEncode(restoredCompleted.toList()));
    srs.value = restoredSrs;
    custom.value = restoredCustom;
    saved.value = restoredSaved;
    completedMaterials.value = restoredCompleted;
  }

  static Future<void> setMaterialCompleted(String id, bool completed) async {
    final updated = {...completedMaterials.value};
    if (completed) {
      updated.add(id);
    } else {
      updated.remove(id);
    }
    await _save(_completedKey, jsonEncode(updated.toList()));
    completedMaterials.value = updated;
  }

  static Future<void> clearAll() async {
    await _p.remove(_srsKey);
    await _p.remove(_customKey);
    await _p.remove(_savedKey);
    await _p.remove(_completedKey);
    srs.value = {};
    custom.value = [];
    saved.value = [];
    completedMaterials.value = {};
  }

  static List<Vocab> get personalWords {
    final words = <String, Vocab>{};
    for (final word in [...custom.value, ...saved.value]) {
      words.putIfAbsent(word.id, () => word);
    }
    return words.values.toList();
  }

  static bool isPersonal(Vocab v) =>
      custom.value.any((word) => word.id == v.id) ||
      saved.value.any((word) => word.id == v.id);

  static Future<void> togglePersonal(Vocab v) async {
    if (isPersonal(v)) {
      await setCustom(custom.value.where((word) => word.id != v.id).toList());
      await setSaved(saved.value.where((word) => word.id != v.id).toList());
    } else {
      await setSaved([...saved.value, v]);
    }
  }

  static Future<void> putSrs(String id, Srs s) async {
    final updated = {...srs.value, id: s};
    await _save(
      _srsKey,
      jsonEncode(updated.map((k, v) => MapEntry(k, v.toJson()))),
    );
    srs.value = updated;
  }

  static Future<void> _writeSrs() async {
    await _save(
      _srsKey,
      jsonEncode(srs.value.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  static Future<void> setCustom(List<Vocab> words) async {
    final unique = {for (final word in words) word.id: word}.values.toList();
    final retainedSaved = saved.value
        .where((word) => !unique.any((item) => item.id == word.id))
        .toList();
    await _save(_customKey, jsonEncode(unique.map((v) => v.toJson()).toList()));
    await _save(
      _savedKey,
      jsonEncode(retainedSaved.map((v) => v.toJson()).toList()),
    );
    custom.value = unique;
    saved.value = retainedSaved;
  }

  static Future<void> _writeCustom() async {
    await _save(
      _customKey,
      jsonEncode(custom.value.map((v) => v.toJson()).toList()),
    );
  }

  static Future<void> setSaved(List<Vocab> words) async {
    final unique = <String, Vocab>{};
    for (final word in words) {
      if (!custom.value.any((item) => item.id == word.id)) {
        unique[word.id] = word;
      }
    }
    final savedWords = unique.values.toList();
    await _save(
      _savedKey,
      jsonEncode(savedWords.map((v) => v.toJson()).toList()),
    );
    saved.value = savedWords;
  }

  static Future<void> _writeSaved() async {
    await _save(
      _savedKey,
      jsonEncode(saved.value.map((v) => v.toJson()).toList()),
    );
  }

  static Future<void> _save(String key, String value) async {
    if (!await _p.setString(key, value)) {
      throw StateError('Could not persist "$key".');
    }
  }

  /// Insert, or replace in place when the id already exists.
  static Future<void> upsert(Vocab v) async {
    await setCustom([...custom.value.where((word) => word.id != v.id), v]);
  }

  static Future<void> remove(String id) =>
      setCustom(custom.value.where((w) => w.id != id).toList());
}

final Listenable storeChanges = Listenable.merge([
  Store.srs,
  Store.custom,
  Store.saved,
  Store.completedMaterials,
]);
