import 'package:flutter/material.dart';

import 'app.dart';

class AppStartupScreen extends StatefulWidget {
  const AppStartupScreen({
    super.key,
    required this.initialize,
    this.app = const ChineseLearningApp(),
  });

  final Future<void> Function() initialize;
  final Widget app;

  @override
  State<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen> {
  Object? _initializationError;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    try {
      await widget.initialize();
      if (!mounted) return;
      setState(() {
        _initializationError = null;
        _initialized = true;
      });
    } on Object catch (error, stackTrace) {
      debugPrint('Application startup failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _initializationError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized) return widget.app;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _initializationError == null
                      ? 'Đang chuẩn bị dữ liệu học...'
                      : 'Không thể khởi động ứng dụng',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_initializationError == null)
                  const CircularProgressIndicator()
                else ...[
                  Text(
                    'Đã xảy ra lỗi khi tải dữ liệu: $_initializationError',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _initializationError = null);
                      _initialize();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
