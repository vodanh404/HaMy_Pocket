import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

// --- AUDIO (native zh-CN text-to-speech) ---

final FlutterTts _tts = FlutterTts();
final messengerKey = GlobalKey<ScaffoldMessengerState>();
bool _ttsInitialized = false;

const _noVoiceMsg =
    'Máy chưa có giọng đọc tiếng Trung. Vào Cài đặt › Chuyển văn bản thành giọng nói '
    '(Google TTS) và tải dữ liệu giọng “Tiếng Trung”.';
const _noWindowsVoiceMsg =
    'Windows chưa có giọng đọc tiếng Trung. Vào Cài đặt › Time & language › Language & region, '
    'thêm Tiếng Trung và cài đặt thành phần Speech.';
const _speechRate = 1.0;

void _ttsHint(String m) => messengerKey.currentState
  ?..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m)));

Future<bool> _selectWindowsChineseVoice() async {
  final voices = await _tts.getVoices;
  if (voices is! List) {
    debugPrint('TTS returned an invalid Windows voice list: $voices');
    return false;
  }

  final chineseVoices = <Map<String, String>>[];
  for (final voice in voices) {
    if (voice is Map && voice['locale'] is String && voice['name'] is String) {
      final locale = voice['locale'] as String;
      if (locale.toLowerCase().startsWith('zh')) {
        chineseVoices.add({'locale': locale, 'name': voice['name'] as String});
      }
    }
  }

  if (chineseVoices.isEmpty) return false;
  chineseVoices.sort((a, b) {
    int rank(String locale) {
      final normalized = locale.toLowerCase();
      if (normalized == 'zh-cn') return 0;
      if (normalized.startsWith('zh-hans')) return 1;
      return 2;
    }

    return rank(a['locale']!).compareTo(rank(b['locale']!));
  });

  return await _tts.setVoice(chineseVoices.first) == 1;
}

Future<bool> initTts({bool showErrors = false}) async {
  if (_ttsInitialized) return true;

  try {
    _tts.setErrorHandler((error) {
      debugPrint('TTS playback error: $error');
      _ttsHint(
        'Không phát được âm thanh. Kiểm tra giọng đọc tiếng Trung và âm lượng.',
      );
    });
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Play through the speaker even when the silent switch is on.
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ]);
    }
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final hasChineseVoice = isWindows
        ? await _selectWindowsChineseVoice()
        : await _tts.isLanguageAvailable('zh-CN') == true &&
              await _tts.setLanguage('zh-CN') == 1;
    if (!hasChineseVoice) {
      if (showErrors) {
        _ttsHint(isWindows ? _noWindowsVoiceMsg : _noVoiceMsg);
      }
      return false;
    }
    // Android maps Flutter's 0.5 rate to the platform's normal 1.0 rate.
    final rate =
        !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS)
        ? _speechRate / 2
        : _speechRate;
    await _tts.setSpeechRate(rate);
    await _tts.setVolume(1.0);
    _ttsInitialized = true;
    return true;
  } catch (error) {
    debugPrint('TTS initialization failed: $error');
    if (showErrors) {
      _ttsHint('Không khởi động được bộ đọc: $error');
    }
    return false;
  }
}

Future<void> speak(String text) async {
  if (text.trim().isEmpty) return;
  try {
    if (!await initTts(showErrors: true)) return;
    await _tts.stop();
    if (await _tts.speak(text) != 1) {
      _ttsHint('Không phát được âm thanh. Kiểm tra âm lượng và thử lại.');
    }
  } catch (error) {
    debugPrint('TTS playback failed: $error');
    _ttsHint('Không phát được âm thanh. Kiểm tra giọng đọc và thử lại.');
  }
}
