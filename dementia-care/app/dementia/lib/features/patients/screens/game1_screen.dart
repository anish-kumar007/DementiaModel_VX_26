import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../services/difficulty_engine.dart';
import '../services/session_logger.dart';
import '../services/reminder_notification_service.dart';

class _MemoryItem {
  final String id;
  final String labelEn;
  final String labelHi;
  final IconData icon;
  final Color accentColor;

  const _MemoryItem({
    required this.id,
    required this.labelEn,
    required this.labelHi,
    required this.icon,
    required this.accentColor,
  });
}

class _CardSlot {
  final _MemoryItem item;
  bool isFaceUp;
  bool isMatched;
  int flipCount;

  _CardSlot({
    required this.item,
    this.isFaceUp = false,
    this.isMatched = false,
    this.flipCount = 0,
  });
}

class Game1Screen extends StatefulWidget {
  final bool isHindi;
  const Game1Screen({super.key, this.isHindi = false});

  @override
  State<Game1Screen> createState() => _Game1ScreenState();
}

class _Game1ScreenState extends State<Game1Screen> {
  final DifficultyEngine _difficultyEngine = DifficultyEngine();
  final Stopwatch _sessionStopwatch = Stopwatch();
  final List<int> _turnDurationsMs = [];
  DateTime? _turnStartTime;

  static const List<_MemoryItem> _familiarThemes = [
    _MemoryItem(id: 'cup', labelEn: 'Tea Cup', labelHi: 'चाय का कप', icon: Icons.local_cafe, accentColor: Colors.amber),
    _MemoryItem(id: 'flower', labelEn: 'Marigold', labelHi: 'गेंदे का फूल', icon: Icons.local_florist, accentColor: Colors.orangeAccent),
    _MemoryItem(id: 'home', labelEn: 'Home', labelHi: 'घर', icon: Icons.home, accentColor: Colors.tealAccent),
    _MemoryItem(id: 'lamp', labelEn: 'Lamp', labelHi: 'दीपक', icon: Icons.lightbulb, accentColor: Colors.yellowAccent),
    _MemoryItem(id: 'apple', labelEn: 'Apple', labelHi: 'सेब', icon: Icons.eco, accentColor: Colors.lightGreenAccent),
    _MemoryItem(id: 'book', labelEn: 'Book', labelHi: 'किताब', icon: Icons.menu_book, accentColor: Colors.cyanAccent),
    _MemoryItem(id: 'umbrella', labelEn: 'Umbrella', labelHi: 'छाता', icon: Icons.umbrella, accentColor: Colors.lightBlueAccent),
    _MemoryItem(id: 'pet', labelEn: 'Cat', labelHi: 'बिल्ली', icon: Icons.pets, accentColor: Colors.pinkAccent),
  ];

  late List<_CardSlot> _cards;
  int? _firstFlippedIndex;
  int? _secondFlippedIndex;
  bool _isWaitingCalmFlipBack = false;

  int _points = 0;
  int _pairsFound = 0;
  int _totalTurns = 0;
  int _streak = 0;
  bool _boardCompleted = false;
  String _encouragementText = '';

