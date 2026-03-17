import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();
  factory ThemeProvider() => _instance;
  ThemeProvider._internal();

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  void toggle() {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: Colors.deepPurple,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.deepPurple,
      unselectedItemColor: Colors.grey,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      indicatorColor: Colors.white,
    ),
    dividerColor: Colors.grey,
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: Colors.deepPurple,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E2E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E2E),
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E1E2E),
      selectedItemColor: Colors.deepPurpleAccent,
      unselectedItemColor: Colors.grey,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      indicatorColor: Colors.white,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: Colors.white,
      iconColor: Colors.white70,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Colors.white70),
      titleMedium: TextStyle(color: Colors.white),
    ),
    iconTheme: const IconThemeData(color: Colors.white70),
    dividerColor: Colors.white24,
    inputDecorationTheme: const InputDecorationTheme(
      labelStyle: TextStyle(color: Colors.white70),
      hintStyle: TextStyle(color: Colors.white38),
      border: OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
    ),
  );
}