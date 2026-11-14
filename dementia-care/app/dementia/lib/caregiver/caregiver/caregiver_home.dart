// app/lib/caregiver/caregiver_home.dart
// Entry point for caregiver mode. B's role guard should open CaregiverHome()
// when users/{uid}.role is 'family' or 'ngo'.
import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'patients/patient_list_screen.dart';
import 'push/push_handler.dart';

class CaregiverHome extends StatefulWidget {
  const CaregiverHome({super.key});
  @override
  State<CaregiverHome> createState() => _CaregiverHomeState();
}

class _CaregiverHomeState extends State<CaregiverHome> {
  @override
  void initState() {
    super.initState();
    // Needs a navigator key so a tap on a push can open the alert.
    CaregiverPush.init(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My family'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: const PatientListScreen(),
    );
  }
}