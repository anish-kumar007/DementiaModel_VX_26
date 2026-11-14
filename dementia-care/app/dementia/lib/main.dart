import 'package:material_ui/material_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// We hide GlobalMaterialLocalizations here so it doesn't conflict with material_ui
import 'package:flutter_localizations/flutter_localizations.dart' hide GlobalMaterialLocalizations;

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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate, // This now safely comes from material_ui
        GlobalWidgetsLocalizations.delegate,  // This comes from flutter_localizations
        // We removed GlobalCupertinoLocalizations because it was causing the deprecation error
      ],
      supportedLocales: const [
        Locale('en', ''),
      ],
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(authSnapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                String role = userSnapshot.data!['role'];
                if (role == 'patient') {
                  return const PatientHomeScreen();
                } else {
                  return const CaregiverHome();
                }
              } else {
                return const LoginScreen();
              }
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}