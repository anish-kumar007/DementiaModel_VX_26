import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/reminder_notification_service.dart';

class PatientProfileScreen extends StatefulWidget {
  final bool isHindi;
  final String? patientId;

  const PatientProfileScreen({
    super.key,
    this.isHindi = false,
    this.patientId,
  });

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  final _nameCtrl = TextEditingController();
  final _preferredNameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _bloodGroupCtrl = TextEditingController();
  final _languagesCtrl = TextEditingController();
  final _homeAddressCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _doctorNameCtrl = TextEditingController();
  final _doctorPhoneCtrl = TextEditingController();
  final _caregiverNameCtrl = TextEditingController();
  final _caregiverRelationCtrl = TextEditingController();
  final _caregiverPhoneCtrl = TextEditingController();
  final _comfortNotesCtrl = TextEditingController();

  bool _controllersInitialized = false;

  String get _pid =>
      widget.patientId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  String _t(String en, String hi) => widget.isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    ReminderNotificationService.initialize(isHindi: widget.isHindi);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _preferredNameCtrl.dispose();
    _ageCtrl.dispose();
    _bloodGroupCtrl.dispose();
    _languagesCtrl.dispose();
    _homeAddressCtrl.dispose();
    _diagnosisCtrl.dispose();
    _allergiesCtrl.dispose();
    _medicationsCtrl.dispose();
    _doctorNameCtrl.dispose();
    _doctorPhoneCtrl.dispose();
    _caregiverNameCtrl.dispose();
    _caregiverRelationCtrl.dispose();
    _caregiverPhoneCtrl.dispose();
    _comfortNotesCtrl.dispose();
    super.dispose();
  }

  void _populateControllers(Map<String, dynamic> data) {
    if (_controllersInitialized && _isEditing) return;
    _nameCtrl.text = (data['name'] ?? '').toString();
    _preferredNameCtrl.text = (data['preferredName'] ?? '').toString();
    _ageCtrl.text = (data['age'] ?? '').toString();
    _bloodGroupCtrl.text = (data['bloodGroup'] ?? '').toString();
    _languagesCtrl.text = (data['languages'] ?? 'English, Hindi').toString();
    _homeAddressCtrl.text = (data['homeAddress'] ?? '').toString();
    _diagnosisCtrl.text = (data['diagnosis'] ?? '').toString();
    _allergiesCtrl.text = (data['allergies'] ?? '').toString();
    _medicationsCtrl.text = (data['medications'] ?? '').toString();
    _doctorNameCtrl.text = (data['doctorName'] ?? '').toString();
    _doctorPhoneCtrl.text = (data['doctorPhone'] ?? '').toString();
    _caregiverNameCtrl.text = (data['caregiverName'] ?? '').toString();
    _caregiverRelationCtrl.text = (data['caregiverRelation'] ?? '').toString();
    _caregiverPhoneCtrl.text = (data['caregiverPhone'] ?? '').toString();
    _comfortNotesCtrl.text = (data['comfortPreferences'] ?? '').toString();
    _controllersInitialized = true;
  }

  Future<void> _saveProfile() async {
    if (_pid.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('patients').doc(_pid).set({
        'name': _nameCtrl.text.trim(),
        'preferredName': _preferredNameCtrl.text.trim(),
        'age': _ageCtrl.text.trim(),
        'bloodGroup': _bloodGroupCtrl.text.trim(),
        'languages': _languagesCtrl.text.trim(),
        'homeAddress': _homeAddressCtrl.text.trim(),
        'diagnosis': _diagnosisCtrl.text.trim(),
        'allergies': _allergiesCtrl.text.trim(),
        'medications': _medicationsCtrl.text.trim(),
        'doctorName': _doctorNameCtrl.text.trim(),
        'doctorPhone': _doctorPhoneCtrl.text.trim(),
        'caregiverName': _caregiverNameCtrl.text.trim(),
        'caregiverRelation': _caregiverRelationCtrl.text.trim(),
        'caregiverPhone': _caregiverPhoneCtrl.text.trim(),
        'comfortPreferences': _comfortNotesCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Profile saved successfully.', 'प्रोफ़ाइल सफलतापूर्वक सहेजी गई।'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.teal.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Could not save profile: $e', 'प्रोफ़ाइल सहेजी नहीं जा सकी: $e'),
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.amber.shade900,
        ),
      );
    }
  }

  Future<void> _callNumber(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _speakProfileSummary(Map<String, dynamic> data) {
    final name = (data['name'] ?? '').toString();
    final address = (data['homeAddress'] ?? '').toString();
    final caregiver = (data['caregiverName'] ?? '').toString();

    final summary = widget.isHindi
        ? 'मेरा नाम ${name.isEmpty ? "उपलब्ध नहीं" : name} है। मेरा घर का पता ${address.isEmpty ? "उपलब्ध नहीं" : address} है। मेरे देखभालकर्ता ${caregiver.isEmpty ? "उपलब्ध नहीं" : caregiver} हैं।'
        : 'My name is ${name.isEmpty ? "not set" : name}. My home address is ${address.isEmpty ? "not set" : address}. My caregiver is ${caregiver.isEmpty ? "not set" : caregiver}.';

    ReminderNotificationService.speakReminder(summary);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      appBar: AppBar(
        title: Text(_t('My Profile & ID Card', 'मेरी प्रोफ़ाइल और परिचय पत्र')),
        backgroundColor: Colors.teal.shade900,
        actions: [
          IconButton(
            tooltip: _isEditing
                ? _t('Cancel Edit', 'संपादन रद्द करें')
                : _t('Edit Details', 'विवरण बदलें'),
            icon: Icon(
              _isEditing ? Icons.close : Icons.edit,
              size: 28,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: _pid.isEmpty
          ? Center(
              child: Text(
                _t('Please sign in to view profile.', 'प्रोफ़ाइल देखने के लिए लॉगिन करें।'),
                style: const TextStyle(fontSize: 20, color: Colors.white70),
              ),
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('patients')
                  .doc(_pid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !_controllersInitialized) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data?.data() ?? {};
                _populateControllers(data);

                return SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18.0),
                    child: _isEditing
                        ? _buildEditForm()
                        : _buildReadOnlyProfile(data),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildReadOnlyProfile(Map<String, dynamic> data) {
    final name = (data['name'] ?? _t('Not Set', 'दर्ज नहीं')).toString();
    final preferred = (data['preferredName'] ?? '').toString();
    final age = (data['age'] ?? _t('Not Set', 'दर्ज नहीं')).toString();
    final bloodGroup =
        (data['bloodGroup'] ?? _t('Not Set', 'दर्ज नहीं')).toString();
    final languages =
        (data['languages'] ?? 'English, Hindi').toString();
    final homeAddress =
        (data['homeAddress'] ?? _t('Not Set', 'दर्ज नहीं')).toString();
    final diagnosis =
        (data['diagnosis'] ?? _t('Memory Support', 'स्मृति सहायता')).toString();
    final allergies =
        (data['allergies'] ?? _t('None listed', 'कोई एलर्जी नहीं')).toString();
    final medications =
        (data['medications'] ?? _t('See Reminders', 'रिमाइंडर देखें')).toString();
    final doctorName =
        (data['doctorName'] ?? _t('Not Set', 'दर्ज नहीं')).toString();
    final doctorPhone = (data['doctorPhone'] ?? '').toString();
    final caregiverName =
        (data['caregiverName'] ?? _t('Not Linked Yet', 'अभी जुड़ा नहीं है')).toString();
    final caregiverRelation =
        (data['caregiverRelation'] ?? _t('Family Caregiver', 'परिवार देखभालकर्ता')).toString();
    final caregiverPhone = (data['caregiverPhone'] ?? '').toString();
    final comfortNotes = (data['comfortPreferences'] ??
            _t('Calm music, warm tea, familiar photos', 'शांत संगीत, गर्म चाय, परिवार की तस्वीरें'))
        .toString();

    final zone = data['safeZone'] as Map<String, dynamic>?;
    final radiusM = (zone?['radiusM'] as num?)?.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Identity Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade900, const Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.tealAccent.withOpacity(0.6), width: 1.5),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.tealAccent.withOpacity(0.2),
                child: const Icon(
                  Icons.person,
                  size: 52,
                  color: Colors.tealAccent,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name.isEmpty ? _t('Patient Name', 'रोगी का नाम') : name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              if (preferred.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _t('Calls self: "$preferred"', 'पसंदीदा नाम: "$preferred"'),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _BadgeChip(
                    icon: Icons.cake,
                    label: '${_t('Age', 'उम्र')}: ${age.isEmpty ? '-' : age}',
                  ),
                  _BadgeChip(
                    icon: Icons.bloodtype,
                    label:
                        '${_t('Blood', 'रक्त समूह')}: ${bloodGroup.isEmpty ? '-' : bloodGroup}',
                  ),
                  _BadgeChip(
                    icon: Icons.translate,
                    label: languages,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _speakProfileSummary(data),
                  icon: const Icon(Icons.volume_up, size: 28, color: Colors.white),
                  label: Text(
                    _t('Read My ID Card Aloud', 'मेरा परिचय पत्र बोलकर सुनाएँ'),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 1. Primary Caregiver & Emergency Contact
        _SectionCard(
          title: _t('Primary Caregiver', 'मुख्य देखभालकर्ता'),
          icon: Icons.favorite,
          accentColor: Colors.amberAccent,
          children: [
            _InfoRow(
              label: _t('Name', 'नाम'),
              value: caregiverName.isEmpty ? '-' : caregiverName,
            ),
            _InfoRow(
              label: _t('Relationship', 'रिश्ता'),
              value: caregiverRelation.isEmpty ? '-' : caregiverRelation,
            ),
            _InfoRow(
              label: _t('Phone', 'फ़ोन नंबर'),
              value: caregiverPhone.isEmpty ? _t('Not set', 'दर्ज नहीं') : caregiverPhone,
            ),
            if (caregiverPhone.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 58,
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _callNumber(caregiverPhone),
                  icon: const Icon(Icons.call, size: 28, color: Colors.white),
                  label: Text(
                    _t('Call $caregiverName', '$caregiverName को कॉल करें'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // 2. Home Address & Safe Zone
        _SectionCard(
          title: _t('Home & Safe Zone', 'घर और सुरक्षित क्षेत्र'),
          icon: Icons.home,
          accentColor: Colors.tealAccent,
          children: [
            _InfoRow(
              label: _t('Home Address', 'घर का पता'),
              value: homeAddress.isEmpty ? '-' : homeAddress,
            ),
            _InfoRow(
              label: _t('Safe Zone Radius', 'सुरक्षित क्षेत्र दायरा'),
              value: radiusM != null
                  ? '$radiusM meters'
                  : _t('200 meters (Default)', '200 मीटर (डिफ़ॉल्ट)'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Medical & Dementia Care Information
        _SectionCard(
          title: _t('Medical & Care Information', 'चिकित्सा और देखभाल जानकारी'),
          icon: Icons.medical_information,
          accentColor: Colors.lightBlueAccent,
          children: [
            _InfoRow(
              label: _t('Condition / Support', 'स्थिति / सहायता'),
              value: diagnosis.isEmpty ? '-' : diagnosis,
            ),
            _InfoRow(
              label: _t('Allergies', 'एलर्जी'),
              value: allergies.isEmpty ? '-' : allergies,
            ),
            _InfoRow(
              label: _t('Daily Medications', 'दैनिक दवाइयाँ'),
              value: medications.isEmpty ? '-' : medications,
            ),
            _InfoRow(
              label: _t('Doctor', 'डॉक्टर'),
              value: doctorName.isEmpty ? '-' : doctorName,
            ),
            if (doctorPhone.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.lightBlueAccent),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () => _callNumber(doctorPhone),
                icon: const Icon(Icons.local_hospital, color: Colors.lightBlueAccent),
                label: Text(
                  _t('Call Doctor ($doctorPhone)', 'डॉक्टर को कॉल करें ($doctorPhone)'),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.lightBlueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // 4. Comfort & Routine Preferences
        _SectionCard(
          title: _t('What Helps Me Feel Calm', 'मुझे शांत और खुश रखने वाली बातें'),
          icon: Icons.spa,
          accentColor: Colors.greenAccent,
          children: [
            Text(
              comfortNotes,
              style: const TextStyle(
                fontSize: 19,
                height: 1.4,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Edit Profile Button
        SizedBox(
          height: 60,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.tealAccent, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => setState(() => _isEditing = true),
            icon: const Icon(Icons.edit_note, size: 28, color: Colors.tealAccent),
            label: Text(
              _t('Update Profile Details', 'प्रोफ़ाइल विवरण अपडेट करें'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.tealAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _t('Update Patient Details', 'रोगी का विवरण अपडेट करें'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.amberAccent,
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(_nameCtrl, _t('Full Name', 'पूरा नाम'), Icons.person),
        _buildTextField(
          _preferredNameCtrl,
          _t('Preferred Name / Nickname', 'पसंदीदा नाम'),
          Icons.badge,
        ),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                _ageCtrl,
                _t('Age', 'उम्र'),
                Icons.cake,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                _bloodGroupCtrl,
                _t('Blood Group', 'रक्त समूह'),
                Icons.bloodtype,
              ),
            ),
          ],
        ),
        _buildTextField(
          _languagesCtrl,
          _t('Languages Spoken', 'बोली जाने वाली भाषाएँ'),
          Icons.translate,
        ),
        _buildTextField(
          _homeAddressCtrl,
          _t('Home Address', 'घर का पता'),
          Icons.home,
          maxLines: 2,
        ),
        const Divider(height: 28, color: Colors.white24),
        _buildTextField(
          _caregiverNameCtrl,
          _t('Primary Caregiver Name', 'मुख्य देखभालकर्ता का नाम'),
          Icons.favorite,
        ),
        _buildTextField(
          _caregiverRelationCtrl,
          _t('Caregiver Relationship (e.g. Daughter)', 'रिश्ता (जैसे बेटी/बेटा)'),
          Icons.people,
        ),
        _buildTextField(
          _caregiverPhoneCtrl,
          _t('Caregiver Phone Number', 'देखभालकर्ता का फ़ोन नंबर'),
          Icons.call,
          keyboardType: TextInputType.phone,
        ),
        const Divider(height: 28, color: Colors.white24),
        _buildTextField(
          _diagnosisCtrl,
          _t('Diagnosis / Dementia Stage', 'चिकित्सा स्थिति / चरण'),
          Icons.medical_information,
        ),
        _buildTextField(
          _allergiesCtrl,
          _t('Allergies', 'एलर्जी'),
          Icons.warning_amber,
        ),
        _buildTextField(
          _medicationsCtrl,
          _t('Daily Medications', 'दैनिक दवाइयाँ'),
          Icons.medication,
          maxLines: 2,
        ),
        _buildTextField(
          _doctorNameCtrl,
          _t('Doctor Name', 'डॉक्टर का नाम'),
          Icons.local_hospital,
        ),
        _buildTextField(
          _doctorPhoneCtrl,
          _t('Doctor Phone Number', 'डॉक्टर का फ़ोन नंबर'),
          Icons.phone_in_talk,
          keyboardType: TextInputType.phone,
        ),
        _buildTextField(
          _comfortNotesCtrl,
          _t('Calming & Comfort Preferences', 'पसंदीदा और शांत रखने वाली बातें'),
          Icons.spa,
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 64,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _isSaving ? null : _saveProfile,
            icon: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(Icons.save, size: 28, color: Colors.white),
            label: Text(
              _t('Save Profile', 'प्रोफ़ाइल सहेजें'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 19, color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 17, color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.tealAccent),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: Colors.white12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, color: Colors.white60),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BadgeChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.tealAccent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
