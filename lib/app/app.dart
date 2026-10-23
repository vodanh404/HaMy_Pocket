import 'package:flutter/material.dart';

import '../services/speech/speech_service.dart';
import 'app_router.dart';
import 'app_theme.dart';

class ChineseLearningApp extends StatelessWidget {
  const ChineseLearningApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Học Tiếng Trung',
    scaffoldMessengerKey: messengerKey,
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: const MainNavigator(),
  );
}
