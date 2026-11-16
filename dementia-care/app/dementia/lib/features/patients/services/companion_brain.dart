// lib/features/patients/services/companion_brain.dart
//
// The patient's companion. It answers immediately from data already on the
// phone: the patient profile (name, caregiver, home address), the caregiver's
// reminders and the saved contacts. No network, no AI provider, no cost, and it
// keeps working when the phone is offline — which matters for a patient who may
// be confused or alone.
//
// It is deliberately not a general chatbot: it recognises a handful of everyday
// needs, gives one short calm answer, and points back to a human (caregiver,
// contact, SOS) for anything medical or unknown.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/reminder_utils.dart';

class CompanionReply {
  const CompanionReply(
    this.text, {
    this.suggestions = const [],
    this.callName,
    this.callPhone,
  });

  final String text;

  /// Follow-up questions offered as big tap-able chips.
  final List<String> suggestions;

  /// When set, the screen offers a large "Call …" button.
  final String? callName;
  final String? callPhone;
}

class CompanionContext {
  const CompanionContext({
    this.patient = const {},
    this.reminders = const [],
    this.contacts = const [],
  });

  final Map<String, dynamic> patient;
  final List<Map<String, dynamic>> reminders;
  final List<Map<String, dynamic>> contacts;

  static Future<CompanionContext> load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const CompanionContext();
    try {
      final db = FirebaseFirestore.instance;
      final patientDoc = db.collection('patients').doc(user.uid);
      final results = await Future.wait<dynamic>([
        patientDoc.get(),
        patientDoc.collection('reminders').get(),
        patientDoc.collection('contacts').get(),
      ]);
      final patient = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final reminders = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final contacts = results[2] as QuerySnapshot<Map<String, dynamic>>;
      return CompanionContext(
        patient: patient.data() ?? const {},
        reminders: [for (final doc in reminders.docs) doc.data()],
        contacts: [for (final doc in contacts.docs) doc.data()],
      );
    } catch (_) {
      // Offline on first run: answer with the gentle defaults instead of failing.
      return const CompanionContext();
    }
  }

  static String _text(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String get name => _text(patient['name']);

  String get preferred {
    final p = _text(patient['preferredName']);
    return p.isEmpty ? name : p;
  }

  String get caregiver {
    final c = _text(patient['caregiverName']);
    return c.isEmpty ? _text(patient['doctorName']) : c;
  }

  String get caregiverPhone => _text(patient['caregiverPhone']);

  String get homeAddress => _text(patient['homeAddress']);

  String get languages => _text(patient['languages']);
}

