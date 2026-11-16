// lib/caregiver/profile/patient_profile_editor_screen.dart
//
// 7) Access for the caregiver to change the patient profile, with an audit
// trail so both sides can see who changed what.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';
import '../data/caregiver_repository.dart';

class PatientProfileEditorScreen extends StatefulWidget {
  const PatientProfileEditorScreen({super.key, required this.pid});

  final String pid;

  @override
  State<PatientProfileEditorScreen> createState() =>
      _PatientProfileEditorScreenState();
}

class _PatientProfileEditorScreenState
    extends State<PatientProfileEditorScreen> {
  final Map<String, TextEditingController> _controllers = {};
  Map<String, dynamic> _patient = {};
  bool _loaded = false;
  bool _saving = false;

  static const _nameField = ProfileField('name', 'Full name');

  @override
  void initState() {
    super.initState();
    for (final field in [_nameField, ...caregiverEditableProfileFields]) {
      _controllers[field.key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _populate(Map<String, dynamic> patient) {
    _patient = patient;
    if (_loaded) return;
    for (final entry in _controllers.entries) {
      entry.value.text = strOf(patient[entry.key]);
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final name = _controllers['name']!.text.trim();
    if (name.isEmpty) {
      snack(context, 'The patient name cannot be empty.');
      return;
    }

    setState(() => _saving = true);
    try {
      final values = <String, dynamic>{
        for (final entry in _controllers.entries) entry.key: entry.value.text.trim(),
      };
      await CaregiverRepo.saveProfile(
        pid: widget.pid,
        values: values,
        previous: _patient,
      );
      if (!mounted) return;
      snack(context, 'Profile saved. The patient app shows this immediately.');
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      snack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cg.surface,
      appBar: AppBar(
        backgroundColor: Cg.navy,
        foregroundColor: Colors.white,
        title: const Text('Patient profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: CaregiverRepo.patient(widget.pid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(friendlyError(snap.error!)));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          _populate(snap.data!.data() ?? {});

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InfoCard(
                title: 'Care details',
                icon: Icons.edit_note,
                child: Column(
                  children: [
                    for (final field in [_nameField, ...caregiverEditableProfileFields])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: _controllers[field.key],
                          maxLines: field.multiline ? 3 : 1,
                          minLines: 1,
                          keyboardType: field.key == 'age'
                              ? TextInputType.number
                              : (field.key.contains('Phone')
                                  ? TextInputType.phone
                                  : TextInputType.text),
                          decoration: InputDecoration(
                            labelText: field.label,
                            helperText: field.hint,
                            helperMaxLines: 2,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const InfoCard(
                title: 'What the patient sees',
                icon: Icons.sync_alt,
                accent: Cg.teal,
                child: Text(
                  'These fields are the same document the patient app reads for '
                  'the profile screen and the SOS contact. Saving here updates '
                  'the patient phone straight away.',
                  style: TextStyle(fontSize: 12, color: Cg.slate, height: 1.4),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Change log',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Cg.ink,
                ),
              ),
              const SizedBox(height: 8),
              ProfileChangeLog(pid: widget.pid),
              const SizedBox(height: 16),
              Text(
                disclaimer,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Cg.muted),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ProfileChangeLog extends StatelessWidget {
  const ProfileChangeLog({super.key, required this.pid, this.limit = 8});

  final String pid;
  final int limit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: CaregiverRepo.profileChanges(pid),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            friendlyError(snap.error!),
            style: const TextStyle(fontSize: 12, color: Cg.red),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            message: 'No profile changes yet',
            hint: 'Edits from the patient or a caregiver are listed here.',
          );
        }

        return Column(
          children: [
            for (final doc in docs.take(limit)) _ChangeTile(data: doc.data()),
          ],
        );
      },
    );
  }
}

class _ChangeTile extends StatelessWidget {
  const _ChangeTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final changes = data['changes'];
    final entries = <MapEntry<String, dynamic>>[];
    if (changes is Map) {
      for (final entry in changes.entries) {
        entries.add(MapEntry(entry.key.toString(), entry.value));
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Cg.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                data['editorRole'] == 'caregiver'
                    ? Icons.supervisor_account
                    : Icons.person,
                size: 16,
                color: Cg.navy,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${strOf(data['editorName'], 'Someone')} '
                  '(${strOf(data['editorRole'], 'unknown role')})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Cg.ink,
                  ),
                ),
              ),
              Text(
                timeAgo(toDate(data['at'])),
                style: const TextStyle(fontSize: 11, color: Cg.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (entries.isEmpty)
            const Text(
              'No field details recorded.',
              style: TextStyle(fontSize: 12, color: Cg.slate),
            )
          else
            for (final entry in entries.take(6))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${_label(entry.key)}: ${_value(entry.value, 'from')} → '
                  '${_value(entry.value, 'to')}',
                  style: const TextStyle(fontSize: 12, color: Cg.slate),
                ),
              ),
        ],
      ),
    );
  }

  static String _label(String key) {
    for (final field in caregiverEditableProfileFields) {
      if (field.key == key) return field.label;
    }
    return key == 'name' ? 'Full name' : key;
  }

  static String _value(dynamic entry, String side) {
    if (entry is Map) {
      final value = entry[side];
      final text = strOf(value);
      return text.isEmpty ? 'empty' : text;
    }
    return 'empty';
  }
}
