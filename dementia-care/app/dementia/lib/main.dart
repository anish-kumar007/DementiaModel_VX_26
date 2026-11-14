import 'package:flutter/material.dart'; // Standard Flutter import
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Adjust these paths if your folder structure is slightly different
import 'screens/login_screen.dart';
import 'features/patients/screens/patient_home_screen.dart';
import 'caregiver/caregiver_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // 👇 Changed from LoginScreen to AuthWrapper
      home: const AuthWrapper(), 
    );
  }
}

// 👇 This widget decides which screen to show based on Firebase Auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // 1. Show a loading spinner while Firebase checks the session
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If user IS logged in, fetch their role from Firestore
        if (authSnapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(authSnapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              // Show loading while fetching Firestore data
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // If Firestore data exists, route to the correct home screen
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                String role = userSnapshot.data!['role'];
                if (role == 'patient') {
                  return const PatientHomeScreen();
                } else {
                  return const CaregiverHome();
                }
              } else {
                // Fallback: Auth exists but Firestore doc is missing
                return const LoginScreen();
              }
            },
          );
        }

        // 3. If NO user is logged in, show the Login Screen
        return const LoginScreen();
      },
    );
  }
}