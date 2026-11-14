class DifficultyEngine {
  int _currentLevel = 1;
  int get currentLevel => _currentLevel;

  void adaptDifficultyy({
    required bool lastGameWon,
    required int currentStreak,
  }) {
    if (lastGameWon) {
      if (lastGameWon && currentStreak >= 2) {
        if (_currentLevel < 5) {
          _currentLevel++;
        }
      }
    } else if (!lastGameWon && _currentLevel > 1) {
      _currentLevel--;
    }
  }

  void reset() {
    _currentLevel = 1;
  }
}
