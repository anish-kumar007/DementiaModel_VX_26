import 'package:material_ui/material_ui.dart';
import '../services/difficulty_engine.dart';
import '../services/session_logger.dart';

class Game1Screen extends StatefulWidget {
  const Game1Screen({super.key});

  @override
  State<Game1Screen> createState() => _Game1ScreenState();
}

class _Game1ScreenState extends State<Game1Screen> {
  final DifficultyEngine _difficultyEngine = DifficultyEngine();
  int _score = 0;
  int _streak = 0;
  bool _gameOver = false;

  void _handleAnswer(bool correct) {
    setState(() {
      if (correct) {
        _score += 10 * _difficultyEngine.currentLevel;
        _streak++;
      } else {
        _streak = 0;
      }

      _difficultyEngine.adaptDifficulty(
        lastGameWon: correct,
        currentStreak: _streak,
      );

      if (_score >= 50) {
        _gameOver = true;
        SessionLogger.logSession(
          gameName: 'Game 1 - Memory Match',
          score: _score,
          difficultyLevel: _difficultyEngine.currentLevel,
          completed: true,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Memory Game (Level ${_difficultyEngine.currentLevel})'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _gameOver
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
                    const SizedBox(height: 20),
                    const Text(
                      'Great Job! Session Completed.',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.all(16)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Return Home', style: TextStyle(fontSize: 22)),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Score: $_score',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Tap the matching card or picture:',
                    style: TextStyle(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _handleAnswer(true),
                    child: const Text('Correct Match', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _handleAnswer(false),
                    child: const Text('Wrong Match', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
      ),
    );
  }
}
