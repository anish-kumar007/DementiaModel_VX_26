import 'package:flutter/material.dart';
import '../services/reminder_notification_service.dart';

class PatientRemindersScreen extends StatefulWidget {
  const PatientRemindersScreen({super.key});

  @override
  State<PatientRemindersScreen> createState() => _PatientRemindersScreenState();
}

class _PatientRemindersScreenState extends State<PatientRemindersScreen> {
  // Synced from Member D's caregiver reminder editor or cached locally
  final List<Map<String, dynamic>> _reminders = [
    {
      'id': 1,
      'time': '09:00 AM',
      'title': 'Morning Blood Pressure Medicine',
      'note': 'Take 1 blue tablet after breakfast with water.',
      'completed': true,
    },
    {
      'id': 2,
      'time': '01:30 PM',
      'title': 'Lunch & Hydration',
      'note': 'Have lunch and drink a full glass of water.',
      'completed': false,
    },
    {
      'id': 3,
      'time': '08:00 PM',
      'title': 'Evening Walk & Dinner',
      'note': 'Walk inside the safe zone with family.',
      'completed': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    ReminderNotificationService.initialize();
  }

  void _toggleCompleted(int index) {
    setState(() {
      _reminders[index]['completed'] = !_reminders[index]['completed'];
    });
    if (_reminders[index]['completed']) {
      ReminderNotificationService.speakReminder(
        'Great job! Marked ${_reminders[index]['title']} as done.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Reminders'),
        backgroundColor: Colors.amber.shade900,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView.builder(
          itemCount: _reminders.length,
          itemBuilder: (context, index) {
            final item = _reminders[index];
            final isDone = item['completed'] as bool;

            return Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDone ? Colors.grey.shade900 : const Color(0xFF263238),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDone ? Colors.green : Colors.amberAccent,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['time'],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up, size: 36, color: Colors.white),
                        tooltip: 'Read Aloud',
                        onPressed: () {
                          ReminderNotificationService.speakReminder(
                            '${item['time']}. ${item['title']}. ${item['note']}',
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['title'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDone ? Colors.white60 : Colors.white,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['note'],
                    style: const TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDone ? Colors.green.shade800 : Colors.amber.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _toggleCompleted(index),
                    icon: Icon(
                      isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 30,
                      color: Colors.white,
                    ),
                    label: Text(
                      isDone ? 'COMPLETED' : 'TAP WHEN DONE',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
