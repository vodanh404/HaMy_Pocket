import 'package:flutter/material.dart';

ThemeData buildAppTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.red,
    primary: Colors.red.shade700,
    secondary: Colors.amber.shade700,
  ),
  useMaterial3: true,
  scaffoldBackgroundColor: Colors.grey.shade50,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.red.shade700,
    foregroundColor: Colors.white,
    centerTitle: true,
    elevation: 0,
  ),
);
