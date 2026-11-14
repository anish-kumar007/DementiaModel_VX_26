import 'package:flutter/material.dart';
import '../services/difficulty_engine.dart';
import '../services/session_logger.dart';
import '../services/reminder_notification_service.dart';

class _GroceryItem {
  final String id;
  final String nameEn;
  final String nameHi;
  final IconData icon;
  final Color accentColor;
  final Color surfaceTint;

  const _GroceryItem({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.icon,
    required this.accentColor,
    required this.surfaceTint,
  });
}

enum _ShoppingPhase { learning, pause, selection, completed }

class Game2Screen extends StatefulWidget {
  final bool isHindi;
  const Game2Screen({super.key, this.isHindi = false});

  @override
  State<Game2Screen> createState() => _Game2ScreenState();
}

class _Game2ScreenState extends State<Game2Screen> {
  final DifficultyEngine _difficultyEngine = DifficultyEngine();
  final List<int> _pickDurationsMs = [];
  DateTime? _pickStartTime;

  static const List<_GroceryItem> _catalog = [
    _GroceryItem(
      id: 'milk',
      nameEn: 'Milk',
      nameHi: 'दूध',
      icon: Icons.local_drink,
      accentColor: Color(0xFF1D4ED8),
      surfaceTint: Color(0xFFDBEAFE),
    ),
    _GroceryItem(
      id: 'bread',
      nameEn: 'Bread',
      nameHi: 'ब्रेड',
      icon: Icons.bakery_dining,
      accentColor: Color(0xFFB45309),
      surfaceTint: Color(0xFFFEF3C7),
    ),
    _GroceryItem(
      id: 'apples',
      nameEn: 'Apples',
      nameHi: 'सेब',
      icon: Icons.eco,
      accentColor: Color(0xFF15803D),
      surfaceTint: Color(0xFFDCFCE7),
    ),
    _GroceryItem(
      id: 'tea',
      nameEn: 'Tea Leaves',
      nameHi: 'चाय पत्ती',
      icon: Icons.emoji_food_beverage,
      accentColor: Color(0xFF0F766E),
      surfaceTint: Color(0xFFCCFBF1),
    ),
    _GroceryItem(
      id: 'rice',
      nameEn: 'Rice',
      nameHi: 'चावल',
      icon: Icons.rice_bowl,
      accentColor: Color(0xFF4338CA),
      surfaceTint: Color(0xFFE0E7FF),
    ),
    _GroceryItem(
      id: 'bananas',
      nameEn: 'Bananas',
      nameHi: 'केले',
      icon: Icons.spa,
      accentColor: Color(0xFFA16207),
      surfaceTint: Color(0xFFFEF9C3),
    ),
    _GroceryItem(
      id: 'soap',
      nameEn: 'Soap',
      nameHi: 'साबुन',
      icon: Icons.clean_hands,
      accentColor: Color(0xFF6D28D9),
      surfaceTint: Color(0xFFEDE9FE),
    ),
    _GroceryItem(
      id: 'eggs',
      nameEn: 'Eggs',
      nameHi: 'अंडे',
      icon: Icons.egg_alt,
      accentColor: Color(0xFFC2410C),
      surfaceTint: Color(0xFFFFEDD5),
    ),
    _GroceryItem(
      id: 'tomatoes',
      nameEn: 'Tomatoes',
      nameHi: 'टमाटर',
      icon: Icons.local_florist,
      accentColor: Color(0xFFB91C1C),
      surfaceTint: Color(0xFFFEE2E2),
    ),
    _GroceryItem(
      id: 'curd',
      nameEn: 'Curd',
      nameHi: 'दही',
      icon: Icons.icecream,
      accentColor: Color(0xFF0369A1),
      surfaceTint: Color(0xFFE0F2FE),
    ),
  ];

  int _selectedLevel = 1;
  _ShoppingPhase _phase = _ShoppingPhase.learning;
  late List<_GroceryItem> _targetList;
  late List<_GroceryItem> _shelfItems;
  final Set<String> _basketIds = {};
  final Set<String> _acknowledgedLearningIds = {};

  bool _peekListVisible = false;
  bool _usedPeek = false;
  bool _caregiverBonusAwarded = false;
  int _points = 0;
  int _totalTaps = 0;
  int _streak = 0;
  String _feedbackBanner = '';

