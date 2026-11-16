// lib/caregiver/caregiver_home.dart
//
// Entry point for caregiver mode. AuthWrapper opens this when
// users/{uid}.role is 'family' or 'ngo'.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'common.dart';
import 'data/caregiver_repository.dart';
import 'patients/patient_list_screen.dart';
import 'push/push_handler.dart';

class CaregiverHome extends StatefulWidget {
  const CaregiverHome({super.key});

  @override
  State<CaregiverHome> createState() => _CaregiverHomeState();
}

class _CaregiverHomeState extends State<CaregiverHome> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Handles taps on SOS / safe-zone push notifications.
    CaregiverPush.init(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          PatientListScreen(),
          _AccountTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Family',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class _AccountTab extends StatelessWidget {
  const _AccountTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Cg.surface,
      appBar: AppBar(
        backgroundColor: Cg.navy,
        foregroundColor: Colors.white,
        title: const Text('Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Cg.cardBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Cg.navy.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, color: Cg.navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String>(
                        future: CaregiverRepo.caregiverName(),
                        builder: (context, snap) => Text(
                          snap.data ?? 'Caregiver',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Cg.ink,
                          ),
                        ),
                      ),
                      Text(
                        user?.email ?? 'not signed in',
                        style: const TextStyle(fontSize: 12, color: Cg.slate),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: CaregiverRepo.myPatients(),
            builder: (context, snap) {
              final count = snap.data?.docs.length;
              return InfoCard(
                title: 'Linked patients',
                icon: Icons.family_restroom,
                child: Text(
                  count == null
                      ? 'Loading…'
                      : '$count patient${count == 1 ? '' : 's'} linked to this account.',
                  style: const TextStyle(color: Cg.slate),
                ),
              );
            },
          ),
          InfoCard(
            title: 'How access works',
            icon: Icons.lock_outline,
            accent: Cg.teal,
            child: const Text(
              'A patient adds you by approving a one-time 6-digit code. Only '
              'linked caregivers can read that patient\'s sessions, alerts and '
              'location. You can remove your own access from the patient\'s '
              'screen at any time.',
              style: TextStyle(fontSize: 13, color: Cg.slate, height: 1.4),
            ),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Cg.red,
              side: const BorderSide(color: Cg.red),
              minimumSize: const Size(0, 48),
            ),
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 16),
          Text(
            disclaimer,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Cg.muted),
          ),
        ],
      ),
    );
  }
}
