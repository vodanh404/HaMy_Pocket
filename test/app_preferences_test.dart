import 'package:flutter_test/flutter_test.dart';
import 'package:hamy_poket/services/storage/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads defaults and persists theme and voice selections', () async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.load();

    expect(AppPreferences.darkMode.value, isFalse);
    expect(AppPreferences.voiceSpeaker.value, 0);

    await AppPreferences.setDarkMode(true);
    await AppPreferences.setVoiceSpeaker(2);
    expect(AppPreferences.darkMode.value, isTrue);
    expect(AppPreferences.voiceSpeaker.value, 2);

    await AppPreferences.load();
    expect(AppPreferences.darkMode.value, isTrue);
    expect(AppPreferences.voiceSpeaker.value, 2);
  });

  test('falls back to a valid speaker if a stored ID is unsupported', () async {
    SharedPreferences.setMockInitialValues({'voice_speaker_v1': 7});
    await AppPreferences.load();

    expect(AppPreferences.voiceSpeaker.value, 0);
  });
}