  String _t(String en, String hi) => widget.isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    _selectedLevel = _difficultyEngine.currentLevel.clamp(1, 3);
    ReminderNotificationService.initialize(isHindi: widget.isHindi);
    _startNewRound();
  }

  /// PDF Specification:
  /// Level 1: 4 items + 2 distractors (List remains visible)
  /// Level 2: 5 items + 3 distractors (List can be checked once)
  /// Level 3: 6 items + 4 distractors (List hidden after learning)
  void _startNewRound() {
    final targetCount = _selectedLevel == 1 ? 4 : (_selectedLevel == 2 ? 5 : 6);
    final distractorCount =
        _selectedLevel == 1 ? 2 : (_selectedLevel == 2 ? 3 : 4);

    final shuffled = List<_GroceryItem>.from(_catalog)..shuffle();
    final targets = shuffled.take(targetCount).toList();
    final distractors =
        shuffled.skip(targetCount).take(distractorCount).toList();
    final shelf = [...targets, ...distractors]..shuffle();

    setState(() {
      _targetList = targets;
      _shelfItems = shelf;
      _basketIds.clear();
      _acknowledgedLearningIds.clear();
      _phase = _ShoppingPhase.learning;
      _peekListVisible = false;
      _usedPeek = false;
      _caregiverBonusAwarded = false;
      _totalTaps = 0;
      _feedbackBanner = _t(
        'Tap each item to read and name it together slowly.',
        'हर वस्तु को दबाकर धीरे-धीरे एक साथ नाम पढ़ें।',
      );
    });
    _pickDurationsMs.clear();
  }

  void _readListAloud() {
    final names = _targetList.map((e) => _t(e.nameEn, e.nameHi)).join(', ');
    ReminderNotificationService.speakReminder(
      _t('Our shopping list has: $names', 'हमारी सूची में है: $names'),
    );
  }

  void _goToPausePhase() {
    setState(() {
      _phase = _ShoppingPhase.pause;
      _feedbackBanner = _t(
        'Take a pleasant pause. Chat about your favourite meal or have a sip of water.',
        'थोड़ा आराम करें। अपने पसंदीदा भोजन पर बात करें या पानी पिएँ।',
      );
    });
  }

  void _goToSelectionPhase() {
    setState(() {
      _phase = _ShoppingPhase.selection;
      _feedbackBanner = _t(
        'Tap the items from our list to place them in our basket.',
        'सूची वाली वस्तुओं को हमारी टोकरी में रखने के लिए दबाएँ।',
      );
    });
    _pickStartTime = DateTime.now();
  }

  /// PDF Practical Tip: Offer a gentle 2-choice verbal/visual cue when stuck
  void _offerTwoChoiceHint() {
    final remainingTargets =
        _targetList.where((t) => !_basketIds.contains(t.id)).toList();
    if (remainingTargets.isEmpty) return;

    final nextTarget = remainingTargets.first;
    final distractors = _shelfItems
        .where((s) => !_targetList.any((t) => t.id == s.id))
        .toList();

    final targetName = _t(nextTarget.nameEn, nextTarget.nameHi);
    String cueText;
    if (distractors.isNotEmpty) {
      final distractorName = _t(distractors.first.nameEn, distractors.first.nameHi);
      cueText = _t(
        'Gentle cue: Is it $targetName or $distractorName?',
        'संकेत: क्या यह $targetName है या $distractorName?',
      );
    } else {
      cueText = _t(
        'Gentle cue: Let’s look for $targetName.',
        'संकेत: आइए $targetName ढूँढें।',
      );
    }

    setState(() => _feedbackBanner = cueText);
    ReminderNotificationService.speakReminder(cueText);
  }

  void _onShelfItemTap(_GroceryItem item) {
    if (_basketIds.contains(item.id)) return;

    _totalTaps++;
    final now = DateTime.now();
    final pickMs = _pickStartTime != null
        ? now.difference(_pickStartTime!).inMilliseconds
        : 3500;
    _pickDurationsMs.add(pickMs);
    _pickStartTime = now;

    final isTarget = _targetList.any((t) => t.id == item.id);
    final label = _t(item.nameEn, item.nameHi);

    if (isTarget) {
      _streak++;
      _difficultyEngine.adaptDifficulty(
        lastAnswerCorrect: true,
        currentStreak: _streak,
        responseTimeMs: pickMs,
      );

      setState(() {
        _basketIds.add(item.id);
        _points += 10; // PDF Scoring: +10 for correct item placed in basket
        _feedbackBanner = _t(
          'Yes, $label is on our list! (+10)',
          'हाँ, $label हमारी सूची में है! (+10)',
        );
      });
      ReminderNotificationService.speakReminder(
        _t('Yes, $label is on our list!', 'हाँ, $label हमारी सूची में है!'),
      );

      if (_basketIds.length == _targetList.length) {
        _completeShopping();
      }
    } else {
      // PDF Scoring: 0 penalty for item not on the list, gentle supportive wording
      _streak = 0;
      _difficultyEngine.adaptDifficulty(
        lastAnswerCorrect: false,
        currentStreak: 0,
        responseTimeMs: pickMs,
      );

      setState(() {
        _feedbackBanner = _t(
          'That’s a nice $label, but let’s look for the ones on our list.',
          '$label अच्छा है, पर आइए सूची वाली चीज़ें ढूँढें।',
        );
      });
    }
  }

  void _completeShopping() {
    final avgMs = _pickDurationsMs.isEmpty
        ? 3000
        : (_pickDurationsMs.reduce((a, b) => a + b) ~/ _pickDurationsMs.length);
    final accuracy = _totalTaps == 0
        ? 1.0
        : (_targetList.length / _totalTaps).clamp(0.0, 1.0);

    setState(() {
      _points += 20; // PDF Scoring: +20 bonus for all list items collected
      _phase = _ShoppingPhase.completed;
      _feedbackBanner = _t(
        'You got everything — excellent!',
        'आपने सब कुछ ले लिया — बहुत बढ़िया!',
      );
    });

    ReminderNotificationService.speakReminder(_feedbackBanner);

    SessionLogger.logSession(
      game: 'shopping_basket',
      level: _selectedLevel,
      accuracy: accuracy,
      avgResponseMs: avgMs,
      language: widget.isHindi ? 'hi' : 'en',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      appBar: AppBar(
        title: Text(
          _t(
            'Shopping Basket • Level $_selectedLevel',
            'खरीदारी की टोकरी • स्तर $_selectedLevel',
          ),
        ),
        backgroundColor: Colors.indigo.shade900,
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.tune, color: Colors.white, size: 28),
            tooltip: _t('Choose Level', 'स्तर चुनें'),
            onSelected: (lvl) {
              setState(() => _selectedLevel = lvl);
              _startNewRound();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 1,
                child: Text(
                  _t('Level 1 • 4 Items (List Visible)', 'स्तर 1 • 4 वस्तुएँ (सूची दिखेगी)'),
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: Text(
                  _t('Level 2 • 5 Items (1 Peek)', 'स्तर 2 • 5 वस्तुएँ (1 बार देखें)'),
                ),
              ),
              PopupMenuItem(
                value: 3,
                child: Text(
                  _t('Level 3 • 6 Items (From Memory)', 'स्तर 3 • 6 वस्तुएँ (याद से)'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildBodyForPhase(),
        ),
      ),
    );
  }

  Widget _buildBodyForPhase() {
    switch (_phase) {
      case _ShoppingPhase.learning:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _t('Step 1: Our Shopping List', 'चरण 1: हमारी खरीदारी की सूची'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onPressed: _readListAloud,
                  icon: const Icon(Icons.volume_up, color: Colors.white),
                  label: Text(
                    _t('Read Aloud', 'बोलकर सुनाएँ'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _feedbackBanner,
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _targetList.length,
                itemBuilder: (context, index) {
                  final item = _targetList[index];
                  final acknowledged =
                      _acknowledgedLearningIds.contains(item.id);
                  final itemLabel = _t(item.nameEn, item.nameHi);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        setState(() => _acknowledgedLearningIds.add(item.id));
                        ReminderNotificationService.speakReminder(itemLabel);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: item.surfaceTint,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: acknowledged
                                ? Colors.teal.shade700
                                : item.accentColor,
                            width: 2.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor:
                                  item.accentColor.withOpacity(0.15),
                              child: Icon(
                                item.icon,
                                size: 32,
                                color: item.accentColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                itemLabel,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            Icon(
                              acknowledged
                                  ? Icons.check_circle
                                  : Icons.touch_app,
                              color: acknowledged
                                  ? Colors.teal.shade700
                                  : item.accentColor,
                              size: 30,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 66,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _goToPausePhase,
                icon: const Icon(
                  Icons.arrow_forward,
                  size: 30,
                  color: Colors.white,
                ),
                label: Text(
                  _t('We Are Ready to Shop', 'हम खरीदारी के लिए तैयार हैं'),
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

      case _ShoppingPhase.pause:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.local_cafe, size: 84, color: Colors.amberAccent),
            const SizedBox(height: 20),
            Text(
              _t('Step 2: Short Pleasant Pause', 'चरण 2: छोटा सा आराम'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                _feedbackBanner,
                style: const TextStyle(fontSize: 20, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 70,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _goToSelectionPhase,
                icon: const Icon(
                  Icons.shopping_basket,
                  size: 32,
                  color: Colors.white,
                ),
                label: Text(
                  _t('Open Shopping Basket', 'खरीदारी की टोकरी खोलें'),
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

      case _ShoppingPhase.selection:
        // PDF Difficulty Rules:
        // Level 1: List remains visible
        // Level 2: List can be checked once
        // Level 3: List hidden after learning
        final showAlwaysList = _selectedLevel <= 1;
        final canCheckOnce = _selectedLevel == 2 && !_usedPeek;
        final collectedItems =
            _targetList.where((t) => _basketIds.contains(t.id)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Positive Progress & Points Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _t(
                      'Basket: ${_basketIds.length} / ${_targetList.length}',
                      'टोकरी: ${_basketIds.length} / ${_targetList.length}',
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _t('Points: $_points', 'अंक: $_points'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Supportive Feedback & Optional 2-Choice Hint Button
            Row(
              children: [
                Expanded(
                  child: Text(
                    _feedbackBanner,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.tealAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.amberAccent),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onPressed: _offerTwoChoiceHint,
                  icon: const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amberAccent,
                    size: 20,
                  ),
                  label: Text(
                    _t('Cue', 'संकेत'),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // Level 1 Visible List OR Level 2 One-Time Peek
            if (showAlwaysList || _peekListVisible) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amberAccent),
                ),
                child: Text(
                  '${_t('Our List', 'हमारी सूची')}: ${_targetList.map((e) => _t(e.nameEn, e.nameHi)).join(' • ')}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else if (canCheckOnce) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.amberAccent),
                ),
                onPressed: () => setState(() {
                  _peekListVisible = true;
                  _usedPeek = true;
                }),
                icon: const Icon(Icons.visibility, color: Colors.amberAccent),
                label: Text(
                  _t('Check List Once', 'सूची एक बार देखें'),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),

            // High-Clarity Grocery Shelf Grid
            Expanded(
              child: GridView.builder(
                itemCount: _shelfItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.55,
                ),
                itemBuilder: (context, index) {
                  final item = _shelfItems[index];
                  final inBasket = _basketIds.contains(item.id);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _onShelfItemTap(item),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: inBasket
                              ? const Color(0xFFD1FAE5)
                              : item.surfaceTint,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: inBasket
                                ? Colors.teal.shade700
                                : item.accentColor,
                            width: inBasket ? 3.5 : 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              inBasket ? Icons.check_circle : item.icon,
                              size: 38,
                              color: inBasket
                                  ? Colors.teal.shade700
                                  : item.accentColor,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _t(item.nameEn, item.nameHi),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Concrete Shopping Basket Tray (PDF tip: a basket makes the task concrete & enjoyable)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.shopping_basket,
                        color: Colors.tealAccent,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _t('In Our Basket:', 'हमारी टोकरी में:'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.tealAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  collectedItems.isEmpty
                      ? Text(
                          _t(
                            'Tap an item above to place it here.',
                            'यहाँ रखने के लिए ऊपर किसी वस्तु को दबाएँ।',
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white60,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: collectedItems
                              .map(
                                (item) => Chip(
                                  backgroundColor: Colors.teal.shade800,
                                  avatar: Icon(
                                    item.icon,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _t(item.nameEn, item.nameHi),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ],
              ),
            ),
          ],
        );

      case _ShoppingPhase.completed:
        return Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shopping_bag,
                  size: 88,
                  color: Colors.amberAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  _feedbackBanner,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _t('Points Earned: $_points', 'अर्जित अंक: $_points'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.tealAccent,
                  ),
                ),
                const SizedBox(height: 20),

                // PDF Scoring: +10 session bonus given warmly at the end
                if (!_caregiverBonusAwarded)
                  SizedBox(
                    height: 60,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _points += 10;
                          _caregiverBonusAwarded = true;
                        });
                      },
                      icon: const Icon(Icons.favorite, color: Colors.white),
                      label: Text(
                        _t(
                          'Caregiver Bonus: Great Session (+10)',
                          'देखभालकर्ता बोनस: शानदार सत्र (+10)',
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _startNewRound,
                    icon: const Icon(
                      Icons.refresh,
                      size: 30,
                      color: Colors.white,
                    ),
                    label: Text(
                      _t('Shop Again', 'फिर से खरीदारी करें'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.tealAccent, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      _t('Back to Home', 'मुख्य स्क्रीन पर जाएँ'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.tealAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}