class CompanionBrain {
  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  static CompanionReply reply(
    String query, {
    required CompanionContext context,
    required bool isHindi,
  }) {
    final q = _normalise(query);

    String say(String en, String hi) => isHindi ? hi : en;

    if (q.isEmpty) {
      return CompanionReply(
        say(
          'I am listening. Tap the microphone and say what you need.',
          'मैं सुन रहा हूँ। माइक दबाएँ और बताएँ कि आपको क्या चाहिए।',
        ),
        suggestions: suggestions(context: context, isHindi: isHindi),
      );
    }

    // Greetings first, so "hello" never falls through to a random intent.
    if (_any(q, ['hello', 'hi ', 'hey', 'namaste', 'नमस्ते', 'नमस्कार']) && q.length < 24) {
      final who = context.preferred;
      return CompanionReply(
        who.isEmpty
            ? say('Hello! I am here with you. What do you need?',
                'नमस्ते! मैं आपके साथ हूँ। आपको क्या चाहिए?')
            : say('Hello $who. I am here with you. What do you need?',
                'नमस्ते $who। मैं आपके साथ हूँ। आपको क्या चाहिए?'),
        suggestions: suggestions(context: context, isHindi: isHindi),
      );
    }

    if (_any(q, ['thank', 'thanks', 'धन्यवाद', 'शुक्रिया'])) {
      return CompanionReply(
        say('You are welcome. I am always here.', 'कोई बात नहीं। मैं हमेशा यहाँ हूँ।'),
        suggestions: suggestions(context: context, isHindi: isHindi),
      );
    }

    // A named contact ("call Asha", "my son", "आरव को कॉल") wins over generic talk.
    final contact = _matchContact(q, context);
    if (contact != null && _any(q, ['call', 'phone', 'कॉल', 'फोन', 'बात'])) {
      final name = _text(contact['name']);
      final phone = _text(contact['phone']);
      if (phone.isNotEmpty) {
        return CompanionReply(
          say('Calling $name now.', 'अभी $name को कॉल कर रहा हूँ।'),
          callName: name,
          callPhone: phone,
          suggestions: suggestions(context: context, isHindi: isHindi),
        );
      }
    }

    if (_any(q, ['sos', 'emergency', 'urgent', 'help me', 'मदद', 'आपात', 'बचाओ'])) {
      return CompanionReply(
        say(
          'If you need help right now, tap the big red SOS button on your home '
          'screen. It alerts your caregiver at once.',
          'अगर आपको अभी मदद चाहिए, तो होम स्क्रीन पर बड़ा लाल SOS बटन दबाएँ। '
          'यह तुरंत आपके देखभालकर्ता को सूचित कर देगा।',
        ),
        callName: context.caregiver.isEmpty ? null : context.caregiver,
        callPhone: context.caregiverPhone.isEmpty ? null : context.caregiverPhone,
        suggestions: suggestions(context: context, isHindi: isHindi),
      );
    }

    // Feelings: no advice, just warmth and a person to reach.
    if (_any(q, [
      'sad',
      'lonely',
      'scared',
      'afraid',
      'worried',
      'anxious',
      'tired',
      'upset',
      'अकेला',
      'डर',
      'उदास',
      'परेशान',
      'थक',
    ])) {
      final name = context.caregiver;
      final text = isHindi
          ? (name.isEmpty
              ? 'मैं समझ सकता हूँ। आप अकेले नहीं हैं। धीरे से गहरी साँस लें। क्या आप किसी अपने को कॉल करना चाहेंगे?'
              : 'मैं समझ सकता हूँ। आप अकेले नहीं हैं। धीरे से गहरी साँस लें। $name को कॉल करें?')
          : (name.isEmpty
              ? 'I understand. You are not alone. Take one slow, gentle breath. '
                  'Would you like to call someone you trust?'
              : 'I understand. You are not alone. Take one slow, gentle breath. '
                  'Would you like to call $name?');
      final phone = context.caregiverPhone;
      return CompanionReply(
        text,
        callName: name.isEmpty || phone.isEmpty ? null : name,
        callPhone: name.isEmpty || phone.isEmpty ? null : phone,
        suggestions: suggestions(context: context, isHindi: isHindi),
      );
    }

    if (_any(q, ['time', 'clock', 'बजे', 'समय', 'टाइम'])) {
      return _timeReply(context, isHindi);
    }

    if (_any(q, ['date', 'today', 'day is', 'तारीख', 'दिन', 'आज'])) {
      return _dateReply(context, isHindi);
    }

    if (_any(q, [
      'medicine',
      'medication',
      'tablet',
      'pill',
      'dose',
      'दवा',
      'दवाई',
      'गोली',
    ])) {
      return _medicineReply(context, isHindi);
    }

    if (_any(q, ['remind', 'water', 'पानी', 'रिमाइंडर', 'खाना', 'food', 'lunch', 'breakfast'])) {
      return _reminderReply(context, isHindi);
    }

    if (_any(q, ['call', 'phone', 'कॉल', 'फोन'])) {
      return _callHelp(context, isHindi);
    }

    if (_any(q, ['caregiver', 'family', 'देखभाल', 'परिवार', 'बेटा', 'बेटी'])) {
      return _caregiverReply(context, isHindi);
    }

    if (_any(q, ['my name', 'who am i', 'मेरा नाम', 'मैं कौन'])) {
      final who = context.preferred;
      return CompanionReply(
        who.isEmpty
            ? say('Your name is not saved yet. Your caregiver can add it.',
                'आपका नाम अभी सहेजा नहीं गया है। आपका देखभालकर्ता इसे जोड़ सकता है।')
            : say('You are $who.', 'आप $who हैं।'),
        suggestions: suggestions(context: context, isHindi: isHindi),
      );
    }

    if (_any(q, ['home', 'address', 'घर', 'पता', 'where do i live'])) {
      return CompanionReply(
        context.homeAddress.isEmpty
            ? say('No home address is saved yet.', 'घर का पता अभी सहेजा नहीं गया है।')
            : say('Your home address is ${context.homeAddress}.',
                'आपका घर का पता ${context.homeAddress} है।'),
        suggestions: suggestions(context: context, isHindi: isHindi),
      );
    }

    if (_any(q, ['play', 'game', 'activity', 'खेल', 'गेम'])) {
      return CompanionReply(
        say(
          'Let us play. Tap Play on your home screen — Memory Pairs is a good '
          'start.',
          'चलिए खेलते हैं। होम स्क्रीन पर खेलें दबाएँ — चित्र जोड़ी मिलान अच्छा है।',
        ),
        suggestions: suggestions(context: context, isHindi: isHindi),
      );
    }

    if (_any(q, ['weather', 'मौसम', 'news', 'समाचार', 'cricket'])) {
      return CompanionReply(
        say(
          'I cannot check the news or the weather. Ask your caregiver and they '
          'can tell you.',
          'मैं मौसम या समाचार नहीं देख सकता। अपने देखभालकर्ता से पूछें, वे बता देंगे।',
        ),
        callName: context.caregiver.isEmpty ? null : context.caregiver,
        callPhone: context.caregiverPhone.isEmpty ? null : context.caregiverPhone,
        suggestions: suggestions(context: context, isHindi: isHindi),
      );
    }

    // Nothing recognised: answer kindly and steer to a person, never guess.
    final name = context.caregiver;
    final caring = isHindi
        ? 'मुझे यह ठीक से समझ नहीं आया। मैं आपके साथ हूँ। आप समय, दवा, अपने रिमाइंडर या किसी को कॉल करने के बारे में पूछ सकते हैं।'
        : 'I did not quite understand that. I am here with you. You can ask me '
            'about the time, your medicines, your reminders, or calling someone.';
    final extra = name.isEmpty
        ? ''
        : (isHindi ? ' क्या $name को कॉल करें?' : ' Would you like to call $name?');

    return CompanionReply(
      '$caring$extra',
      suggestions: suggestions(context: context, isHindi: isHindi),
      callName: name.isEmpty || context.caregiverPhone.isEmpty ? null : name,
      callPhone: name.isEmpty ? null : context.caregiverPhone,
    );
  }

