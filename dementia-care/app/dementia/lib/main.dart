import 'package:flutter/material.dart';
import 'screens/login_screen.dart'; // Ensure this matches your folder structure

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dementia Care',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // This is the correct syntax for the color scheme
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // This points to your new login screen
      home: const LoginScreen(), 
    );
  }
}