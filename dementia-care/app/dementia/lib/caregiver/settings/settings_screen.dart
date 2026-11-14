// app/lib/caregiver/settings/settings_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';
import 'contacts_screen.dart';
import 'reminders_screen.dart';
import 'safe_zone_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.pid});
  final String pid;

  Future<void> _revoke(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Stop seeing this patient?'),
        content: const Text(
            'You will no longer see their status, location or alerts. '
            'You can link again later with a new code.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Remove my access')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // Removes only my own uid. The rules must allow this (ask A).
      await patientRef(pid).update({
        'caregivers': FieldValue.arrayRemove([myUid]),
      });
      if (context.mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (_) {
      if (context.mounted) snack(context, 'Could not remove access. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    void go(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Safe zone'),
            subtitle: const Text('Pick the centre and radius on the map'),
            onTap: () => go(SafeZoneScreen(pid: pid)),
          ),
          ListTile(
            leading: const Icon(Icons.alarm),
            title: const Text('Reminders'),
            subtitle: const Text('Medication, water, games'),
            onTap: () => go(RemindersScreen(pid: pid)),
          ),
          ListTile(
            leading: const Icon(Icons.contacts),
            title: const Text('Contacts and doctor'),
            subtitle: const Text('Who the patient can call'),
            onTap: () => go(ContactsScreen(pid: pid)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.link_off, color: Color(0xFFC62828)),
            title: const Text('Revoke my access'),
            onTap: () => _revoke(context),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(disclaimer, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}