import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/ai_generated_activity.dart';
import '../models/practice_activity_type.dart';
import '../models/practice_item.dart';
import '../models/subject.dart';
import '../services/practice_error_service.dart';
import '../services/practice_stats_service.dart';
import '../widgets/app_scaffold.dart';
import '../theme/app_theme.dart';

class PracticeActivityPage extends StatefulWidget {
  final Subject subject;
  final String sessionId;
  final PracticeActivityType type;
  final List<PracticeItem> items;
  final String? summaryText;
  final List<AiDocumentSummary> documentSummaries;
  final ValueNotifier<int> remainingSecondsNotifier;
  final ValueNotifier<bool> completionDialogShownNotifier;
  final Future<void> Function(int remainingSeconds) onTick;
  final Future<void> Function() onTimeFinished;
  final Future<bool> Function() hasMoreDueSessions;

  const PracticeActivityPage({
    super.key,
    required this.subject,
    required this.sessionId,
    required this.type,
    required this.items,
    this.summaryText,
    this.documentSummaries = const [],
    required this.remainingSecondsNotifier,
    required this.completionDialogShownNotifier,
    required this.onTick,
    required this.onTimeFinished,
    required this.hasMoreDueSessions,
  });

  @override
  State<PracticeActivityPage> createState() => _PracticeActivityPageState();
}

class _PracticeActivityPageState extends State<PracticeActivityPage> {
  final PracticeErrorService _errorService = PracticeErrorService();
  final PracticeStatsService _statsService = PracticeStatsService();

  Timer? _timer;

  int _currentIndex = 0;

  bool _showAnswer = false;
  bool _savingError = false;
  bool _timeFinishedHandled = false;
  bool _timerWarningShown = false;
  bool _timerPaused = false;

  final Map<int, String> _selectedOptionsByIndex = {};