  String _t(String en, String hi) => widget.isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    ReminderNotificationService.initialize(isHindi: widget.isHindi);
    _setupBoard();
  }

  /// Level 1: 4 pairs (8 cards, 2x4)
  /// Level 2: 6 pairs (12 cards, 3x4)
  /// Level 3+: 8 pairs (16 cards, 4x4)
  int get _pairCountForLevel {
    final lvl = _difficultyEngine.currentLevel;
    if (lvl <= 1) return 4;
    if (lvl == 2) return 6;
    return 8;
  }

  void _setupBoard() {
    final pairCount = _pairCountForLevel;
    final selected = _familiarThemes.take(pairCount).toList();
    final deck = <_CardSlot>[];
    for (final item in selected) {
      deck.add(_CardSlot(item: item));
      deck.add(_CardSlot(item: item));
    }
    deck.shuffle();

    setState(() {
      _cards = deck;
      _firstFlippedIndex = null;
      _secondFlippedIndex = null;
      _isWaitingCalmFlipBack = false;
      _pairsFound = 0;
      _totalTurns = 0;
      _boardCompleted = false;
      _encouragementText = _t(
        'Tap any two cards at your own pace.',
        'अपनी सुविधा से कोई भी दो कार्ड चुनें।',
      );
    });

    _turnDurationsMs.clear();
    _sessionStopwatch
      ..reset()
      ..start();
    _turnStartTime = DateTime.now();
  }

  void _onCardTap(int index) {
    if (_isWaitingCalmFlipBack || _boardCompleted) return;
    final slot = _cards[index];
    if (slot.isFaceUp || slot.isMatched) return;

    final label = _t(slot.item.labelEn, slot.item.labelHi);
    ReminderNotificationService.speakReminder(label);

    setState(() {
      slot.isFaceUp = true;
      slot.flipCount++;
    });

    if (_firstFlippedIndex == null) {
      _firstFlippedIndex = index;
      return;
    }

    _secondFlippedIndex = index;
    _totalTurns++;

    final now = DateTime.now();
    final turnMs = _turnStartTime != null
        ? now.difference(_turnStartTime!).inMilliseconds
        : 4000;
    _turnDurationsMs.add(turnMs);
    _turnStartTime = now;

    final firstSlot = _cards[_firstFlippedIndex!];
    final secondSlot = _cards[_secondFlippedIndex!];

    if (firstSlot.item.id == secondSlot.item.id) {
      // Match found! +10 base, +5 first-try bonus
      final isFirstTry = firstSlot.flipCount == 1 && secondSlot.flipCount == 1;
      final earned = isFirstTry ? 15 : 10;

      setState(() {
        firstSlot.isMatched = true;
        secondSlot.isMatched = true;
        _points += earned;
        _pairsFound++;
        _streak++;
        _encouragementText = isFirstTry
            ? _t('Wonderful memory! (+15)', 'शानदार याददाश्त! (+15)')
            : _t('Great match! You found it! (+10)', 'बहुत बढ़िया जोड़ी! (+10)');
        _firstFlippedIndex = null;
        _secondFlippedIndex = null;
      });

      _difficultyEngine.adaptDifficulty(
        lastAnswerCorrect: true,
        currentStreak: _streak,
        responseTimeMs: turnMs,
      );

      if (_pairsFound == _pairCountForLevel) {
        _finishBoard();
      }
    } else {
      // Mismatch: 0 penalty, calm neutral message, look together briefly before flipping back
      _streak = 0;
      _difficultyEngine.adaptDifficulty(
        lastAnswerCorrect: false,
        currentStreak: 0,
        responseTimeMs: turnMs,
      );

      setState(() {
        _isWaitingCalmFlipBack = true;
        _encouragementText = _t(
          'Let’s look together, then try another pair.',
          'एक साथ देखें, फिर दूसरी जोड़ी आज़माएँ।',
        );
      });

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() {
          firstSlot.isFaceUp = false;
          secondSlot.isFaceUp = false;
          _firstFlippedIndex = null;
          _secondFlippedIndex = null;
          _isWaitingCalmFlipBack = false;
        });
      });
    }
  }

  void _finishBoard() {
    _sessionStopwatch.stop();
    final avgMs = _turnDurationsMs.isEmpty
        ? 3000
        : (_turnDurationsMs.reduce((a, b) => a + b) ~/ _turnDurationsMs.length);
    final accuracy = _totalTurns == 0
        ? 1.0
        : (_pairsFound / _totalTurns).clamp(0.0, 1.0);

    setState(() {
      _points += 25; // Board completion bonus (+20-30)
      _boardCompleted = true;
      _encouragementText = _t(
        'You finished the whole game — well done!',
        'आपने पूरा खेल पूरा किया — बहुत बढ़िया!',
      );
    });

    ReminderNotificationService.speakReminder(_encouragementText);

    SessionLogger.logSession(
      game: 'memory_pairs',
      level: _difficultyEngine.currentLevel,
      accuracy: accuracy,
      avgResponseMs: avgMs,
      language: widget.isHindi ? 'hi' : 'en',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pairCount = _pairCountForLevel;
    final crossAxisCount = pairCount <= 6 ? 2 : 4;

    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      appBar: AppBar(
        title: Text(_t(
          'Memory Pairs • Level ${_difficultyEngine.currentLevel}',
          'चित्र मिलान • स्तर ${_difficultyEngine.currentLevel}',
        )),
        backgroundColor: Colors.teal.shade900,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: _boardCompleted
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.emoji_events, size: 88, color: Colors.amberAccent),
                    const SizedBox(height: 16),
                    Text(
                      _encouragementText,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t('Points Earned: $_points', 'अर्जित अंक: $_points'),
                      style: const TextStyle(fontSize: 24, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 66,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _setupBoard,
                        icon: const Icon(Icons.refresh, size: 30, color: Colors.white),
                        label: Text(
                          _t('Play Another Round', 'एक और दौर खेलें'),
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
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Positive Score & Progress Banner (No countdown timer!)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _t('Pairs: $_pairsFound / $pairCount', 'जोड़ी: $_pairsFound / $pairCount'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          _t('Points: $_points', 'अंक: $_points'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _encouragementText,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: Colors.tealAccent),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // High-Contrast Card Grid
                  Expanded(
                    child: GridView.builder(
                      itemCount: _cards.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: crossAxisCount == 2 ? 1.45 : 0.95,
                      ),
                      itemBuilder: (context, index) {
                        final slot = _cards[index];
                        final showFront = slot.isFaceUp || slot.isMatched;

                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _onCardTap(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            decoration: BoxDecoration(
                              color: slot.isMatched
                                  ? Colors.teal.shade900
                                  : (showFront ? const Color(0xFF263238) : Colors.blueGrey.shade800),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: slot.isMatched
                                    ? Colors.tealAccent
                                    : (showFront ? slot.item.accentColor : Colors.white24),
                                width: 2.5,
                              ),
                            ),
                            child: showFront
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(slot.item.icon, size: 42, color: slot.item.accentColor),
                                      const SizedBox(height: 6),
                                      Text(
                                        _t(slot.item.labelEn, slot.item.labelHi),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  )
                                : const Center(
                                    child: Icon(Icons.help_outline, size: 44, color: Colors.white54),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
