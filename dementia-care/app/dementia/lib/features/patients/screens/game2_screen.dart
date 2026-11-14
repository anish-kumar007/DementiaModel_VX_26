import 'package:material_ui/material_ui.dart';
import '../services/difficulty_engine.dart';
import '../services/session_logger.dart';
import '../services/reminder_notification_service.dart';

class _GroceryItem {
  final String id;
  final String nameEn;
  final String nameHi;
  final IconData icon;

  const _GroceryItem({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.icon,
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
    _GroceryItem(id: 'milk', nameEn: 'Milk', nameHi: 'दूध', icon: Icons.local_drink),
    _GroceryItem(id: 'bread', nameEn: 'Bread', nameHi: 'ब्रेड', icon: Icons.bakery_dining),
    _GroceryItem(id: 'apples', nameEn: 'Apples', nameHi: 'सेब', icon: Icons.eco),
    _GroceryItem(id: 'tea', nameEn: 'Tea Leaves', nameHi: 'चाय पत्ती', icon: Icons.emoji_food_beverage),
    _GroceryItem(id: 'rice', nameEn: 'Rice', nameHi: 'चावल', icon: Icons.rice_bowl),
    _GroceryItem(id: 'bananas', nameEn: 'Bananas', nameHi: 'केले', icon: Icons.spa),
    _GroceryItem(id: 'soap', nameEn: 'Soap', nameHi: 'साबुन', icon: Icons.clean_hands),
    _GroceryItem(id: 'eggs', nameEn: 'Eggs', nameHi: 'अंडे', icon: Icons.egg_alt),
  ];

  _ShoppingPhase _phase = _ShoppingPhase.learning;
  late List<_GroceryItem> _targetList;
  late List<_GroceryItem> _shelfItems;
  final Set<String> _basketIds = {};
  bool _peekListVisible = false;
  bool _usedPeek = false;
  int _points = 0;
  int _totalTaps = 0;
  int _streak = 0;
  String _feedbackBanner = '';

  String _t(String en, String hi) => widget.isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    ReminderNotificationService.initialize(isHindi: widget.isHindi);
    _startNewRound();
  }

  void _startNewRound() {
    final lvl = _difficultyEngine.currentLevel;
    // Level 1: 4 items + 2 distractors (list stays visible)
    // Level 2: 5 items + 3 distractors (list can be checked once)
    // Level 3+: 6 items + 2 distractors (list hidden after learning)
    final targetCount = lvl <= 1 ? 4 : (lvl == 2 ? 5 : 6);
    final distractorCount = lvl <= 1 ? 2 : (lvl == 2 ? 3 : 2);

    final shuffled = List<_GroceryItem>.from(_catalog)..shuffle();
    final targets = shuffled.take(targetCount).toList();
    final distractors = shuffled.skip(targetCount).take(distractorCount).toList();
    final shelf = [...targets, ...distractors]..shuffle();

    setState(() {
      _targetList = targets;
      _shelfItems = shelf;
      _basketIds.clear();
      _phase = _ShoppingPhase.learning;
      _peekListVisible = false;
      _usedPeek = false;
      _totalTaps = 0;
      _feedbackBanner = _t(
        'Let’s read our shopping list together slowly.',
        'आइए अपनी खरीदारी की सूची धीरे-धीरे एक साथ पढ़ें।',
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
        'Take a gentle pause. Have a sip of water or chat together.',
        'थोड़ा आराम करें। पानी पिएँ या आपस में बात करें।',
      );
    });
  }

  void _goToSelectionPhase() {
    setState(() {
      _phase = _ShoppingPhase.selection;
      _feedbackBanner = _t(
        'Tap the items from our list to place them in the basket.',
        'सूची वाली वस्तुओं को टोकरी में डालने के लिए दबाएँ।',
      );
    });
    _pickStartTime = DateTime.now();
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
        _points += 10; // +10 for correct item in basket
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
      // 0 penalty for non-list item; gentle cue
      _streak = 0;
      _difficultyEngine.adaptDifficulty(
        lastAnswerCorrect: false,
        currentStreak: 0,
        responseTimeMs: pickMs,
      );

      setState(() {
        _feedbackBanner = _t(
          '$label is nice, let’s look for the items on our list.',
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
      _points += 20; // +20 bonus for collecting all list items
      _phase = _ShoppingPhase.completed;
      _feedbackBanner = _t(
        'You got everything — excellent!',
        'आपने सब कुछ ले लिया — बहुत बढ़िया!',
      );
    });

    ReminderNotificationService.speakReminder(_feedbackBanner);

    SessionLogger.logSession(
      game: 'shopping_basket',
      level: _difficultyEngine.currentLevel,
      accuracy: accuracy,
      avgResponseMs: avgMs,
      language: widget.isHindi ? 'hi' : 'en',
    );
  }

  @override
  Widget build(BuildContext context) {
    final lvl = _difficultyEngine.currentLevel;

    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      appBar: AppBar(
        title: Text(_t('Shopping Basket • Level $lvl', 'खरीदारी की टोकरी • स्तर $lvl')),
        backgroundColor: Colors.indigo.shade900,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: _buildBodyForPhase(lvl),
      ),
    );
  }

