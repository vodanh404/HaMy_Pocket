import 'package:flutter/material.dart';

import '../services/speech/speech_service.dart';
import '../services/storage/app_preferences.dart';
import 'app_router.dart';
import 'app_theme.dart';

class ChineseLearningApp extends StatelessWidget {
  const ChineseLearningApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: AppPreferences.darkMode,
    builder: (context, darkMode, _) => MaterialApp(
      title: 'HaMy_Pocket',
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(dark: true),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const MainNavigator(),
    ),
  );
}