  @override
  void initState() {
    super.initState();

    if (widget.type == PracticeActivityType.timer) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _showTimerWarningIfNeeded();

        if (!mounted) return;

        if (widget.sessionId.isNotEmpty &&
            widget.remainingSecondsNotifier.value > 0) {
          _startTimer();
        }
      });

      return;
    }

    if (widget.sessionId.isNotEmpty &&
        widget.remainingSecondsNotifier.value > 0) {
      _startTimer();
    }
  }

  PracticeItem? get _currentItem {
    if (widget.items.isEmpty) return null;
    if (_currentIndex >= widget.items.length) return null;
    return widget.items[_currentIndex];
  }

  bool get _isFlashcardMode {
    final item = _currentItem;
    if (item == null) return false;

    return widget.type == PracticeActivityType.flashcards ||
        item.type == PracticeActivityType.flashcards;
  }

  Future<void> _showTimerWarningIfNeeded() async {
    if (_timerWarningShown || !mounted) return;

    _timerWarningShown = true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Temporitzador lliure'),
          content: const Text(
            'Aquesta modalitat només et dona temps per practicar. Has de triar tu què treballes i practicar pel teu compte.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Entès'),
            ),
          ],
        );
      },
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (_timerPaused) return;

        if (widget.remainingSecondsNotifier.value <= 0) {
          timer.cancel();
          await _handleTimeFinished();
          return;
        }

        widget.remainingSecondsNotifier.value--;

        await widget.onTick(widget.remainingSecondsNotifier.value);

        if (widget.remainingSecondsNotifier.value <= 0) {
          timer.cancel();
          await _handleTimeFinished();
        }
      },
    );
  }

  Future<void> _handleTimeFinished() async {
    if (_timeFinishedHandled) return;
    _timeFinishedHandled = true;

    if (widget.sessionId.isEmpty) return;

    widget.completionDialogShownNotifier.value = true;

    bool hasMoreDueSessions = false;

    try {
      hasMoreDueSessions = await widget.hasMoreDueSessions();
    } catch (_) {
      hasMoreDueSessions = false;
    }

    if (!mounted) return;

    final continuePracticing = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pràctica completada'),
          content: Text(
            hasMoreDueSessions
                ? 'Felicitats! Has completat aquesta sessió. Tens més sessions pendents acumulades, així que pots passar directament a la següent.'
                : 'Felicitats! Has completat aquesta sessió. No tens més sessions pendents acumulades, però pots seguir practicant lliurement.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Parar per avui'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(
                hasMoreDueSessions ? 'Següent sessió' : 'Seguir practicant',
              ),
            ),
          ],
        );
      },
    );

    await widget.onTimeFinished();

    if (!mounted) return;

    Navigator.of(context).pop(
    PracticeCompletionResult(
      continuePracticing: continuePracticing == true,
      hasMoreDueSessions: hasMoreDueSessions,
    ),
  );
  }



  Future<void> _registerAttempt(bool isCorrect) async {
    await _statsService.registerAttempt(
      subjectId: widget.subject.id,
      sessionId: widget.sessionId,
      activityType: widget.type == PracticeActivityType.errorTest
          ? (_currentItem?.type ?? widget.type)
          : widget.type,
      isCorrect: isCorrect,
    );
  }

  String _formatTime(int secondsValue) {
    final minutes = secondsValue ~/ 60;
    final seconds = secondsValue % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _goToIndex(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.items.length) return;

    setState(() {
      _currentIndex = newIndex;
      _showAnswer = false;
    });
  }

  void _nextItem() {
    if (_currentIndex >= widget.items.length - 1) {
      Navigator.pop(context);
      return;
    }

    _goToIndex(_currentIndex + 1);
  }

  void _previousItem() {
    _goToIndex(_currentIndex - 1);
  }

  Future<void> _saveCurrentAsError() async {
    final item = _currentItem;
    if (item == null || _savingError) return;

    setState(() {
      _savingError = true;
    });

    try {
      await _errorService.saveError(
        subjectId: widget.subject.id,
        item: item,
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingError = false;
        });
      }
    }
  }

  Future<void> _removeCurrentFromErrors() async {
    final item = _currentItem;
    if (item == null) return;

    await _errorService.removeError(
      subjectId: widget.subject.id,
      item: item,
    );
  }

  Future<void> _markWrongAndNext() async {
    await _registerAttempt(false);
    await _saveCurrentAsError();
    _nextItem();
  }

  Future<void> _markCorrectAndNext() async {
    await _registerAttempt(true);

    if (widget.type == PracticeActivityType.errorTest) {
      await _removeCurrentFromErrors();
    }

    _nextItem();
  }

  @override
  void dispose() {
    _timer?.cancel();

    if (widget.sessionId.isNotEmpty && !_timeFinishedHandled) {
      widget.onTick(widget.remainingSecondsNotifier.value);
    }

    super.dispose();
  }

  Widget _buildTimer() {
    return ValueListenableBuilder<int>(
      valueListenable: widget.remainingSecondsNotifier,
      builder: (context, remainingSeconds, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  widget.sessionId.isEmpty
                      ? 'Pràctica extra fora de sessió'
                      : 'Temps restant: ${_formatTime(remainingSeconds)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.sessionId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _timerPaused = !_timerPaused;
                      });
                    },
                    icon: Icon(
                      _timerPaused ? Icons.play_arrow : Icons.pause,
                    ),
                    label: Text(
                      _timerPaused ? 'Reprendre temps' : 'Parar temps',
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationButtons() {
    if (widget.items.length <= 1) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _currentIndex > 0 ? _previousItem : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Anterior'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                _currentIndex < widget.items.length - 1 ? _nextItem : null,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Següent'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.type == PracticeActivityType.exercises
                  ? 'Enunciat'
                  : 'Pregunta',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerCard({
    required String text,
    required bool isExerciseMode,
  }) {
    return Card(
      color: AppColors.surfaceLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isExerciseMode ? 'Solució' : 'Resposta',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryActivity() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTimer(),
        const SizedBox(height: 16),
        if ((widget.summaryText ?? '').trim().isNotEmpty) ...[
          Text(
            'Resum general',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            widget.summaryText!,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          'Resums per document',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (widget.documentSummaries.isEmpty)
          const Text('No hi ha resums per document disponibles.'),
        ...widget.documentSummaries.map(
          (documentSummary) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    documentSummary.fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    documentSummary.summary,
                    textAlign: TextAlign.justify,
                    style: const TextStyle(height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFreeTimerActivity() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Temporitzador',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aquest mode no mostra preguntes. Utilitza el temps restant per practicar pel teu compte.',
                    textAlign: TextAlign.center,
                  ),
                  if (_timerPaused) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Temps aturat',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTimer(),
        ],
      ),
    );
  }

  Widget _buildFlashcardActivity() {
    final item = _currentItem;

    if (item == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hi ha flashcards disponibles.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final canAnswer = _showAnswer;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTimer(),
          const SizedBox(height: 16),
          Text(
            'Flashcard ${_currentIndex + 1}/${widget.items.length}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Toca la targeta per girar-la. Després podràs indicar si la sabies o no.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showAnswer = !_showAnswer;
                });
              },
              onHorizontalDragEnd: (details) async {
                if (!canAnswer) return;

                final velocity = details.primaryVelocity ?? 0;

                if (velocity > 250) {
                  await _markCorrectAndNext();
                } else if (velocity < -250) {
                  await _markWrongAndNext();
                }
              },
              child: Center(
                child: SizedBox(
                  width: double.infinity,
                  height: 340,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) {
                      final rotate = Tween<double>(
                        begin: math.pi,
                        end: 0,
                      ).animate(animation);

                      return AnimatedBuilder(
                        animation: rotate,
                        child: child,
                        builder: (context, child) {
                          return Transform(
                            transform: Matrix4.rotationY(rotate.value),
                            alignment: Alignment.center,
                            child: child,
                          );
                        },
                      );
                    },
                    child: _FlashcardFace(
                      key: ValueKey(_showAnswer),
                      text: _showAnswer ? item.answer : item.question,
                      label: _showAnswer ? 'Resposta' : 'Pregunta',
                      isAnswer: _showAnswer,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (!canAnswer)
            const Text(
              'Gira la targeta per poder respondre.',
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      canAnswer && !_savingError ? _markWrongAndNext : null,
                  icon: const Icon(Icons.close),
                  label: const Text('No ho sabia'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canAnswer ? _markCorrectAndNext : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Ho sabia'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevealAnswerActivity() {
    final item = _currentItem;
  
    if (item == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hi ha preguntes disponibles per aquesta modalitat.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  
    if (_isFlashcardMode) {
      return _buildFlashcardActivity();
    }
  
    final isExerciseMode = widget.type == PracticeActivityType.exercises ||
        item.type == PracticeActivityType.exercises;
  
    final canAnswer = _showAnswer;
  
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTimer(),
            const SizedBox(height: 16),
            Text(
              isExerciseMode
                  ? 'Exercicis importats ${_currentIndex + 1}/${widget.items.length}'
                  : 'Pregunta ${_currentIndex + 1}/${widget.items.length}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildQuestionCard(item.question),
            const SizedBox(height: 16),
            if (_showAnswer)
              _buildAnswerCard(
                text: item.answer,
                isExerciseMode: isExerciseMode,
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showAnswer = !_showAnswer;
                });
              },
              child: Text(
                _showAnswer
                    ? isExerciseMode
                        ? 'Amagar solució'
                        : 'Amagar resposta'
                    : isExerciseMode
                        ? 'Mostrar solució'
                        : 'Mostrar resposta',
              ),
            ),
            const SizedBox(height: 8),
            if (!canAnswer)
              Text(
                isExerciseMode
                    ? 'Mostra la solució per poder indicar si l’has resolt bé.'
                    : 'Mostra la resposta per poder indicar si la sabies.',
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        canAnswer && !_savingError ? _markWrongAndNext : null,
                    child: Text(
                      isExerciseMode ? 'No ho he resolt bé' : 'No ho sabia',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: canAnswer ? _markCorrectAndNext : null,
                    child: Text(
                      isExerciseMode ? 'Ho he resolt bé' : 'Ho sabia',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleChoiceActivity() {
    final item = _currentItem;

    if (item == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hi ha preguntes tipus test disponibles.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final selectedOption = _selectedOptionsByIndex[_currentIndex];
    final answered = selectedOption != null;
    final correct = selectedOption == item.answer;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTimer(),
        const SizedBox(height: 16),
        Text(
          'Pregunta ${_currentIndex + 1}/${widget.items.length}',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _buildQuestionCard(item.question),
        const SizedBox(height: 16),
        ...item.options.map(
          (option) {
            final isSelected = option == selectedOption;
            final isCorrectOption = option == item.answer;

            Color? buttonColor;

            if (answered && isSelected && isCorrectOption) {
              buttonColor = Colors.green.shade200;
            } else if (answered && isSelected && !isCorrectOption) {
              buttonColor = Colors.red.shade300;
            } else if (answered && isCorrectOption) {
              buttonColor = Colors.green.shade200;
            } else if (answered) {
              buttonColor = AppColors.primary.withOpacity(0.35);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton(
                style: buttonColor == null
                    ? null
                    : ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: answered ? Colors.black : null,
                      ),
                onPressed: () async {
                  if (answered) return;

                  setState(() {
                    _selectedOptionsByIndex[_currentIndex] = option;
                  });

                  if (option != item.answer) {
                    await _registerAttempt(false);
                    await _saveCurrentAsError();
                  } else {
                    await _registerAttempt(true);

                    if (widget.type == PracticeActivityType.errorTest) {
                      await _removeCurrentFromErrors();
                    }
                  }
                },
                child: Text(option),
              ),
            );
          },
        ),
        if (answered)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              correct
                  ? 'Correcte'
                  : 'Incorrecte. Resposta correcta: ${item.answer}',
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 16),
        _buildNavigationButtons(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildErrorTestActivity() {
    final item = _currentItem;

    if (item == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Ja no queden errors pendents.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (item.type == PracticeActivityType.multipleChoice &&
        item.options.length >= 2) {
      return _buildMultipleChoiceActivity();
    }

    return _buildRevealAnswerActivity();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    switch (widget.type) {
      case PracticeActivityType.summary:
        child = _buildSummaryActivity();
        break;
      case PracticeActivityType.multipleChoice:
        child = _buildMultipleChoiceActivity();
        break;
      case PracticeActivityType.errorTest:
        child = _buildErrorTestActivity();
        break;
      case PracticeActivityType.flashcards:
        child = _buildFlashcardActivity();
        break;
      case PracticeActivityType.openQuestions:
      case PracticeActivityType.exercises:
        child = _buildRevealAnswerActivity();
        break;
      case PracticeActivityType.timer:
        child = _buildFreeTimerActivity();
        break;
    }

    return AppScaffold(
      title: widget.type.title,
      child: child,
    );
  }
}

class _FlashcardFace extends StatelessWidget {
  final String text;
  final String label;
  final bool isAnswer;

  const _FlashcardFace({
    super.key,
    required this.text,
    required this.label,
    required this.isAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 340,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isAnswer ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.grey.shade500,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isAnswer ? Colors.white70 : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: isAnswer ? Colors.white : Colors.grey.shade900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PracticeCompletionResult {
  final bool continuePracticing;
  final bool hasMoreDueSessions;

  const PracticeCompletionResult({
    required this.continuePracticing,
    required this.hasMoreDueSessions,
  });
}