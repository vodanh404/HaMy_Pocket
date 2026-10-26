import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const _darkModeKey = 'app_dark_mode_v1';
  static const _voiceSpeakerKey = 'voice_speaker_v1';

  static final darkMode = ValueNotifier<bool>(false);
  static final voiceSpeaker = ValueNotifier<int>(0);
  static SharedPreferences? _preferences;

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _preferences = preferences;
    darkMode.value = preferences.getBool(_darkModeKey) ?? false;
    final speaker = preferences.getInt(_voiceSpeakerKey) ?? 0;
    voiceSpeaker.value = speaker >= 0 && speaker < 3 ? speaker : 0;
  }

  static Future<void> setDarkMode(bool enabled) async {
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    if (!await preferences.setBool(_darkModeKey, enabled)) {
      throw StateError('Could not save the theme preference.');
    }
    darkMode.value = enabled;
  }

  static Future<void> setVoiceSpeaker(int speaker) async {
    if (speaker < 0 || speaker >= 3) {
      throw RangeError.range(speaker, 0, 2, 'speaker');
    }
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    if (!await preferences.setInt(_voiceSpeakerKey, speaker)) {
      throw StateError('Could not save the voice preference.');
    }
    voiceSpeaker.value = speaker;
  }
}
