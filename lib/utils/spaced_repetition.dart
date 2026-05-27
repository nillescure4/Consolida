import '../models/goal_type.dart';

List<DateTime> generateSpacedPracticeDates({
  required GoalType type,
  required DateTime startDate,
  DateTime? targetDate,
  required int minutesPerSession,
}) {
  final dates = <DateTime>[];

  final cappedMinutes = minutesPerSession > 30 ? 30 : minutesPerSession;
  final durationFactor = cappedMinutes / 30.0;

  final cleanStartDate = DateTime(
    startDate.year,
    startDate.month,
    startDate.day,
  );

  dates.add(cleanStartDate);

  if (type == GoalType.longTerm) {
    const oneYearDays = 365;

    final initialGap = (oneYearDays * 0.05 * durationFactor).round();
    final finalGap = (oneYearDays * 0.10 * durationFactor).round();

    var currentDate = cleanStartDate;
    var currentGap = initialGap < 1 ? 1 : initialGap;
    final maxGap = finalGap < 1 ? 1 : finalGap;

    final oneYearLater = cleanStartDate.add(
      const Duration(days: oneYearDays),
    );

    while (currentDate.isBefore(oneYearLater)) {
      final nextDate = currentDate.add(
        Duration(days: currentGap),
      );

      dates.add(nextDate);
      currentDate = nextDate;

      if (currentGap < maxGap) {
        currentGap += 1;
      }
    }

    return dates;
  }

  if (targetDate == null) {
    throw Exception('Aquest objectiu necessita una data final.');
  }

  final cleanTargetDate = DateTime(
    targetDate.year,
    targetDate.month,
    targetDate.day,
  );

  final totalDays = cleanTargetDate.difference(cleanStartDate).inDays;

  if (totalDays <= 0) {
    throw Exception('La data final ha de ser posterior a avui.');
  }

  double initialPercentage;
  double finalPercentage;

  if (type == GoalType.shortTerm) {
    initialPercentage = 0.25;
    finalPercentage = 0.30;
  } else {
    initialPercentage = 0.15;
    finalPercentage = 0.20;
  }

  final initialGap = (totalDays * initialPercentage * durationFactor).round();
  final finalGap = (totalDays * finalPercentage * durationFactor).round();

  var currentDate = cleanStartDate;
  var currentGap = initialGap < 1 ? 1 : initialGap;
  final maxGap = finalGap < 1 ? 1 : finalGap;

  while (true) {
    final nextDate = currentDate.add(
      Duration(days: currentGap),
    );

    if (nextDate.isAfter(cleanTargetDate)) {
      break;
    }

    dates.add(nextDate);
    currentDate = nextDate;

    if (currentGap < maxGap) {
      currentGap += 1;
    }
  }

  final alreadyContainsTargetDate = dates.any(
    (date) =>
        date.year == cleanTargetDate.year &&
        date.month == cleanTargetDate.month &&
        date.day == cleanTargetDate.day,
  );

  if (!alreadyContainsTargetDate) {
    dates.add(cleanTargetDate);
  }

  return dates;
}