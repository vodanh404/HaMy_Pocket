import 'package:flutter/material.dart';

ThemeData buildAppTheme({bool dark = false}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.red,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: dark ? Colors.red.shade300 : Colors.red.shade700,
    secondary: dark ? Colors.amber.shade300 : Colors.amber.shade700,
  );
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: dark ? colorScheme.surface : Colors.grey.shade50,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? colorScheme.surface : Colors.red.shade700,
      foregroundColor: dark ? colorScheme.onSurface : Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
  );
}
