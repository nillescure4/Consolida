class PracticeTimerState {
  final String? sessionId;
  final int remainingSeconds;
  final int durationMinutes;
  final bool hasDueSession;
  final bool completedToday;
  final String goalTitle;
  final DateTime? scheduledDate;

  const PracticeTimerState({
    required this.sessionId,
    required this.remainingSeconds,
    required this.durationMinutes,
    required this.hasDueSession,
    required this.completedToday,
    this.goalTitle = '',
    this.scheduledDate,
  });
}