  /// Context-aware chips: large, few, and each one is a complete question.
  static List<String> suggestions({
    required CompanionContext context,
    required bool isHindi,
  }) {
    final next = ReminderTime.next(context.reminders);
    final callName = context.caregiver.isEmpty
        ? (context.contacts.isEmpty ? '' : _text(context.contacts.first['name']))
        : context.caregiver;

    if (isHindi) {
      return [
        'कितना बजा है?',
        if (next != null)
          'मेरी दवा कब है?'
        else
          'मेरा रिमाइंडर बताएँ',
        if (callName.isNotEmpty) '$callName को कॉल करें' else 'मेरा नाम क्या है?',
        'मुझे अकेला लग रहा है',
      ];
    }
    return [
      'What time is it?',
      if (next != null) 'When is my medicine?' else 'What are my reminders?',
      if (callName.isNotEmpty) 'Call $callName' else 'What is my name?',
      'I feel lonely',
    ];
  }

  // -------------------------------------------------------------------------
  // Intent replies
  // -------------------------------------------------------------------------

  static CompanionReply _timeReply(CompanionContext context, bool isHindi) {
    final now = DateTime.now();
    final text = isHindi
        ? 'अभी ${_clockHi(now)} बजे हैं।'
        : 'It is ${_clock(now)}.';
    final next = ReminderTime.next(context.reminders);
    final extra = next == null
        ? ''
        : (isHindi
            ? ' आपका अगला रिमाइंडर ${ReminderTime.to12h(next['time'] as String?)} पर है।'
            : ' Your next reminder is at ${ReminderTime.to12h(next['time'] as String?)}.');
    return CompanionReply(
      '$text$extra',
      suggestions: suggestions(context: context, isHindi: isHindi),
    );
  }

