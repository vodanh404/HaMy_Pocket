import 'package:flutter/foundation.dart';

import '../speech/speech_service.dart';

class AudioService {
  const AudioService();

  Future<void> playChineseSample(String text) async {
    if (text.trim().isEmpty) {
      debugPrint('Skipped playback because the Chinese sample is empty.');
      return;
    }
    await speak(text);
  }
}
