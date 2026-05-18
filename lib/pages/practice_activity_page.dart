import 'dart:async';

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
  bool _timeFinishedHandledInThisPage = false;

  @override
  void initState() {
    super.initState();

    if (widget.remainingSecondsNotifier.value > 0) {
      _startTimer();
    }
  }

  PracticeItem? get _currentItem {
    if (widget.items.isEmpty) return null;
    if (_currentIndex >= widget.items.length) return null;

    return widget.items[_currentIndex];
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
    if (_timeFinishedHandledInThisPage) return;

    _timeFinishedHandledInThisPage = true;

    await widget.onTimeFinished();

    if (!mounted) return;

    if (widget.completionDialogShownNotifier.value) {
      return;
    }

    widget.completionDialogShownNotifier.value = true;

    final continuePracticing = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pràctica completada'),
          content: const Text(
            'Felicitats! Ja has completat el temps de pràctica d’avui.',
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
              child: const Text('Seguir practicant'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (continuePracticing == false) {
      Navigator.pop(context);
    }
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
    widget.onTick(widget.remainingSecondsNotifier.value);
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
              'Temps restant: ${_formatTime(remainingSeconds)}',
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
            child: const Text('Mostrar resposta'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _savingError ? null : _markWrongAndNext,
                  child: const Text('No ho sabia'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _markCorrectAndNext,
                  child: const Text('Ho sabia'),
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