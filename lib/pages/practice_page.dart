import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/ai_generated_activity.dart';
import '../models/practice_activity_type.dart';
import '../models/practice_item.dart';
import '../models/practice_timer_state.dart';
import '../models/processed_material.dart';
import '../models/study_goal.dart';
import '../models/subject.dart';
import '../services/ai_activity_service.dart';
import '../services/gemini_service.dart';
import '../services/material_processing_service.dart';
import '../services/objective_service.dart';
import '../services/practice_error_service.dart';
import '../widgets/app_scaffold.dart';
import '../pages/practice_activity_page.dart';
import '../pages/visualize_page.dart';

class PracticePage extends StatefulWidget {
  final Subject subject;

  const PracticePage({
    super.key,
    required this.subject,
  });

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final MaterialProcessingService _materialProcessingService =
      MaterialProcessingService();
  final ObjectiveService _objectiveService = ObjectiveService();
  final PracticeErrorService _errorService = PracticeErrorService();
  final GeminiService _geminiService = GeminiService();
  final AiActivityService _aiActivityService = AiActivityService();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isGenerating = false;

  ValueNotifier<int>? _remainingSecondsNotifier;
  ValueNotifier<bool>? _completionDialogShownNotifier;
  String? _activeSessionId;

  @override
  void dispose() {
    _remainingSecondsNotifier?.dispose();
    _completionDialogShownNotifier?.dispose();
    super.dispose();
  }

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No hi ha usuari autenticat.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _practiceSessionsCollection {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('subjects')
        .doc(widget.subject.id)
        .collection('practiceSessions');
  }

  Future<bool> _hasMoreDueSessionsAfterCurrent() async {
    final activeSessionId = _activeSessionId;

    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final snapshot = await _practiceSessionsCollection
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in snapshot.docs) {
      if (doc.id == activeSessionId) continue;

      final data = doc.data();
      final scheduledDateRaw = data['scheduledDate'];

      DateTime? scheduledDate;

      if (scheduledDateRaw is Timestamp) {
        scheduledDate = scheduledDateRaw.toDate();
      } else if (scheduledDateRaw is DateTime) {
        scheduledDate = scheduledDateRaw;
      }

      if (scheduledDate == null) continue;

      if (!scheduledDate.isAfter(todayEnd)) {
        return true;
      }
    }

