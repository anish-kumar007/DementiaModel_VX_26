class DifficultyEngine {
  int _currentLevel = 1;
  int _consecutiveMisses = 0;

  int get currentLevel => _currentLevel;

  /// Adapts game difficulty based on streak, accuracy, and response speed.
  /// Raises level after a streak of quick correct answers; lowers after
  /// repeated misses or very slow answers. Never exposes a failing score.
  void adaptDifficulty({
    required bool lastAnswerCorrect,
    required int currentStreak,
    int? responseTimeMs,
  }) {
    final bool isSlow = responseTimeMs != null && responseTimeMs > 12000;

    if (lastAnswerCorrect && !isSlow) {
      _consecutiveMisses = 0;
      if (currentStreak >= 1 && _currentLevel < 5) {
        _currentLevel++;
      }
    } else {
      _consecutiveMisses++;
      if ((_consecutiveMisses >= 2 || isSlow) && _currentLevel > 1) {
        _currentLevel--;
        _consecutiveMisses = 0;
      }
    }
  }

  void reset() {
    _currentLevel = 1;
    _consecutiveMisses = 0;
  }
}
