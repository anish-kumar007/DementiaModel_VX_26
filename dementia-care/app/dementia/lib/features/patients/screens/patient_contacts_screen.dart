import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Contacts the caregiver manages in the caregiver app
/// (patients/{pid}/contacts) plus a few safe defaults.
class PatientContactsScreen extends StatelessWidget {
  final bool isHindi;
  const PatientContactsScreen({super.key, this.isHindi = false});

  static const List<Map<String, dynamic>> _fallback = [
    {
      'name': 'Aarav (Son)',
      'nameHi': 'आरव (बेटा)',
      'phone': '+919876543210',
      'relation': 'Primary Caregiver',
      'relationHi': 'मुख्य देखभालकर्ता',
      'isDoctor': false,
      'videoUrl': 'https://meet.jit.si/DementiaCareFamilyDemo',
    },
    {
      'name': 'Dr. Sharma (Clinic)',
      'nameHi': 'डॉ. शर्मा (क्लिनिक)',
      'phone': '+919112233445',
      'relation': 'Family Doctor',
      'relationHi': 'पारिवारिक डॉक्टर',
      'isDoctor': true,
      'videoUrl': '',
    },
    {
      'name': 'Emergency Helpline',
      'nameHi': 'आपातकालीन हेल्पलाइन',
      'phone': '112',
      'relation': 'National Emergency',
      'relationHi': 'राष्ट्रीय आपातकाल',
      'isDoctor': false,
      'videoUrl': '',
    },
  ];

  String _t(String en, String hi) => isHindi ? hi : en;

  Future<void> _launchUri(BuildContext context, Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Could not open action.', 'कार्रवाई नहीं खुल सकी।'))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      appBar: AppBar(
        title: Text(_t('Call Family & Doctor', 'परिवार और डॉक्टर को कॉल')),
        backgroundColor: Colors.blueGrey.shade900,
      ),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('patients')
                  .doc(uid)
                  .collection('contacts')
                  .snapshots(),
              builder: (context, snap) {
                final fromCaregiver = [
                  for (final doc in snap.data?.docs ?? []) doc.data(),
                ];

                final contacts = fromCaregiver.isEmpty
                    ? [
                        for (final c in _fallback)
                          {
                            ...c,
                            'name': isHindi ? c['nameHi'] : c['name'],
                            'relation': isHindi ? c['relationHi'] : c['relation'],
                          }
                      ]
                    : fromCaregiver;

                if (contacts.isEmpty) {
                  return Center(
                    child: Text(
                      _t('No contacts yet.', 'अभी कोई संपर्क नहीं है।'),
                      style: const TextStyle(fontSize: 20, color: Colors.white70),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final isDoctor = contact['isDoctor'] == true;
                    final videoUrl = (contact['videoUrl'] as String?) ?? '';
                    final name = (contact['name'] as String?) ?? 'Contact';
                    final relation = (contact['relation'] as String?) ?? '';
                    final phone = (contact['phone'] as String?) ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDoctor
                            ? const Color(0xFF1A2930)
                            : Colors.blueGrey.shade900,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDoctor ? Colors.amberAccent : Colors.tealAccent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isDoctor
                                    ? Icons.medical_services_outlined
                                    : Icons.person,
                                size: 36,
                                color: isDoctor
                                    ? Colors.amberAccent
                                    : Colors.tealAccent,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (relation.isNotEmpty)
                                      Text(
                                        relation,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isDoctor
                                              ? Colors.amberAccent
                                              : Colors.tealAccent,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 60,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal.shade700,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: phone.isEmpty
                                        ? null
                                        : () => _launchUri(
                                              context,
                                              Uri.parse('tel:$phone'),
                                            ),
                                    icon: const Icon(Icons.call,
                                        size: 28, color: Colors.white),
                                    label: Text(
                                      _t('Call', 'कॉल करें'),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (videoUrl.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 60,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo.shade600,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _launchUri(context, Uri.parse(videoUrl)),
                                      icon: const Icon(Icons.videocam,
                                          size: 28, color: Colors.white),
                                      label: Text(
                                        _t('Video', 'वीडियो'),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
