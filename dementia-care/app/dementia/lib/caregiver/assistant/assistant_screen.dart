// lib/caregiver/assistant/assistant_screen.dart
//
// The caregiver's "Ask about <patient>" screen. Answers come from
// CareInsights, which reads the same Firestore records as the rest of the
// caregiver module, plus the patient's own voice-assistant turns.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';
import '../data/caregiver_repository.dart';
import 'care_insights.dart';

class _Turn {
  _Turn(this.question, this.reply);

  final String question;
  final String reply;
}

class CareAssistantScreen extends StatefulWidget {
  const CareAssistantScreen({super.key, required this.pid});

  final String pid;

  @override
  State<CareAssistantScreen> createState() => _CareAssistantScreenState();
}

class _CareAssistantScreenState extends State<CareAssistantScreen> {
  final List<StreamSubscription<dynamic>> _subs = [];
  final List<_Turn> _turns = [];
  final TextEditingController _input = TextEditingController();

  Map<String, dynamic> _patient = {};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sessions = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _alerts = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _locations = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _reminders = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _contacts = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _chats = [];

  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();

    _subs.add(CaregiverRepo.patient(widget.pid).listen(
      (snap) => setState(() {
        _patient = snap.data() ?? {};
        _ready = true;
      }),
      onError: _onError,
    ));
    _subs.add(CaregiverRepo.sessions(widget.pid, limit: 200).listen(
      (snap) => setState(() => _sessions = snap.docs),
      onError: _onError,
    ));
    _subs.add(CaregiverRepo.alerts(widget.pid, limit: 50).listen(
      (snap) => setState(() => _alerts = snap.docs),
      onError: _onError,
    ));
    _subs.add(CaregiverRepo.locationLogs(widget.pid, limit: 50).listen(
      (snap) => setState(() => _locations = snap.docs),
      onError: _onError,
    ));
    _subs.add(CaregiverRepo.reminders(widget.pid).listen(
      (snap) => setState(() => _reminders = snap.docs),
      onError: _onError,
    ));
    _subs.add(CaregiverRepo.contacts(widget.pid).listen(
      (snap) => setState(() => _contacts = snap.docs),
      onError: _onError,
    ));
    _subs.add(CaregiverRepo.assistantChats(widget.pid, limit: 10).listen(
      (snap) => setState(() => _chats = snap.docs),
      onError: _onError,
    ));
  }

  void _onError(Object error) {
    if (!mounted) return;
    setState(() => _error = friendlyError(error));
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _input.dispose();
    super.dispose();
  }

  CareContext get _context => CareContext.fromDocs(
        patient: _patient,
        sessions: _sessions,
        alerts: _alerts,
        locations: _locations,
        reminders: _reminders,
        contacts: _contacts,
        chats: _chats,
      );

  Future<void> _ask(String question) async {
    final text = question.trim();
    if (text.isEmpty) return;
    final reply = CareInsights.answer(text, _context);
    setState(() {
      _turns.insert(0, _Turn(text, reply));
      _input.clear();
    });
    try {
      await CaregiverRepo.saveAssistantTurn(
        pid: widget.pid,
        question: text,
        reply: reply,
      );
    } catch (_) {
      // The answer stays on screen even if the log write is blocked.
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = strOf(_patient['name'], 'this patient');

    return Scaffold(
      backgroundColor: Cg.surface,
      appBar: AppBar(
        backgroundColor: Cg.navy,
        foregroundColor: Colors.white,
        title: const Text('Care assistant'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Cg.navy, Cg.blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Ask about $name',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Answers are built from $name\'s saved records: games, '
                        'alerts, location, reminders and the profile. Nothing '
                        'is sent to an AI provider.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorNote(message: _error!),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final q in CareInsights.quickQuestions)
                      ActionChip(
                        label: Text(q, style: const TextStyle(fontSize: 12)),
                        onPressed: () => _ask(q),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Cg.cardBorder),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_chats.isNotEmpty) _PatientAssistantCard(chats: _chats),
                if (!_ready)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                for (final turn in _turns) _TurnCard(turn: turn),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Cg.cardBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _ask,
                      decoration: InputDecoration(
                        hintText: 'Ask about location, games, alerts…',
                        isDense: true,
                        filled: true,
                        fillColor: Cg.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _ask(_input.text),
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(backgroundColor: Cg.navy),
                    tooltip: 'Ask',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnCard extends StatelessWidget {
  const _TurnCard({required this.turn});

  final _Turn turn;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Cg.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Cg.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  turn.question,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Cg.slate,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            turn.reply,
            style: const TextStyle(fontSize: 14, height: 1.45, color: Cg.ink),
          ),
        ],
      ),
    );
  }
}

class _PatientAssistantCard extends StatelessWidget {
  const _PatientAssistantCard({required this.chats});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> chats;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'From the patient\'s voice assistant',
      icon: Icons.record_voice_over,
      accent: Cg.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final doc in chats
              .where((doc) => doc.data()['source'] != 'caregiver')
              .take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '“${strOf(doc.data()['question'], 'no question')}”',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Cg.ink,
                    ),
                  ),
                  Text(
                    '${strOf(doc.data()['reply'], 'no reply')} · '
                    '${timeAgo(dateField(doc.data(), 'time'))}',
                    style: const TextStyle(fontSize: 12, color: Cg.slate),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Cg.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9F1239)),
            ),
          ),
        ],
      ),
    );
  }
}
