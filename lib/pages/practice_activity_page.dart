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
  String? _selectedOption;
  bool _savingError = false;
  bool _timeFinishedHandled = false;

  @override
  void initState() {
    super.initState();

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

  void _startTimer() {
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
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
    if (widget.completionDialogShownNotifier.value) return;

    widget.completionDialogShownNotifier.value = true;

    await widget.onTimeFinished();

    if (!mounted) return;

    final continuePracticing = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pràctica completada'),
          content: const Text(
            'Felicitats! Has completat aquesta sessió. Si tens més sessions pendents, en tornar a la pantalla de pràctica es carregarà la següent.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Parar per avui'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Següent sessió'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    Navigator.pop(context, continuePracticing == true);
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

  void _nextItem() {
    if (_currentIndex >= widget.items.length - 1) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _currentIndex++;
      _showAnswer = false;
      _selectedOption = null;
    });
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
            child: Text(
              widget.sessionId.isEmpty
                  ? 'Pràctica extra fora de sessió'
                  : 'Temps restant: ${_formatTime(remainingSeconds)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
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
            'Toca la targeta per girar-la. Arrossega a la dreta si la sabies o a l’esquerra si no la sabies.',
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
                final velocity = details.primaryVelocity ?? 0;

                if (velocity > 250) {
                  await _markCorrectAndNext();
                } else if (velocity < -250) {
                  await _markWrongAndNext();
                }
              },
              child: Center(
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _savingError ? null : _markWrongAndNext,
                  icon: const Icon(Icons.close),
                  label: const Text('No ho sabia'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _markCorrectAndNext,
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTimer(),
          const SizedBox(height: 16),
          Text(
            isExerciseMode
                ? 'Exercici ${_currentIndex + 1}/${widget.items.length}'
                : 'Pregunta ${_currentIndex + 1}/${widget.items.length}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                item.question,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_showAnswer)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  item.answer,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showAnswer = true;
              });
            },
            child: Text(
              isExerciseMode ? 'Mostrar solució' : 'Mostrar resposta',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _savingError ? null : _markWrongAndNext,
                  child: Text(
                    isExerciseMode ? 'No ho he resolt bé' : 'No ho sabia',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _markCorrectAndNext,
                  child: Text(
                    isExerciseMode ? 'Ho he resolt bé' : 'Ho sabia',
                  ),
                ),
              ),
            ],
          ),
        ],
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

    final answered = _selectedOption != null;
    final correct = _selectedOption == item.answer;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTimer(),
          const SizedBox(height: 16),
          Text(
            'Pregunta ${_currentIndex + 1}/${widget.items.length}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                item.question,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...item.options.map(
            (option) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ElevatedButton(
                  onPressed: answered
                      ? null
                      : () async {
                          setState(() {
                            _selectedOption = option;
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
          const Spacer(),
          ElevatedButton(
            onPressed: answered ? _nextItem : null,
            child: const Text('Següent'),
          ),
        ],
      ),
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
      constraints: const BoxConstraints(
        minHeight: 300,
        maxWidth: 520,
      ),
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
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: isAnswer ? Colors.white : Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }
}