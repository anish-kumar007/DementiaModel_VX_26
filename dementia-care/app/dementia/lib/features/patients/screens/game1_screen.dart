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
  final Color iconColor;
  final Color cardTint;

  const _MemoryItem({
    required this.id,
    required this.labelEn,
    required this.labelHi,
    required this.icon,
    required this.iconColor,
    required this.cardTint,
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
    _MemoryItem(
      id: 'cup',
      labelEn: 'Tea Cup',
      labelHi: 'चाय का कप',
      icon: Icons.local_cafe,
      iconColor: Color(0xFFB45309),
      cardTint: Color(0xFFFEF3C7),
    ),
    _MemoryItem(
      id: 'flower',
      labelEn: 'Marigold',
      labelHi: 'गेंदे का फूल',
      icon: Icons.local_florist,
      iconColor: Color(0xFFC2410C),
      cardTint: Color(0xFFFFEDD5),
    ),
    _MemoryItem(
      id: 'home',
      labelEn: 'Home',
      labelHi: 'घर',
      icon: Icons.home,
      iconColor: Color(0xFF0F766E),
      cardTint: Color(0xFFCCFBF1),
    ),
    _MemoryItem(
      id: 'lamp',
      labelEn: 'Lamp',
      labelHi: 'दीपक',
      icon: Icons.lightbulb,
      iconColor: Color(0xFFA16207),
      cardTint: Color(0xFFFEF9C3),
    ),
    _MemoryItem(
      id: 'apple',
      labelEn: 'Apple',
      labelHi: 'सेब',
      icon: Icons.eco,
      iconColor: Color(0xFF15803D),
      cardTint: Color(0xFFDCFCE7),
    ),
    _MemoryItem(
      id: 'book',
      labelEn: 'Book',
      labelHi: 'किताब',
      icon: Icons.menu_book,
      iconColor: Color(0xFF1D4ED8),
      cardTint: Color(0xFFDBEAFE),
    ),
    _MemoryItem(
      id: 'umbrella',
      labelEn: 'Umbrella',
      labelHi: 'छाता',
      icon: Icons.umbrella,
      iconColor: Color(0xFF6D28D9),
      cardTint: Color(0xFFEDE9FE),
    ),
    _MemoryItem(
      id: 'cat',
      labelEn: 'Cat',
      labelHi: 'बिल्ली',
      icon: Icons.pets,
      iconColor: Color(0xFFBE185D),
      cardTint: Color(0xFFFCE7F3),
    ),
    _MemoryItem(
      id: 'sun',
      labelEn: 'Morning Sun',
      labelHi: 'सूरज',
      icon: Icons.wb_sunny,
      iconColor: Color(0xFFD97706),
      cardTint: Color(0xFFFEF3C7),
    ),
    _MemoryItem(
      id: 'key',
      labelEn: 'House Key',
      labelHi: 'चाबी',
      icon: Icons.vpn_key,
      iconColor: Color(0xFF374151),
      cardTint: Color(0xFFF3F4F6),
    ),
  ];

  late List<_CardSlot> _cards;
  int? _firstFlippedIndex;
  int? _secondFlippedIndex;
  bool _isWaitingCalmFlipBack = false;

  int _selectedLevel = 1;
  int _points = 0;
  int _pairsFound = 0;
  int _totalTurns = 0;
  int _streak = 0;
  bool _boardCompleted = false;
  bool _caregiverBonusAwarded = false;
  String _encouragementText = '';

  String _t(String en, String hi) => widget.isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    _selectedLevel = _difficultyEngine.currentLevel.clamp(1, 4);
    ReminderNotificationService.initialize(isHindi: widget.isHindi);
    _setupBoard();
  }

  /// PDF Specification:
  /// Level 1: 4 pairs (8 cards - 2x4 grid)
  /// Level 2: 6 pairs (12 cards - 3x4 grid)
  /// Level 3: 8 pairs (16 cards - 4x4 grid)
  /// Level 4: 10 pairs (20 cards - 4x5 grid)
  int get _pairCountForLevel {
    switch (_selectedLevel) {
      case 1:
        return 4;
      case 2:
        return 6;
      case 3:
        return 8;
      default:
        return 10;
    }
  }

  int get _columnsForLevel {
    switch (_selectedLevel) {
      case 1:
        return 2; // 2 columns x 4 rows = 8 cards
      case 2:
        return 3; // 3 columns x 4 rows = 12 cards
      default:
        return 4; // 4 columns x 4 or 5 rows = 16 or 20 cards
    }
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
      _caregiverBonusAwarded = false;
      _encouragementText = _t(
        'Let’s turn over any two cards together.',
        'आइए मिलकर कोई भी दो कार्ड पलटें।',
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
      // PDF Scoring: +10 matching a pair, +5 bonus on first try
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
      // PDF Rule: 0 penalty, look together calmly before turning face-down
      _streak = 0;
      _difficultyEngine.adaptDifficulty(
        lastAnswerCorrect: false,
        currentStreak: 0,
        responseTimeMs: turnMs,
      );

      setState(() {
        _isWaitingCalmFlipBack = true;
        _encouragementText = _t(
          'Let’s look at them together, then try another pair.',
          'आइए इन्हें एक साथ देखें, फिर दूसरी जोड़ी आज़माएँ।',
        );
      });

      Future.delayed(const Duration(milliseconds: 1600), () {
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

  void _finishBoard({bool stoppedEarly = false}) {
    _sessionStopwatch.stop();
    final avgMs = _turnDurationsMs.isEmpty
        ? 3000
        : (_turnDurationsMs.reduce((a, b) => a + b) ~/ _turnDurationsMs.length);
    final accuracy = _totalTurns == 0
        ? 1.0
        : (_pairsFound / _totalTurns).clamp(0.0, 1.0);

    setState(() {
      if (!stoppedEarly) {
        _points += 25; // +20–30 board completion bonus
        _encouragementText = _t(
          'You finished the whole game — well done!',
          'आपने पूरा खेल पूरा किया — बहुत बढ़िया!',
        );
      } else {
        _encouragementText = _t(
          'Wonderful session together! We can play more anytime.',
          'साथ में बहुत अच्छा समय बिताया! हम कभी भी फिर खेल सकते हैं।',
        );
      }
      _boardCompleted = true;
    });

    ReminderNotificationService.speakReminder(_encouragementText);

    // Optional tracking saved quietly for caregiver notes (never shown as error/efficiency to patient)
    SessionLogger.logSession(
      game: 'memory_pairs',
      level: _selectedLevel,
      accuracy: accuracy,
      avgResponseMs: avgMs,
      language: widget.isHindi ? 'hi' : 'en',
      rounds: _totalTurns,
      durationMs: _sessionStopwatch.elapsedMilliseconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pairCount = _pairCountForLevel;
    final columns = _columnsForLevel;
    final rows = (pairCount * 2 / columns).ceil();

    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      appBar: AppBar(
        title: Text(
          _t(
            'Memory Pairs • Level $_selectedLevel',
            'चित्र मिलान • स्तर $_selectedLevel',
          ),
        ),
        backgroundColor: Colors.teal.shade900,
        actions: [
          // Gentle optional level switcher (never forces progression)
          PopupMenuButton<int>(
            icon: const Icon(Icons.tune, color: Colors.white, size: 28),
            tooltip: _t('Choose Level', 'स्तर चुनें'),
            onSelected: (lvl) {
              setState(() => _selectedLevel = lvl);
              _setupBoard();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 1,
                child: Text(_t('Level 1 • 4 Pairs (2×4)', 'स्तर 1 • 4 जोड़ी (2×4)')),
              ),
              PopupMenuItem(
                value: 2,
                child: Text(_t('Level 2 • 6 Pairs (3×4)', 'स्तर 2 • 6 जोड़ी (3×4)')),
              ),
              PopupMenuItem(
                value: 3,
                child: Text(_t('Level 3 • 8 Pairs (4×4)', 'स्तर 3 • 8 जोड़ी (4×4)')),
              ),
              PopupMenuItem(
                value: 4,
                child: Text(_t('Level 4 • 10 Pairs (4×5)', 'स्तर 4 • 10 जोड़ी (4×5)')),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _boardCompleted
              ? _buildCompletionView()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Positive Score & Progress Header (No countdown timer!)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.style,
                                color: Colors.tealAccent,
                                size: 26,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _t(
                                  'Pairs: $_pairsFound / $pairCount',
                                  'जोड़ी: $_pairsFound / $pairCount',
                                ),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.amberAccent,
                                size: 28,
                              ),
                              const SizedBox(width: 6),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Supportive Encouragement Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade900.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _encouragementText,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: Colors.tealAccent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Responsive High-Clarity Grid (Fits screen cleanly without cramped scrolling)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const spacing = 12.0;
                          final totalHSpacing = spacing * (columns - 1);
                          final totalVSpacing = spacing * (rows - 1);
                          final cardWidth =
                              (constraints.maxWidth - totalHSpacing) / columns;
                          final cardHeight =
                              (constraints.maxHeight - totalVSpacing) / rows;
                          final aspectRatio =
                              (cardWidth / cardHeight).clamp(0.75, 1.85);

                          return GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _cards.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: spacing,
                              mainAxisSpacing: spacing,
                              childAspectRatio: aspectRatio,
                            ),
                            itemBuilder: (context, index) {
                              final slot = _cards[index];
                              final showFront =
                                  slot.isFaceUp || slot.isMatched;

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => _onCardTap(index),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 260),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      // High-contrast light warm surface when revealed so images/labels are effortless to see
                                      color: showFront
                                          ? (slot.isMatched
                                              ? const Color(0xFFD1FAE5)
                                              : slot.item.cardTint)
                                          : const Color(0xFF1E3A5F),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: slot.isMatched
                                            ? Colors.teal.shade700
                                            : (showFront
                                                ? slot.item.iconColor
                                                : Colors.lightBlueAccent
                                                    .withOpacity(0.5)),
                                        width: slot.isMatched ? 3.5 : 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: showFront
                                        ? Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Icon(
                                                    slot.item.icon,
                                                    size: columns == 2
                                                        ? 54
                                                        : (columns == 3
                                                            ? 44
                                                            : 36),
                                                    color: slot.item.iconColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                _t(
                                                  slot.item.labelEn,
                                                  slot.item.labelHi,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize:
                                                      columns == 2 ? 20 : 16,
                                                  fontWeight: FontWeight.w800,
                                                  color:
                                                      const Color(0xFF111827),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          )
                                        : Center(
                                            child: Icon(
                                              Icons.spa_outlined,
                                              size: columns == 2 ? 46 : 34,
                                              color: Colors.white60,
                                            ),
                                          ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // PDF Principle: Stop anytime while still enjoying the activity
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white38),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _finishBoard(stoppedEarly: true),
                        icon: const Icon(
                          Icons.pause_circle_outline,
                          color: Colors.white70,
                        ),
                        label: Text(
                          _t(
                            'Finish & Rest Anytime',
                            'अभी रुकें और विश्राम करें',
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCompletionView() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events,
              size: 88,
              color: Colors.amberAccent,
            ),
            const SizedBox(height: 16),
            Text(
              _encouragementText,
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
                color: Colors.tealAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // PDF Scoring: +10 session bonus given by caregiver for calm engagement
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
                      'Caregiver Bonus: Great Focus (+10)',
                      'देखभालकर्ता बोनस: शानदार एकाग्रता (+10)',
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
                  backgroundColor: Colors.teal.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _setupBoard,
                icon: const Icon(Icons.refresh, size: 30, color: Colors.white),
                label: Text(
                  _t('Play Another Round', 'एक और दौर खेलें'),
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
