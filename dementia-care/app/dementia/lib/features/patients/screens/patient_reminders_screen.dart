import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../../services/reminder_utils.dart';
import '../services/reminder_notification_service.dart';

/// Reads the reminders the caregiver sets in the caregiver app
/// (patients/{pid}/reminders) and lets the patient tick them off.
class PatientRemindersScreen extends StatefulWidget {
  final bool isHindi;
  const PatientRemindersScreen({super.key, this.isHindi = false});

  @override
  State<PatientRemindersScreen> createState() => _PatientRemindersScreenState();
}

class _PatientRemindersScreenState extends State<PatientRemindersScreen> {
  final Set<String> _localDone = <String>{};

  static final List<Map<String, dynamic>> _demoFallback = [
    {
      'id': 'demo-medication',
      'time': '09:00',
      'type': 'medication',
      'title': 'Morning Blood Pressure Medicine',
      'titleHi': 'सुबह की ब्लड प्रेशर की दवा',
      'note': 'Take 1 tablet after breakfast with water.',
      'noteHi': 'नाश्ते के बाद पानी के साथ 1 गोली लें।',
      'demo': true,
    },
    {
      'id': 'demo-hydration',
      'time': '13:30',
      'type': 'hydration',
      'title': 'Lunch & Hydration',
      'titleHi': 'दोपहर का भोजन और पानी',
      'note': 'Have lunch and drink a full glass of water.',
      'noteHi': 'दोपहर का भोजन करें और एक पूरा गिलास पानी पिएँ।',
      'demo': true,
    },
    {
      'id': 'demo-game',
      'time': '17:00',
      'type': 'game',
      'title': 'Evening Word & Picture Activity',
      'titleHi': 'शाम का शब्द और चित्र खेल',
      'note': 'Play one short round of Memory Pairs.',
      'noteHi': 'मेमोरी पेयर का एक छोटा दौर खेलें।',
      'demo': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    ReminderNotificationService.initialize(isHindi: widget.isHindi);
  }

  String _t(String en, String hi) => widget.isHindi ? hi : en;

  IconData _typeIcon(String type) {
    switch (type) {
      case 'medication':
        return Icons.medication;
      case 'hydration':
        return Icons.water_drop;
      default:
        return Icons.extension;
    }
  }

  Future<void> _toggleDone(Map<String, dynamic> item, bool isDone) async {
    final id = item['id'] as String?;
    final title = (item['title'] as String?) ?? _t('Reminder', 'रिमाइंडर');
    final demo = item['demo'] == true;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (isDone) {
      setState(() => id == null ? null : _localDone.remove(id));
    } else {
      if (id != null) setState(() => _localDone.add(id));
      if (!demo && uid != null && id != null) {
        try {
          await FirebaseFirestore.instance
              .collection('patients')
              .doc(uid)
              .collection('reminders')
              .doc(id)
              .set({
            'lastDoneOn': ReminderTime.dateKey(DateTime.now()),
            'lastDoneAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {
          // Offline: the tick still shows on screen.
        }
      }
      ReminderNotificationService.speakReminder(
        _t('Great job! $title is done.', 'बहुत बढ़िया! $title पूरा हो गया है।'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      appBar: AppBar(
        title: Text(_t('Daily Reminders', 'दैनिक रिमाइंडर')),
        backgroundColor: Colors.cyan.shade900,
      ),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('patients')
                  .doc(uid)
                  .collection('reminders')
                  .snapshots(),
              builder: (context, snap) {
                final fromCaregiver = (snap.data?.docs ?? [])
                    .map((d) => <String, dynamic>{...d.data(), 'id': d.id})
                    .toList()
                  ..sort(compareReminderTime);

                final visible = fromCaregiver.where((r) => r['active'] != false).toList();
                final items = visible.isEmpty
                    ? [
                        for (final r in _demoFallback)
                          {
                            ...r,
                            'title': widget.isHindi ? r['titleHi'] : r['title'],
                            'note': widget.isHindi ? r['noteHi'] : r['note'],
                          }
                      ]
                    : visible;

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _t('No reminders yet.', 'अभी कोई रिमाइंडर नहीं है।'),
                        style: const TextStyle(fontSize: 20, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final id = item['id'] as String?;
                    final isDone =
                        _localDone.contains(id) || ReminderTime.isDoneToday(item);
                    return _ReminderCard(
                      item: item,
                      isDone: isDone,
                      isHindi: widget.isHindi,
                      icon: _typeIcon((item['type'] as String?) ?? 'medication'),
                      onToggle: () => _toggleDone(item, isDone),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.item,
    required this.isDone,
    required this.isHindi,
    required this.icon,
    required this.onToggle,
  });

  final Map<String, dynamic> item;
  final bool isDone;
  final bool isHindi;
  final IconData icon;
  final VoidCallback onToggle;

  String _t(String en, String hi) => isHindi ? hi : en;

  @override
  Widget build(BuildContext context) {
    final time = ReminderTime.to12h(item['time'] as String?);
    final title = (item['title'] as String?) ?? _t('Reminder', 'रिमाइंडर');
    final note = (item['note'] as String?)?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDone ? Colors.grey.shade900 : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone ? Colors.tealAccent : Colors.amberAccent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.amberAccent, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.volume_up, size: 36, color: Colors.white),
                tooltip: _t('Read Aloud', 'बोलकर सुनाएँ'),
                onPressed: () => ReminderNotificationService.speakReminder(
                  note == null || note.isEmpty ? '$time. $title' : '$time. $title. $note',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDone ? Colors.white60 : Colors.white,
              decoration: isDone ? TextDecoration.lineThrough : null,
            ),
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note, style: const TextStyle(fontSize: 18, color: Colors.white70)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 60,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDone ? Colors.teal.shade800 : Colors.amber.shade900,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onToggle,
              icon: Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 30,
                color: Colors.white,
              ),
              label: Text(
                isDone
                    ? _t('COMPLETED', 'पूरा हुआ')
                    : _t('TAP WHEN DONE', 'पूरा होने पर दबाएँ'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
