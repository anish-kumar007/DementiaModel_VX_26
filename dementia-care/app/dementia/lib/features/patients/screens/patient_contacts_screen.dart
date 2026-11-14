import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';

class PatientContactsScreen extends StatelessWidget {
  const PatientContactsScreen({super.key});

  final List<Map<String, String>> _contacts = const [
    {'name': 'Primary Caregiver (Aarav)', 'phone': '+919876543210', 'role': 'Son'},
    {'name': 'Dr. Sharma (Clinic)', 'phone': '+919112233445', 'role': 'Doctor'},
    {'name': 'Emergency Helpline', 'phone': '112', 'role': 'SOS'},
  ];

  Future<void> _makeCall(BuildContext context, String phoneNumber) async {
    final callUri = Uri.parse('tel:$phoneNumber');
    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch phone call.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching call: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Important Contacts'),
        backgroundColor: Colors.blueGrey.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView.builder(
          itemCount: _contacts.length,
          itemBuilder: (context, index) {
            final contact = _contacts[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade900,
                  padding: const EdgeInsets.all(20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.tealAccent, width: 1.5),
                  ),
                ),
                onPressed: () => _makeCall(context, contact['phone']!),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact['name']!,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Role: ${contact['role']}',
                          style: const TextStyle(fontSize: 16, color: Colors.tealAccent),
                        ),
                      ],
                    ),
                    const Icon(Icons.phone_in_talk, size: 36, color: Colors.tealAccent),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