  Widget _buildBodyForPhase(int lvl) {
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
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, size: 36, color: Colors.white),
                  tooltip: _t('Read List Aloud', 'सूची बोलकर सुनाएँ'),
                  onPressed: _readListAloud,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_feedbackBanner, style: const TextStyle(fontSize: 18, color: Colors.white70)),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.builder(
                itemCount: _targetList.length,
                itemBuilder: (context, index) {
                  final item = _targetList[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.tealAccent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(item.icon, size: 38, color: Colors.tealAccent),
                        const SizedBox(width: 16),
                        Text(
                          _t(item.nameEn, item.nameHi),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: 68,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _goToPausePhase,
                icon: const Icon(Icons.arrow_forward, size: 30, color: Colors.white),
                label: Text(
                  _t('We Ready to Shop', 'हम खरीदारी के लिए तैयार हैं'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
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
            const Icon(Icons.local_cafe, size: 80, color: Colors.amberAccent),
            const SizedBox(height: 20),
            Text(
              _t('Step 2: Short Pleasant Pause', 'चरण 2: छोटा सा आराम'),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(
              _feedbackBanner,
              style: const TextStyle(fontSize: 20, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              height: 70,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _goToSelectionPhase,
                icon: const Icon(Icons.shopping_basket, size: 32, color: Colors.white),
                label: Text(
                  _t('Open Shopping Basket', 'खरीदारी की टोकरी खोलें'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        );

      case _ShoppingPhase.selection:
        // Level 1: List remains visible; Level 2: Check once; Level 3+: Hidden
        final showAlwaysList = lvl <= 1;
        final canCheckOnce = lvl == 2 && !_usedPeek;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _t('Basket: ${_basketIds.length} / ${_targetList.length}', 'टोकरी: ${_basketIds.length} / ${_targetList.length}'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  _t('Points: $_points', 'अंक: $_points'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _feedbackBanner,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.tealAccent),
              textAlign: TextAlign.center,
            ),
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
                  '${_t('List', 'सूची')}: ${_targetList.map((e) => _t(e.nameEn, e.nameHi)).join(', ')}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else if (canCheckOnce) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amberAccent)),
                onPressed: () => setState(() {
                  _peekListVisible = true;
                  _usedPeek = true;
                }),
                icon: const Icon(Icons.visibility, color: Colors.amberAccent),
                label: Text(
                  _t('Peek at List Once', 'सूची एक बार देखें'),
                  style: const TextStyle(fontSize: 18, color: Colors.amberAccent),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                itemCount: _shelfItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                itemBuilder: (context, index) {
                  final item = _shelfItems[index];
                  final inBasket = _basketIds.contains(item.id);

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: inBasket ? Colors.teal.shade800 : const Color(0xFF263238),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: inBasket ? Colors.tealAccent : Colors.white24,
                          width: 2,
                        ),
                      ),
                    ),
                    onPressed: () => _onShelfItemTap(item),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          inBasket ? Icons.check_circle : item.icon,
                          size: 40,
                          color: inBasket ? Colors.tealAccent : Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _t(item.nameEn, item.nameHi),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );

      case _ShoppingPhase.completed:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_bag, size: 88, color: Colors.amberAccent),
              const SizedBox(height: 16),
              Text(
                _feedbackBanner,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _t('Points Earned: $_points', 'अर्जित अंक: $_points'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.tealAccent),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 66,
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _startNewRound,
                  icon: const Icon(Icons.refresh, size: 30, color: Colors.white),
                  label: Text(
                    _t('Shop Again', 'फिर से खरीदारी करें'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 66,
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.tealAccent, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    _t('Back to Home', 'मुख्य स्क्रीन पर जाएँ'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}