    return false;
  }

  void _syncTimerWithFirestoreState(PracticeTimerState timerState) {
    if (_activeSessionId == timerState.sessionId &&
        _remainingSecondsNotifier != null &&
        _completionDialogShownNotifier != null) {
      return;
    }

    _remainingSecondsNotifier?.dispose();
    _completionDialogShownNotifier?.dispose();

    _activeSessionId = timerState.sessionId;

    _remainingSecondsNotifier = ValueNotifier<int>(
      timerState.remainingSeconds,
    );

    _completionDialogShownNotifier = ValueNotifier<bool>(false);
  }

  void _resetLocalTimer() {
    _remainingSecondsNotifier?.dispose();
    _completionDialogShownNotifier?.dispose();

    _remainingSecondsNotifier = null;
    _completionDialogShownNotifier = null;
    _activeSessionId = null;
  }

  void _clearTimer() {
    _resetLocalTimer();
  }

  String _formatTime(int secondsValue) {
    final minutes = secondsValue ~/ 60;
    final seconds = secondsValue % 60;

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _persistRemainingSeconds(int remainingSeconds) async {
    final sessionId = _activeSessionId;

    if (sessionId == null || sessionId.isEmpty) return;

    await _objectiveService.updateRemainingSeconds(
      subjectId: widget.subject.id,
      sessionId: sessionId,
      remainingSeconds: remainingSeconds,
    );
  }

  Future<void> _markPracticeCompletedToday() async {
    final sessionId = _activeSessionId;

    if (sessionId == null || sessionId.isEmpty) return;

    await _objectiveService.completePracticeSession(
      subjectId: widget.subject.id,
      subjectName: widget.subject.name,
      sessionId: sessionId,
    );

    _resetLocalTimer();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _generateActivities(List<ProcessedMaterial> materials) async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final activity = await _geminiService.generateActivitiesFromMaterials(
        materials: materials,
        onFlashOverloaded: () {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gemini Flash està saturat temporalment. Ho intentem automàticament amb Gemini Flash-Lite.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        },
      );

      await _aiActivityService.saveActivity(
        subjectId: widget.subject.id,
        activity: activity,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Activitats generades: ${activity.flashcards.length} flashcards, ${activity.multipleChoiceQuestions.length} test, ${activity.openQuestions.length} obertes i ${activity.exercises.length} exercicis detectats.',
          ),
        ),
      );
    } on GeminiOverloadedException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ara mateix la API de Gemini està massa saturada. Torna-ho a provar més tard.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hi ha hagut un error generant les activitats. Torna-ho a provar d’aquí uns minuts.'),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
  void _showGeneratingMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La generació d\'activitats pot tardar uns minuts. Si us plau, espera mentre Consolida prepara el contingut.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _openActivity({
    required PracticeActivityType type,
    required AiGeneratedActivity activity,
    required List<PracticeItem> errorItems,
  }) async {
    if (_isGenerating) {
      _showGeneratingMessage();
      return;
    }

    final remainingSecondsNotifier = _remainingSecondsNotifier;
    final completionDialogShownNotifier = _completionDialogShownNotifier;

    if (remainingSecondsNotifier == null ||
        completionDialogShownNotifier == null) {
      return;
    }

    List<PracticeItem> items = [];
    String? summary;

    switch (type) {
      case PracticeActivityType.flashcards:
        items = activity.flashcards
            .map(
              (card) => PracticeItem(
                type: PracticeActivityType.flashcards,
                question: card.question,
                answer: card.answer,
              ),
            )
            .toList();
        break;

      case PracticeActivityType.summary:
        summary = activity.summary;
        break;

      case PracticeActivityType.multipleChoice:
        items = activity.multipleChoiceQuestions
            .where(
              (question) =>
                  question.options.length == 4 &&
                  question.options.contains(question.correctAnswer),
            )
            .map(
              (question) => PracticeItem(
                type: PracticeActivityType.multipleChoice,
                question: question.question,
                answer: question.correctAnswer,
                options: question.options,
              ),
            )
            .toList();
        break;

      case PracticeActivityType.openQuestions:
        items = activity.openQuestions
            .map(
              (question) => PracticeItem(
                type: PracticeActivityType.openQuestions,
                question: question.question,
                answer: question.suggestedAnswer,
              ),
            )
            .toList();
        break;

      case PracticeActivityType.exercises:
        items = activity.exercises
            .map(
              (exercise) => PracticeItem(
                type: PracticeActivityType.exercises,
                question: exercise.sourceFileName.trim().isEmpty
                    ? exercise.exercise
                    : 'Fitxer: ${exercise.sourceFileName}\n\n${exercise.exercise}',
                answer: exercise.solutionGeneratedByAi
                    ? '${exercise.solution}\n\nAvís: aquesta resposta ha estat generada per la IA perquè el fitxer importat no contenia una solució explícita.'
                    : exercise.solution,
                sourceFileName: exercise.sourceFileName,
              ),
            )
            .toList();
        break;

      case PracticeActivityType.errorTest:
        items = errorItems;
        break;

      case PracticeActivityType.timer:
        items = [];
        break;
    }

    final completionResult = await Navigator.push<PracticeCompletionResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PracticeActivityPage(
          subject: widget.subject,
          sessionId: _activeSessionId ?? '',
          type: type,
          items: items,
          summaryText: summary,
          documentSummaries: activity.documentSummaries,
          remainingSecondsNotifier: remainingSecondsNotifier,
          completionDialogShownNotifier: completionDialogShownNotifier,
          onTick: _persistRemainingSeconds,
          onTimeFinished: _markPracticeCompletedToday,
          hasMoreDueSessions: _hasMoreDueSessionsAfterCurrent,
        ),
      ),
    );

    if (!mounted) return;

    if (completionResult == null) return;

    if (completionResult.continuePracticing) {
      if (completionResult.hasMoreDueSessions) {
        _resetLocalTimer();

        await Future.delayed(const Duration(milliseconds: 400));

        if (!mounted) return;

        setState(() {});
        return;
      }

      setState(() {});
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VisualizePage(subject: widget.subject),
      ),
    );
  }

  Future<void> _confirmRegenerate(
    List<ProcessedMaterial> materials,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Regenerar activitats'),
          content: const Text(
            'Això substituirà les activitats generades anteriorment. Vols continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel·lar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Regenerar'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await _generateActivities(materials);
  }

  Widget _buildTimerHeader(PracticeTimerState timerState) {
    final remainingSecondsNotifier = _remainingSecondsNotifier;

    if (remainingSecondsNotifier == null) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<int>(
      valueListenable: remainingSecondsNotifier,
      builder: (context, remainingSeconds, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  timerState.hasDueSession ? 'Sessió activa' : 'Pràctica lliure',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (timerState.hasDueSession) ...[
                  Text(
                    'Objectiu: ${timerState.goalTitle}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sessió prevista: ${_formatDate(timerState.scheduledDate)}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text('Temps restant'),
                ] else ...[
                  const Text(
                    'No tens cap sessió pendent ara mateix.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  _formatTime(remainingSeconds),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoPendingPracticeMessage() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Ara mateix no tens cap pràctica pendent. Pots practicar igualment, però aquesta pràctica extra no consumirà temps d’una sessió programada.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Practicar - ${widget.subject.name}',
      child: StreamBuilder<List<ProcessedMaterial>>(
        stream: _materialProcessingService.getProcessedMaterials(
          widget.subject.id,
        ),
        builder: (context, materialSnapshot) {
          if (materialSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final materials = materialSnapshot.data ?? [];

          if (materials.isEmpty) {
            _clearTimer();

            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Encara no hi ha material processat.\n\nVes a Importar i afegeix un PDF, DOCX o TXT.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<List<StudyGoal>>(
            stream: _objectiveService.getGoals(widget.subject.id),
            builder: (context, goalsSnapshot) {
              if (goalsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final goals = goalsSnapshot.data ?? [];

              if (goals.isEmpty) {
                _clearTimer();

                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Encara no pots practicar.\n\nPrimer has de crear un objectiu perquè la sessió tingui una durada i una planificació.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return StreamBuilder<PracticeTimerState>(
                stream: _objectiveService.watchPracticeTimerState(
                  widget.subject.id,
                ),
                builder: (context, timerSnapshot) {
                  if (timerSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final timerState = timerSnapshot.data ??
                      const PracticeTimerState(
                        sessionId: null,
                        remainingSeconds: 0,
                        durationMinutes: 0,
                        hasDueSession: false,
                        completedToday: false,
                      );

                  _syncTimerWithFirestoreState(timerState);

                  return StreamBuilder<AiGeneratedActivity?>(
                    stream: _aiActivityService.watchActivity(
                      widget.subject.id,
                    ),
                    builder: (context, activitySnapshot) {
                      final activity = activitySnapshot.data;

                      return StreamBuilder<List<PracticeItem>>(
                        stream: _errorService.getErrors(widget.subject.id),
                        builder: (context, errorsSnapshot) {
                          final errorItems = errorsSnapshot.data ?? [];

                          if (activity == null) {
                            return ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                _buildTimerHeader(timerState),
                                const SizedBox(height: 16),
                                if (!timerState.hasDueSession) ...[
                                  _buildNoPendingPracticeMessage(),
                                  const SizedBox(height: 16),
                                ],
                                _NoGeneratedActivitiesView(
                                  materialsCount: materials.length,
                                  isGenerating: _isGenerating,
                                  onGenerate: () =>
                                      _generateActivities(materials),
                                ),
                              ],
                            );
                          }

                          final multipleChoiceCount =
                              activity.multipleChoiceQuestions.where(
                            (question) {
                              return question.options.length == 4 &&
                                  question.options.contains(
                                    question.correctAnswer,
                                  );
                            },
                          ).length;

                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildTimerHeader(timerState),
                              const SizedBox(height: 16),
                              if (!timerState.hasDueSession) ...[
                                _buildNoPendingPracticeMessage(),
                                const SizedBox(height: 16),
                              ],
                              Text(
                                'Tria una modalitat de pràctica',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                timerState.hasDueSession
                                    ? 'Estàs fent una sessió de l’objectiu: ${timerState.goalTitle}'
                                    : 'Pràctica extra fora de planificació',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Material processat: ${materials.length} fitxers',
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _isGenerating
                                    ? null
                                    : () => _confirmRegenerate(materials),
                                icon: const Icon(Icons.refresh),
                                label: Text(
                                  _isGenerating
                                      ? 'Regenerant...'
                                      : 'Regenerar activitats amb IA',
                                ),
                              ),
                              if (_isGenerating) ...[
                                const SizedBox(height: 8),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'La generació d\'activitats pot tardar uns minuts. Si us plau, espera mentre Consolida prepara el contingut.',
                                            textAlign: TextAlign.left,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              const SizedBox(height: 24),
                              _ActivityCard(
                                type: PracticeActivityType.summary,
                                count: activity.documentSummaries.isNotEmpty
                                    ? activity.documentSummaries.length
                                    : (activity.summary.trim().isEmpty ? 0 : 1),
                                enabled: !_isGenerating && (activity.summary.trim().isNotEmpty ||
                                    activity.documentSummaries.isNotEmpty),
                                onTap: () => _openActivity(
                                  type: PracticeActivityType.summary,
                                  activity: activity,
                                  errorItems: errorItems,
                                ),
                              ),
                              _ActivityCard(
                                type: PracticeActivityType.flashcards,
                                count: activity.flashcards.length,
                                enabled: !_isGenerating && activity.flashcards.isNotEmpty,
                                onTap: () => _openActivity(
                                  type: PracticeActivityType.flashcards,
                                  activity: activity,
                                  errorItems: errorItems,
                                ),
                              ),
                              _ActivityCard(
                                type: PracticeActivityType.multipleChoice,
                                count: multipleChoiceCount,
                                enabled: !_isGenerating && multipleChoiceCount > 0,
                                onTap: () => _openActivity(
                                  type: PracticeActivityType.multipleChoice,
                                  activity: activity,
                                  errorItems: errorItems,
                                ),
                              ),
                              _ActivityCard(
                                type: PracticeActivityType.openQuestions,
                                count: activity.openQuestions.length,
                                enabled: !_isGenerating && activity.openQuestions.isNotEmpty,
                                onTap: () => _openActivity(
                                  type: PracticeActivityType.openQuestions,
                                  activity: activity,
                                  errorItems: errorItems,
                                ),
                              ),
                              _ActivityCard(
                                type: PracticeActivityType.exercises,
                                count: activity.exercises.length,
                                enabled: !_isGenerating && activity.exercises.isNotEmpty,
                                onTap: () => _openActivity(
                                  type: PracticeActivityType.exercises,
                                  activity: activity,
                                  errorItems: errorItems,
                                ),
                              ),
                              _ActivityCard(
                                type: PracticeActivityType.errorTest,
                                count: errorItems.length,
                                enabled: !_isGenerating && errorItems.isNotEmpty,
                                onTap: () => _openActivity(
                                  type: PracticeActivityType.errorTest,
                                  activity: activity,
                                  errorItems: errorItems,
                                ),
                              ),
                              _ActivityCard(
                                type: PracticeActivityType.timer,
                                count: 1,
                                enabled: !_isGenerating,
                                onTap: () => _openActivity(
                                  type: PracticeActivityType.timer,
                                  activity: activity,
                                  errorItems: errorItems,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
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

class _NoGeneratedActivitiesView extends StatelessWidget {
  final int materialsCount;
  final bool isGenerating;
  final VoidCallback onGenerate;

  const _NoGeneratedActivitiesView({
    required this.materialsCount,
    required this.isGenerating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Encara no hi ha activitats generades.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                Text(
                  'Material processat: $materialsCount fitxers',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'La generació d\'activitats pot tardar uns minuts. Si us plau, espera mentre Consolida prepara el contingut.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isGenerating ? null : onGenerate,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: isGenerating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Generar activitats amb Gemini'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final PracticeActivityType type;
  final int count;
  final VoidCallback onTap;
  final bool enabled;

  const _ActivityCard({
    required this.type,
    required this.count,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = type == PracticeActivityType.timer
        ? type.description
        : enabled
            ? '${type.description}\nDisponibles: $count'
            : '${type.description}\nNo disponible encara.';

    return Card(
      child: ListTile(
        enabled: enabled,
        title: Text(type.title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}