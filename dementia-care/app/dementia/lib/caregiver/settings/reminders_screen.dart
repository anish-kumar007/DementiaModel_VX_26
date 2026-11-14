// app/lib/caregiver/settings/reminders_screen.dart
// patients/{pid}/reminders/{id}: title, time, repeat, type, active
// ASSUMPTION: time is stored as "HH:mm" (24 h) and repeat as "daily" or "once".
// Confirm with C, who schedules the local alarms from these docs.
// This is the first feature to cut after the NGO view.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key, required this.pid});
  final String pid;

  CollectionReference<Map<String, dynamic>> get _col =>
      patientRef(pid).collection('reminders');

  static const _types = {
    'medication': 'Medication',
    'hydration': 'Water',
    'game': 'Play a game',
  };

  Future<void> _edit(BuildContext context,
      [DocumentSnapshot<Map<String, dynamic>>? doc]) async {
    final d = doc?.data() ?? {};
    final title = TextEditingController(text: d['title'] ?? '');
    var type = (d['type'] as String?) ?? 'medication';
    var repeat = (d['repeat'] as String?) ?? 'daily';
    var time = _parse(d['time'] as String?) ?? const TimeOfDay(hour: 9, minute: 0);

    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(doc == null ? 'Add reminder' : 'Edit reminder'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: title,
                  decoration: const InputDecoration(
                      labelText: 'Message (e.g. Take your tablet)')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: [
                  for (final e in _types.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setS(() => type = v ?? type),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Time: ${time.format(c)}'),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final t =
                      await showTimePicker(context: c, initialTime: time);
                  if (t != null) setS(() => time = t);
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: repeat,
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Every day')),
                  DropdownMenuItem(value: 'once', child: Text('Once')),
                ],
                onChanged: (v) => setS(() => repeat = v ?? repeat),
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
    if (title.text.trim().isEmpty) {
      if (context.mounted) snack(context, 'Please write the message.');
      return;
    }
    final data = {
      'title': title.text.trim(),
      'type': type,
      'repeat': repeat,
      'time': _fmt(time),
      'active': d['active'] ?? true,
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

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay? _parse(String? s) {
    if (s == null) return null;
    final p = s.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No reminders yet. Tap + to add.'));
          }
          return ListView(children: [
            for (final d in docs)
              SwitchListTile(
                title: Text(d.data()['title'] ?? ''),
                subtitle: Text(
                    '${d.data()['time'] ?? ''}  ·  ${_types[d.data()['type']] ?? ''}'
                    '  ·  ${d.data()['repeat'] == 'once' ? 'Once' : 'Every day'}'),
                value: d.data()['active'] != false,
                onChanged: (v) => d.reference.update({'active': v}),
                secondary: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _edit(context, d),
                ),
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