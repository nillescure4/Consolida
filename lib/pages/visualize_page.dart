import 'dart:math';

import 'package:flutter/material.dart';

import '../models/practice_attempt.dart';
import '../models/practice_session.dart';
import '../models/study_goal.dart';
import '../models/subject.dart';
import '../services/objective_service.dart';
import '../services/practice_stats_service.dart';
import '../widgets/app_scaffold.dart';
import '../theme/app_theme.dart';

class VisualizePage extends StatelessWidget {
  final Subject subject;

  const VisualizePage({
    super.key,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    final objectiveService = ObjectiveService();
    final statsService = PracticeStatsService();

    return AppScaffold(
      title: 'Veure progrés - ${subject.name}',
      child: StreamBuilder<List<StudyGoal>>(
        stream: objectiveService.getGoals(subject.id),
        builder: (context, goalsSnapshot) {
          final goals = goalsSnapshot.data ?? [];

          return StreamBuilder<List<PracticeSession>>(
            stream: objectiveService.getPracticeSessions(subject.id),
            builder: (context, sessionsSnapshot) {
              final sessions = sessionsSnapshot.data ?? [];

              return StreamBuilder<List<PracticeAttempt>>(
                stream: statsService.watchAttempts(subject.id),
                builder: (context, attemptsSnapshot) {
                  final attempts = attemptsSnapshot.data ?? [];

                  final stats = _ProgressStats.fromData(
                    goals: goals,
                    sessions: sessions,
                    attempts: attempts,
                  );

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Resum del progrés',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _MetricGrid(stats: stats),
                      const SizedBox(height: 16),
                      _ProgressBarCard(stats: stats),
                      const SizedBox(height: 16),
                      _ErrorCard(stats: stats),
                      const SizedBox(height: 16),
                      _ForgettingCurveCard(stats: stats),
                      const SizedBox(height: 16),
                      _ActivityBreakdownCard(stats: stats),
                      const SizedBox(height: 16),
                      _UpcomingSessionsCard(sessions: sessions),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _KnowledgePoint {
  final DateTime date;
  final double knowledgePercentage;
  final double errorRate;

  const _KnowledgePoint({
    required this.date,
    required this.knowledgePercentage,
    required this.errorRate,
  });
}

class _ProgressStats {
  final int completedSessions;
  final int pendingSessions;
  final int totalSessions;
  final int daysUntilTarget;
  final double completionRate;
  final double lastSessionErrorRate;
  final double totalErrorRate;
  final Map<String, int> attemptsByActivity;
  final Map<String, int> errorsByActivity;
  final List<_KnowledgePoint> knowledgePoints;
  final DateTime? objectiveStartDate;
  final DateTime? chartStartDate;
  final DateTime? chartEndDate;

  const _ProgressStats({
    required this.completedSessions,
    required this.pendingSessions,
    required this.totalSessions,
    required this.daysUntilTarget,
    required this.completionRate,
    required this.lastSessionErrorRate,
    required this.totalErrorRate,
    required this.attemptsByActivity,
    required this.errorsByActivity,
    required this.knowledgePoints,
    required this.objectiveStartDate,
    required this.chartStartDate,
    required this.chartEndDate,
  });

  factory _ProgressStats.fromData({
    required List<StudyGoal> goals,
    required List<PracticeSession> sessions,
    required List<PracticeAttempt> attempts,
  }) {
    final completedSessions =
        sessions.where((session) => session.status == 'completed').length;

    final pendingSessions =
        sessions.where((session) => session.status == 'pending').length;

    final totalSessions = sessions.length;

    final completionRate =
        totalSessions == 0 ? 0.0 : completedSessions / totalSessions;

    final sortedGoals = List<StudyGoal>.from(goals)
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });

    final objectiveStartDate =
        sortedGoals.isEmpty ? null : sortedGoals.first.createdAt;

    final targetDates = goals
        .where((goal) => goal.targetDate != null)
        .map((goal) => goal.targetDate!)
        .toList()
      ..sort();

    final now = DateTime.now();

    final chartStartDate = objectiveStartDate ??
        (sessions.isEmpty
            ? now
            : (List<PracticeSession>.from(sessions)
                  ..sort(
                    (a, b) => a.scheduledDate.compareTo(b.scheduledDate),
                  ))
                .first
                .scheduledDate);

    final chartEndDate = targetDates.isNotEmpty
        ? targetDates.first
        : chartStartDate.add(const Duration(days: 365));

    final daysUntilTarget =
        targetDates.isEmpty ? -1 : max(0, targetDates.first.difference(now).inDays);

    final sortedAttempts = List<PracticeAttempt>.from(attempts)
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    final latestSessionId =
        sortedAttempts.isEmpty ? '' : sortedAttempts.first.sessionId;

    final lastSessionAttempts = sortedAttempts
        .where((attempt) => attempt.sessionId == latestSessionId)
        .toList();

    final lastSessionErrors =
        lastSessionAttempts.where((attempt) => !attempt.isCorrect).length;

    final totalErrors = attempts.where((attempt) => !attempt.isCorrect).length;

    final lastSessionErrorRate = lastSessionAttempts.isEmpty
        ? 0.0
        : lastSessionErrors / lastSessionAttempts.length;

    final totalErrorRate = attempts.isEmpty ? 0.0 : totalErrors / attempts.length;

    final attemptsByActivity = <String, int>{};
    final errorsByActivity = <String, int>{};

    for (final attempt in attempts) {
      attemptsByActivity[attempt.activityType] =
          (attemptsByActivity[attempt.activityType] ?? 0) + 1;

      if (!attempt.isCorrect) {
        errorsByActivity[attempt.activityType] =
            (errorsByActivity[attempt.activityType] ?? 0) + 1;
      }
    }

    final attemptsBySession = <String, List<PracticeAttempt>>{};

    for (final attempt in attempts) {
      if (attempt.sessionId.isEmpty || attempt.createdAt == null) continue;

      attemptsBySession.putIfAbsent(attempt.sessionId, () => []);
      attemptsBySession[attempt.sessionId]!.add(attempt);
    }

    final knowledgePoints = <_KnowledgePoint>[];

    for (final entry in attemptsBySession.entries) {
      final sessionAttempts = entry.value;

      final attemptsWithDate = sessionAttempts
          .where((attempt) => attempt.createdAt != null)
          .toList()
        ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

      if (attemptsWithDate.isEmpty) continue;

      final date = attemptsWithDate.first.createdAt!;
      final errors =
          sessionAttempts.where((attempt) => !attempt.isCorrect).length;

      final errorRate =
          sessionAttempts.isEmpty ? 0.0 : errors / sessionAttempts.length;

      knowledgePoints.add(
        _KnowledgePoint(
          date: date,
          errorRate: errorRate,
          knowledgePercentage: 1 - errorRate,
        ),
      );
    }

    knowledgePoints.sort((a, b) => a.date.compareTo(b.date));

    return _ProgressStats(
      completedSessions: completedSessions,
      pendingSessions: pendingSessions,
      totalSessions: totalSessions,
      daysUntilTarget: daysUntilTarget,
      completionRate: completionRate,
      lastSessionErrorRate: lastSessionErrorRate,
      totalErrorRate: totalErrorRate,
      attemptsByActivity: attemptsByActivity,
      errorsByActivity: errorsByActivity,
      knowledgePoints: knowledgePoints,
      objectiveStartDate: objectiveStartDate,
      chartStartDate: chartStartDate,
      chartEndDate: chartEndDate,
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final _ProgressStats stats;

  const _MetricGrid({
    required this.stats,
  });

  int _crossAxisCount(double width) {
    if (width >= 1100) return 4;
    return 2;
  }

  double _maxContentWidth(double width) {
    if (width >= 1100) return 1000;
    if (width >= 700) return 680;
    return double.infinity;
  }

  double _childAspectRatio(double width) {
    if (width >= 1100) return 1.25;
    if (width >= 700) return 1.35;
    return 1.6;
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(
        title: 'Dies practicats',
        value: stats.completedSessions.toString(),
      ),
      _MetricCard(
        title: 'Sessions pendents',
        value: stats.pendingSessions.toString(),
      ),
      _MetricCard(
        title: 'Dies fins data límit',
        value: stats.daysUntilTarget < 0
            ? 'Sense límit'
            : stats.daysUntilTarget.toString(),
      ),
      _MetricCard(
        title: 'Progrés total',
        value: '${(stats.completionRate * 100).round()}%',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _maxContentWidth(width),
            ),
            child: GridView.count(
              crossAxisCount: _crossAxisCount(width),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: _childAspectRatio(width),
              children: cards,
            ),
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;

  const _MetricCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBarCard extends StatelessWidget {
  final _ProgressStats stats;

  const _ProgressBarCard({
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compliment de sessions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: stats.completionRate,
              minHeight: 14,
            ),
            const SizedBox(height: 8),
            Text(
              '${stats.completedSessions}/${stats.totalSessions} sessions completades',
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final _ProgressStats stats;

  const _ErrorCard({
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final last = (stats.lastSessionErrorRate * 100).round();
    final total = (stats.totalErrorRate * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Errors',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text('Última sessió: $last% d’error'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: stats.lastSessionErrorRate),
            const SizedBox(height: 16),
            Text('Total de pràctiques: $total% d’error'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: stats.totalErrorRate),
          ],
        ),
      ),
    );
  }
}

class _ForgettingCurveCard extends StatelessWidget {
  final _ProgressStats stats;

  const _ForgettingCurveCard({
    required this.stats,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasPoints = stats.knowledgePoints.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comparació amb la corba de l’oblit',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Què és la corba de l’oblit?'),
              children: const [
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'La corba de l’oblit és una corba teòrica que mostra com el coneixement disminueix amb el temps si no es repassa (Ebbinghaus, 1885). En aquesta visualització, la línia negre és la corba de l’oblit i en taronja pots veure el teu nivell d’oblit. D’aquesta manera pots comparar com de consolidat tens el coneixement comparat amb si no haguessis fer servir Consolida. Els punts representen el teu coneixement estimat a cada pràctica.',
                    textAlign: TextAlign.justify,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Inici: ${_formatDate(stats.chartStartDate)} · Final: ${_formatDate(stats.chartEndDate)}',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 310,
              child: CustomPaint(
                painter: _ForgettingCurvePainter(
                  points: stats.knowledgePoints,
                  startDate: stats.chartStartDate,
                  endDate: stats.chartEndDate,
                ),
                child: Container(),
              ),
            ),
            const SizedBox(height: 12),
            const _LegendItem(
              line: true,
              label: 'Corba de l’oblit teòrica sense repàs',
            ),
            const SizedBox(height: 6),
            const _LegendItem(
              line: false,
              label: 'El teu coneixement estimat segons % d’error',
            ),
            const SizedBox(height: 12),
            if (!hasPoints)
              const Text(
                'Encara no hi ha punts perquè no hi ha intents registrats. Practica algunes preguntes i la gràfica es començarà a generar automàticament.',
              )
            else
              Text(
                'Últim coneixement estimat: ${(stats.knowledgePoints.last.knowledgePercentage * 100).round()}%',
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final bool line;
  final String label;

  const _LegendItem({
    required this.line,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CustomPaint(
          size: const Size(34, 14),
          painter: _LegendPainter(line: line),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label),
        ),
      ],
    );
  }
}

class _LegendPainter extends CustomPainter {
  final bool line;

  const _LegendPainter({
    required this.line,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line ? Colors.black : AppColors.primary
      ..strokeWidth = line ? 3 : 0
      ..style = line ? PaintingStyle.stroke : PaintingStyle.fill;

    if (line) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    } else {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LegendPainter oldDelegate) {
    return oldDelegate.line != line;
  }
}

class _ForgettingCurvePainter extends CustomPainter {
  final List<_KnowledgePoint> points;
  final DateTime? startDate;
  final DateTime? endDate;

  _ForgettingCurvePainter({
    required this.points,
    required this.startDate,
    required this.endDate,
  });

  final List<Map<String, double>> _ebbinghausAnchors = const [
    {'days': 0.0, 'retention': 1.00},
    {'days': 20 / 1440, 'retention': 0.58},
    {'days': 1 / 24, 'retention': 0.44},
    {'days': 9 / 24, 'retention': 0.36},
    {'days': 1.0, 'retention': 0.34},
    {'days': 2.0, 'retention': 0.28},
    {'days': 6.0, 'retention': 0.25},
    {'days': 31.0, 'retention': 0.21},
    {'days': 365.0, 'retention': 0.15},
  ];

  double _ebbinghausRetention(double daysSinceStart) {
    if (daysSinceStart <= 0) return 1.0;

    for (int i = 0; i < _ebbinghausAnchors.length - 1; i++) {
      final current = _ebbinghausAnchors[i];
      final next = _ebbinghausAnchors[i + 1];

      final currentDays = current['days']!;
      final nextDays = next['days']!;

      if (daysSinceStart >= currentDays && daysSinceStart <= nextDays) {
        final currentRetention = current['retention']!;
        final nextRetention = next['retention']!;

        final safeCurrentDays = max(currentDays, 0.001);
        final safeDays = max(daysSinceStart, 0.001);

        final logStart = log(safeCurrentDays);
        final logEnd = log(nextDays);
        final logNow = log(safeDays);

        final ratio =
            ((logNow - logStart) / (logEnd - logStart)).clamp(0.0, 1.0);

        return currentRetention +
            (nextRetention - currentRetention) * ratio;
      }
    }

    final lastRetention = _ebbinghausAnchors.last['retention']!;
    const minimumLongTermRetention = 0.12;

    final extraDays = daysSinceStart - 365.0;
    final slowDecay = exp(-extraDays / 1000.0);

    return minimumLongTermRetention +
        (lastRetention - minimumLongTermRetention) * slowDecay;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 0.4
      ..style = PaintingStyle.stroke;

    final forgettingPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final pointLinePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const left = 56.0;
    final right = size.width - 18;
    const top = 18.0;
    final bottom = size.height - 62;

    canvas.drawLine(
      const Offset(left, top),
      Offset(left, bottom),
      axisPaint,
    );

    canvas.drawLine(
      Offset(left, bottom),
      Offset(right, bottom),
      axisPaint,
    );

    _drawText(
      canvas: canvas,
      text: 'Retenció (%)',
      offset: const Offset(0, 0),
      fontSize: 11,
    );

    _drawText(
      canvas: canvas,
      text: 'Temps',
      offset: Offset((left + right) / 2 - 16, size.height - 16),
      fontSize: 11,
    );

    for (int i = 0; i <= 5; i++) {
      final value = i / 5;
      final y = bottom - (bottom - top) * value;

      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        gridPaint,
      );

      canvas.drawLine(
        Offset(left - 4, y),
        Offset(left, y),
        axisPaint,
      );

      _drawText(
        canvas: canvas,
        text: '${(value * 100).round()}',
        offset: Offset(14, y - 7),
        fontSize: 10,
      );
    }

    final safeStart = startDate ?? DateTime.now();
    final safeEnd = endDate ?? safeStart.add(const Duration(days: 365));

    final totalDays = max(1, safeEnd.difference(safeStart).inDays);

    final xLabels = [
      safeStart,
      safeStart.add(Duration(days: (totalDays * 0.25).round())),
      safeStart.add(Duration(days: (totalDays * 0.50).round())),
      safeStart.add(Duration(days: (totalDays * 0.75).round())),
      safeEnd,
    ];

    for (final labelDate in xLabels) {
      final ratio = labelDate.difference(safeStart).inDays / totalDays;
      final x = left + (right - left) * ratio.clamp(0.0, 1.0);

      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        gridPaint,
      );

      canvas.drawLine(
        Offset(x, bottom),
        Offset(x, bottom + 4),
        axisPaint,
      );

      _drawText(
        canvas: canvas,
        text: '${labelDate.day}/${labelDate.month}',
        offset: Offset(x - 15, bottom + 8),
        fontSize: 10,
      );
    }

    final forgettingPath = Path();

    for (int i = 0; i <= 180; i++) {
      final t = i / 180;
      final x = left + (right - left) * t;

      final daysSinceStart = totalDays * t;
      final retention = _ebbinghausRetention(daysSinceStart);

      final y = bottom - (bottom - top) * retention;

      if (i == 0) {
        forgettingPath.moveTo(x, y);
      } else {
        forgettingPath.lineTo(x, y);
      }
    }

    canvas.drawPath(forgettingPath, forgettingPaint);

    final validPoints = points.where((point) {
      return !point.date.isBefore(safeStart) && !point.date.isAfter(safeEnd);
    }).toList();

    if (validPoints.isEmpty) return;

    final pointOffsets = <Offset>[];

    for (final point in validPoints) {
      final daysFromStart = point.date.difference(safeStart).inHours / 24.0;

      final xRatio = daysFromStart / totalDays;

      final x = left + (right - left) * xRatio.clamp(0.0, 1.0);

      final y =
          bottom - (bottom - top) * point.knowledgePercentage.clamp(0.0, 1.0);

      pointOffsets.add(Offset(x, y));
    }

    if (pointOffsets.length >= 2) {
      final path = Path()
        ..moveTo(pointOffsets.first.dx, pointOffsets.first.dy);

      for (final offset in pointOffsets.skip(1)) {
        path.lineTo(offset.dx, offset.dy);
      }

      canvas.drawPath(path, pointLinePaint);
    }

    for (int i = 0; i < pointOffsets.length; i++) {
      final offset = pointOffsets[i];

      canvas.drawCircle(offset, 5, pointPaint);

      final label = '${(validPoints[i].knowledgePercentage * 100).round()}%';

      _drawText(
        canvas: canvas,
        text: label,
        offset: Offset(offset.dx - 12, offset.dy - 22),
        fontSize: 10,
      );
    }
  }

  void _drawText({
    required Canvas canvas,
    required String text,
    required Offset offset,
    required double fontSize,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ForgettingCurvePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.startDate != startDate ||
        oldDelegate.endDate != endDate;
  }
}

class _ActivityBreakdownCard extends StatelessWidget {
  final _ProgressStats stats;

  const _ActivityBreakdownCard({
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final entries = stats.attemptsByActivity.entries.toList();

    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Encara no hi ha intents registrats. Practica unes quantes preguntes i aquí veuràs estadístiques per modalitat.',
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rendiment per modalitat',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...entries.map((entry) {
              final total = entry.value;
              final errors = stats.errorsByActivity[entry.key] ?? 0;
              final errorRate = total == 0 ? 0.0 : errors / total;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entry.key}: ${(errorRate * 100).round()}% error'),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: errorRate),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _UpcomingSessionsCard extends StatelessWidget {
  final List<PracticeSession> sessions;

  const _UpcomingSessionsCard({
    required this.sessions,
  });

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = sessions.where((session) => session.status == 'pending').toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    final groupedByGoal = <String, List<PracticeSession>>{};

    for (final session in upcoming) {
      groupedByGoal.putIfAbsent(session.goalTitle, () => []);
      groupedByGoal[session.goalTitle]!.add(session);
    }

    final hasMoreThanThree = groupedByGoal.values.any(
      (goalSessions) => goalSessions.length > 3,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Properes sessions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (upcoming.isEmpty)
              const Text('No hi ha sessions pendents.'),
            ...groupedByGoal.entries.map(
              (entry) {
                final goalTitle = entry.key;
                final goalSessions = entry.value;
                final visibleSessions = goalSessions.take(3).toList();
                final hiddenCount = goalSessions.length - visibleSessions.length;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goalTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...visibleSessions.map(
                        (session) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_formatDate(session.scheduledDate)} · ${session.durationMinutes} min',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (hiddenCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Hi ha $hiddenCount sessions més. Ves a Objectius per veure totes les sessions programades.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            if (hasMoreThanThree) ...[
              const SizedBox(height: 4),
              const Text(
                'Per consultar o modificar totes les sessions, ves a la funcionalitat d’Objectius.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}