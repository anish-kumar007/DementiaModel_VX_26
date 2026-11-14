import 'package:material_ui/material_ui.dart';

class AppTheme {
  static const Color backgroundDark = Color(0xFF121212);
  static const Color primaryCardColor = Color(0xFF283593);
  static const Color statusCardColor = Color(0xFF00695C);
  static const Color sosRedColor = Color(0xFFC62828);

  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(fontSize: 22, color: Colors.white),
      ),
    );
  }
}
