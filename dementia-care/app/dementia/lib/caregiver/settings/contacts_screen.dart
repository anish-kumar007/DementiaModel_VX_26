// app/lib/caregiver/settings/contacts_screen.dart
// patients/{pid}/contacts/{id}: name, phone, relation, isDoctor
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key, required this.pid});
  final String pid;

  CollectionReference<Map<String, dynamic>> get _col =>
      patientRef(pid).collection('contacts');

  Future<void> _edit(BuildContext context,
      [DocumentSnapshot<Map<String, dynamic>>? doc]) async {
    final d = doc?.data() ?? {};
    final name = TextEditingController(text: d['name'] ?? '');
    final phone = TextEditingController(text: d['phone'] ?? '');
    final relation = TextEditingController(text: d['relation'] ?? '');
    var isDoctor = d['isDoctor'] == true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(doc == null ? 'Add contact' : 'Edit contact'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name')),
              TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone')),
              TextField(
                  controller: relation,
                  decoration: const InputDecoration(
                      labelText: 'Relation (son, daughter...)')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('This is the doctor'),
                value: isDoctor,
                onChanged: (v) => setS(() => isDoctor = v),
              ),
            ]),
          ),
          actions: [
            if (doc != null)
              TextButton(
                onPressed: () async {
                  await doc.reference.delete();
                  if (c.mounted) Navigator.pop(c, false);
                },
                child: const Text('Delete'),
              ),
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
      if (context.mounted) snack(context, 'Name and phone are needed.');
      return;
    }
    final data = {
      'name': name.text.trim(),
      'phone': phone.text.trim(),
      'relation': relation.text.trim(),
      'isDoctor': isDoctor,
    };
    try {
      if (doc == null) {
        await _col.add(data);
      } else {
        await doc.reference.update(data);
      }
    } catch (_) {
      if (context.mounted) snack(context, 'Could not save. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts and doctor')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No contacts yet. Tap + to add.'));
          }
          return ListView(children: [
            for (final d in docs)
              ListTile(
                leading: Icon(d.data()['isDoctor'] == true
                    ? Icons.medical_services
                    : Icons.person),
                title: Text(d.data()['name'] ?? ''),
                subtitle: Text(
                    '${d.data()['relation'] ?? ''}  ${d.data()['phone'] ?? ''}'),
                onTap: () => _edit(context, d),
              ),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}