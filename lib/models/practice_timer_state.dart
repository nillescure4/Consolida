class PracticeTimerState {
  final String? sessionId;
  final int remainingSeconds;
  final int durationMinutes;
  final bool hasDueSession;
  final bool completedToday;

  const PracticeTimerState({
    required this.sessionId,
    required this.remainingSeconds,
    required this.durationMinutes,
    required this.hasDueSession,
    required this.completedToday,
  });

  bool get canPractice => hasDueSession || completedToday;
}