  static CompanionReply _dateReply(CompanionContext context, bool isHindi) {
    final now = DateTime.now();
    if (isHindi) {
      return CompanionReply(
        'आज ${_daysHi[now.weekday - 1]}, ${now.day} ${_monthsHi[now.month - 1]} है।',
        suggestions: suggestions(context: context, isHindi: isHindi),
      );
    }
    return CompanionReply(
      'Today is ${_daysEn[now.weekday - 1]}, ${now.day} ${_monthsEn[now.month - 1]}.',
      suggestions: suggestions(context: context, isHindi: isHindi),
    );
  }

  static CompanionReply _medicineReply(CompanionContext context, bool isHindi) {
    final meds = _text(context.patient['medications']);
    final next = ReminderTime.next(context.reminders);

    if (next == null && meds.isEmpty) {
      return CompanionReply(
        isHindi
            ? 'अभी कोई दवा का रिमाइंडर सेट नहीं है। आपका देखभालकर्ता इसे जोड़ सकता है।'
            : 'No medicine reminder is set yet. Your caregiver can add one for you.',
        suggestions: suggestions(context: context, isHindi: isHindi),
      );
    }

    final buffer = StringBuffer();
    if (next != null) {
      final title = _text(next['title']);
      buffer.write(isHindi
          ? 'आपकी अगली दवा ${ReminderTime.to12h(next['time'] as String?)} पर है'
          : 'Your next medicine is at ${ReminderTime.to12h(next['time'] as String?)}');
      if (title.isNotEmpty) {
        buffer.write(isHindi ? ' — $title।' : ' — $title.');
      } else {
        buffer.write(isHindi ? '।' : '.');
      }
    }
    if (meds.isNotEmpty) {
      buffer.write(isHindi ? ' आपकी दवाइयाँ: $meds।' : ' Your medicines: $meds.');
    }
    return CompanionReply(
      buffer.toString().trim(),
      suggestions: suggestions(context: context, isHindi: isHindi),
    );
  }

  static CompanionReply _reminderReply(CompanionContext context, bool isHindi) {
    if (context.reminders.isEmpty) {
      return CompanionReply(
        isHindi
            ? 'अभी कोई रिमाइंडर सेट नहीं है। आपका देखभालकर्ता इसे जोड़ सकता है।'
            : 'No reminders are set yet. Your caregiver can add them for you.',
        suggestions: suggestions(context: context, isHindi: isHindi),
      );
    }

    final sorted = [...context.reminders]..sort(compareReminderTime);
    final next = ReminderTime.next(sorted);
    final upcoming = sorted.take(3).map((r) {
      final title = _text(r['title']);
      return '${ReminderTime.to12h(r['time'] as String?)}'
          '${title.isEmpty ? '' : ' — $title'}';
    }).join(isHindi ? ' · ' : ' · ');

    final first = next == null
        ? (isHindi ? 'आज के रिमाइंडर पूरे हो गए।' : 'Your reminders for today are done.')
        : (isHindi
            ? 'अगला रिमाइंडर ${ReminderTime.to12h(next['time'] as String?)} पर है।'
            : 'The next reminder is at ${ReminderTime.to12h(next['time'] as String?)}.');

    return CompanionReply(
      '$first ${isHindi ? 'आपके रिमाइंडर' : 'Your reminders'}: $upcoming.',
      suggestions: suggestions(context: context, isHindi: isHindi),
    );
  }

