import 'package:material_ui/material_ui.dart';
import '../services/reminder_notification_service.dart';

class PatientRemindersScreen extends StatefulWidget {
  final bool isHindi;
  const PatientRemindersScreen({super.key, this.isHindi = false});

  @override
  State<PatientRemindersScreen> createState() => _PatientRemindersScreenState();
}

class _PatientRemindersScreenState extends State<PatientRemindersScreen> {
  final List<Map<String, dynamic>> _reminders = [
    {
      'id': 1,
      'time': '09:00 AM',
      'type': 'medication',
      'titleEn': 'Morning Blood Pressure Medicine',
      'titleHi': 'सुबह की ब्लड प्रेशर की दवा',
      'noteEn': 'Take 1 blue tablet after breakfast with water.',
      'noteHi': 'नाश्ते के बाद पानी के साथ 1 नीली गोली लें।',
      'completed': true,
    },
    {
      'id': 2,
      'time': '01:30 PM',
      'type': 'hydration',
      'titleEn': 'Lunch & Hydration',
      'titleHi': 'दोपहर का भोजन और पानी',
      'noteEn': 'Have lunch and drink a full glass of water.',
      'noteHi': 'दोपहर का भोजन करें और एक पूरा गिलास पानी पिएँ।',
      'completed': false,
    },
    {
      'id': 3,
      'time': '05:00 PM',
      'type': 'game',
      'titleEn': 'Evening Word & Picture Activity',
      'titleHi': 'शाम का शब्द और चित्र खेल',
      'noteEn': 'Play one short round of Word-Picture Match.',
      'noteHi': 'शब्द और चित्र मिलान का एक छोटा दौर खेलें।',
      'completed': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    ReminderNotificationService.initialize();
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

  void _toggleCompleted(int index) {
    setState(() {
      _reminders[index]['completed'] = !_reminders[index]['completed'];
    });
    if (_reminders[index]['completed']) {
      final title = _t(_reminders[index]['titleEn'], _reminders[index]['titleHi']);
      ReminderNotificationService.speakReminder(
        _t('Great job! Marked $title as done.', 'बहुत बढ़िया! $title पूरा हो गया है।'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      appBar: AppBar(
        title: Text(_t('Daily Reminders', 'दैनिक रिमाइंडर')),
        backgroundColor: Colors.cyan.shade900,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20.0),
        itemCount: _reminders.length,
        itemBuilder: (context, index) {
          final item = _reminders[index];
          final isDone = item['completed'] as bool;
          final title = _t(item['titleEn'], item['titleHi']);
          final note = _t(item['noteEn'], item['noteHi']);

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
                        Icon(_typeIcon(item['type']), color: Colors.amberAccent, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          item['time'],
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
                      onPressed: () {
                        ReminderNotificationService.speakReminder('${item['time']}. $title. $note');
                      },
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
                const SizedBox(height: 6),
                Text(note, style: const TextStyle(fontSize: 18, color: Colors.white70)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 60,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDone ? Colors.teal.shade800 : Colors.amber.shade900,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _toggleCompleted(index),
                    icon: Icon(
                      isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 30,
                      color: Colors.white,
                    ),
                    label: Text(
                      isDone ? _t('COMPLETED', 'पूरा हुआ') : _t('TAP WHEN DONE', 'पूरा होने पर दबाएँ'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
