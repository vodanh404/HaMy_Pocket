import 'package:flutter/material.dart';

import '../domain/services/learning_engine.dart';
import '../domain/services/srs_scheduler.dart';
import '../services/storage/storage_service.dart';
import '../features/dictionary/dictionary_screen.dart';
import '../features/home/home_screen.dart';
import '../features/listening/listening_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/reading/reading_screen.dart';
import '../features/review/review_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/speaking/speaking_screen.dart';
import '../features/writing/typing_practice_screen.dart';

// --- MAIN NAVIGATOR ---
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selected = 0;

  // Built lazily so each tab rebuilds its state (e.g. the SRS queue) when selected.
  Widget _screen(int i) => switch (i) {
    0 => HomeScreen(
      onReview: () => setState(() => _selected = 1),
      onListening: () => _open(const ListeningScreen()),
      onSpeaking: () => _open(const SpeakingScreen()),
      onReading: () => _open(const ReadingScreen()),
      onWriting: () => setState(() => _selected = 3),
      onSettings: () => _open(const SettingsScreen()),
    ),
    1 => const ReviewScreen(),
    2 => const QuizScreen(),
    3 => const TypingPracticeScreen(),
    _ => const DictionaryScreen(),
  };

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screen(_selected),
      bottomNavigationBar: AnimatedBuilder(
        animation: storeChanges,
        builder: (context, _) {
          final pending = buildQueue(
            allWords,
            Store.srs.value,
            DateTime.now(),
          ).length;
          return NavigationBar(
            selectedIndex: _selected,
            onDestinationSelected: (i) => setState(() => _selected = i),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.school),
                label: 'Bài học',
              ),
              NavigationDestination(
                icon: Badge(
                  label: Text('$pending'),
                  isLabelVisible: pending > 0,
                  child: const Icon(Icons.replay_circle_filled),
                ),
                label: 'Ôn tập',
              ),
              const NavigationDestination(
                icon: Icon(Icons.quiz),
                label: 'Kiểm tra',
              ),
              const NavigationDestination(
                icon: Icon(Icons.keyboard),
                label: 'Luyện gõ',
              ),
              const NavigationDestination(
                icon: Icon(Icons.menu_book),
                label: 'Từ điển',
              ),
            ],
          );
        },
      ),
    );
  }
}