  static CompanionReply _callHelp(CompanionContext context, bool isHindi) {
    final options = <String>[];
    for (final contact in context.contacts.take(3)) {
      final name = _text(contact['name']);
      if (name.isNotEmpty) options.add(name);
    }
    if (options.isEmpty && context.caregiver.isNotEmpty) {
      options.add(context.caregiver);
    }

    if (options.isEmpty) {
      return CompanionReply(
        isHindi
            ? 'अभी कोई संपर्क सहेजा नहीं है। आपका देखभालकर्ता नंबर जोड़ सकता है।'
            : 'No contact is saved yet. Your caregiver can add phone numbers for you.',
        suggestions: suggestions(context: context, isHindi: isHindi),
      );
    }

    final list = options.join(', ');
    return CompanionReply(
      isHindi
          ? 'आप किसे कॉल करना चाहेंगे? $list में से नाम बोलें।'
          : 'Who would you like to call? Say a name: $list.',
      suggestions: [
        for (final name in options.take(3)) isHindi ? '$name को कॉल करें' : 'Call $name',
      ],
    );
  }

  static CompanionReply _caregiverReply(CompanionContext context, bool isHindi) {
    final name = context.caregiver;
    if (name.isEmpty) {
      return CompanionReply(
        isHindi
            ? 'आपका देखभालकर्ता अभी जुड़ा नहीं है। होम स्क्रीन पर लिंक आइकन से जोड़ें।'
            : 'No caregiver is linked yet. Use the link icon on your home screen to connect one.',
        suggestions: suggestions(context: context, isHindi: isHindi),
      );
    }

    final relation = _text(context.patient['caregiverRelation']);
    final phone = context.caregiverPhone;
    final sentence = isHindi
        ? 'आपके देखभालकर्ता $name हैं${relation.isEmpty ? '' : ' ($relation)'}।'
        : 'Your caregiver is $name${relation.isEmpty ? '' : ' ($relation)'}.';

    return CompanionReply(
      phone.isEmpty ? sentence : '$sentence ${isHindi ? 'नंबर' : 'Number'}: $phone.',
      callName: phone.isEmpty ? null : name,
      callPhone: phone.isEmpty ? null : phone,
      suggestions: suggestions(context: context, isHindi: isHindi),
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static const _monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _monthsHi = [
    'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
    'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर',
  ];

  static const _daysEn = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  static const _daysHi = [
    'सोमवार', 'मंगलवार', 'बुधवार', 'गुरुवार', 'शुक्रवार', 'शनिवार', 'रविवार',
  ];

  static String _clock(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  static String _clockHi(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final period = t.hour < 12 ? 'सुबह' : (t.hour < 17 ? 'दोपहर' : 'शाम');
    return '$period $hour:${t.minute.toString().padLeft(2, '0')}';
  }

  static String _normalise(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[.,!?;:"]'), ' ').trim();

  static bool _any(String query, List<String> keys) =>
      keys.any((key) => query.contains(key));

  static String _text(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static Map<String, dynamic>? _matchContact(
    String query,
    CompanionContext context,
  ) {
    for (final contact in context.contacts) {
      final name = _text(contact['name']).toLowerCase();
      if (name.isNotEmpty) {
        final tokens = name
            .split(RegExp(r'[^a-z0-9\u0900-\u097F]+'))
            .where((token) => token.length >= 3);
        for (final token in tokens) {
          if (query.contains(token)) return contact;
        }
      }
      final relation = _text(contact['relation']).toLowerCase();
      if (relation.length >= 4 && query.contains(relation)) {
        return contact;
      }
    }
    return null;
  }
}
