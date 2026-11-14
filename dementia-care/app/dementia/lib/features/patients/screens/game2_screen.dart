import 'package:material_ui/material_ui.dart';
import '../services/session_logger.dart';

class Game2Screen extends StatefulWidget {
  const Game2Screen({super.key});

  @override
  State<Game2Screen> createState() => _Game2ScreenState();
}

class _Game2ScreenState extends State<Game2Screen> {
  // Placeholder story/word items until Member B's localized content lands
  final List<Map<String, dynamic>> _questions = [
    {
      'prompt': 'You wake up in the morning and brush your teeth. What do you use?',
      'options': ['Toothbrush', 'Spoon', 'Hammer'],
      'answer': 'Toothbrush',
    },
    {
      'prompt': 'It is raining outside. What should you carry?',
      'options': ['Umbrella', 'Sunglasses', 'Pillow'],
      'answer': 'Umbrella',
    },
  ];

  int _currentIndex = 0;
  int _score = 0;
  bool _completed = false;

  void _submitOption(String selected) {
    final isCorrect = selected == _questions[_currentIndex]['answer'];
    setState(() {
      if (isCorrect) _score += 25;

      if (_currentIndex + 1 < _questions.length) {
        _currentIndex++;
      } else {
        _completed = true;
        SessionLogger.logSession(
          gameName: 'Game 2 - Daily Recall',
          score: _score,
          difficultyLevel: 1,
          completed: true,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Story & Word Recall'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _completed
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, size: 80, color: Colors.amber),
                    const SizedBox(height: 16),
                    Text(
                      'Wonderful! You scored $_score points.',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Home', style: TextStyle(fontSize: 22)),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentQ['prompt'],
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  ...(currentQ['options'] as List<String>).map((option) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _submitOption(option),
                        child: Text(
                          option,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}
